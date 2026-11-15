part of '../main.dart';

// Live classes on LiveKit: chat, the room connection, the teacher's studio
// and the list of sessions a teacher hosts.

/// Messages of one live session, kept fresh with Supabase Realtime (plus a
/// slow poll in case the realtime socket drops).
class LiveChat extends ChangeNotifier {
  LiveChat({required this.learn, required this.sessionId});

  final LearnStore learn;
  final String sessionId;
  List<EpsLiveMessage> messages = [];
  RealtimeChannel? _channel;
  Timer? _poll;
  bool _disposed = false;

  List<EpsLiveMessage> get questions =>
      messages.where((m) => m.isQuestion).toList();

  void start() {
    unawaited(load());
    if (!learn.enabled) {
      return;
    }
    try {
      _channel = learn.repo.watchLiveMessages(sessionId, () {
        unawaited(load());
        unawaited(_refreshSession());
      });
    } on Object {
      // Realtime is optional; the poll below keeps the chat moving.
    }
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => load());
  }

  Future<void> load() async {
    if (!learn.enabled) {
      messages = [...?learn.demoMessages[sessionId]];
      _notify();
      return;
    }
    try {
      messages = await learn.repo.liveMessages(sessionId);
      _notify();
    } on Object {
      // Keep the last messages on transient network errors.
    }
  }

  Future<void> _refreshSession() async {
    try {
      final fresh = await learn.repo.liveSession(sessionId);
      if (fresh != null && !_disposed) {
        learn.replaceLiveSession(fresh);
      }
    } on Object {
      // Ignore; the next update retries.
    }
  }

  Future<void> send(
    AppUser user,
    String text, {
    bool question = false,
    bool teacher = false,
  }) async {
    final body = text.trim();
    if (body.isEmpty) {
      return;
    }
    if (!learn.enabled) {
      learn.demoMessages
          .putIfAbsent(sessionId, () => [])
          .add(
            EpsLiveMessage.fromRow({
              'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
              'user_id': user.id,
              'user_name': user.name,
              'body': body,
              'is_question': question,
              'is_teacher': teacher,
              'created_at': DateTime.now().toIso8601String(),
            }),
          );
      await load();
      return;
    }
    await learn.repo.sendLiveMessage(
      sessionId: sessionId,
      userId: user.id,
      userName: user.name,
      body: body,
      isQuestion: question,
      isTeacher: teacher,
    );
    await load();
  }

  Future<void> setAnswered(EpsLiveMessage message, bool answered) async {
    if (!learn.enabled) {
      final list = learn.demoMessages[sessionId];
      final i = list?.indexWhere((m) => m.id == message.id) ?? -1;
      if (list != null && i >= 0) {
        list[i] = EpsLiveMessage.fromRow({
          'id': message.id,
          'user_id': message.userId,
          'user_name': message.userName,
          'body': message.body,
          'is_question': true,
          'is_teacher': message.isTeacher,
          'answered': answered,
          'created_at': message.createdAt.toIso8601String(),
        });
      }
      await load();
      return;
    }
    await learn.repo.setQuestionAnswered(message.id, answered);
    await load();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    final channel = _channel;
    if (channel != null) {
      unawaited(learn.repo.client.removeChannel(channel));
    }
    super.dispose();
  }
}

enum LiveConnState { idle, connecting, connected, failed, ended }

/// One connection to a LiveKit room, as a viewer or as the host.
class LiveRoomConnection extends ChangeNotifier {
  LiveRoomConnection({
    required this.learn,
    required this.userId,
    required this.sessionId,
    required this.host,
  });

  final LearnStore learn;
  final String userId;
  final String sessionId;
  final bool host;

  lk.Room? room;
  lk.EventsListener<lk.RoomEvent>? _events;
  LiveConnState state = LiveConnState.idle;
  String error = '';
  bool micOn = true;
  bool cameraOn = true;
  bool screenOn = false;
  bool frontCamera = true;
  int peakViewers = 0;
  DateTime? liveSince;
  bool _disposed = false;

  /// Preview builds have no backend: the studio and room run as a demo.
  bool get demo => !learn.enabled;

  int get viewers {
    if (demo) {
      return state == LiveConnState.connected ? 24 : 0;
    }
    return room?.remoteParticipants.length ?? 0;
  }

  bool get canPlayAudio => room?.canPlaybackAudio ?? true;

  /// What to show full size: a shared screen first, then the camera.
  lk.VideoTrack? get mainVideo {
    final r = room;
    if (r == null) {
      return null;
    }
    if (host) {
      final pubs = r.localParticipant?.videoTrackPublications ?? const [];
      final screen = pubs
          .where((p) => p.source == lk.TrackSource.screenShareVideo)
          .firstOrNull;
      return (screen ?? pubs.firstOrNull)?.track;
    }
    lk.VideoTrack? camera;
    for (final p in r.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        final track = pub.track;
        if (track == null || pub.muted) {
          continue;
        }
        if (pub.source == lk.TrackSource.screenShareVideo) {
          return track;
        }
        camera ??= track;
      }
    }
    return camera;
  }

  bool get mainIsScreen {
    final r = room;
    if (r == null) {
      return false;
    }
    final List<lk.TrackPublication> pubs = host
        ? [...?r.localParticipant?.videoTrackPublications]
        : [
            for (final p in r.remoteParticipants.values)
              ...p.videoTrackPublications,
          ];
    return pubs.any(
      (p) => p.source == lk.TrackSource.screenShareVideo && p.track != null,
    );
  }

  /// Joins as a viewer.
  Future<void> join() => _run(() async {
    final grant = await learn.repo.liveKit(
      'token',
      userId: userId,
      sessionId: sessionId,
    );
    await _connect(grant);
  });

  /// Goes live as the host with camera and microphone. Sessions are not
  /// recorded.
  Future<void> startBroadcast() => _run(() async {
    if (demo) {
      liveSince = DateTime.now();
      return;
    }
    final grant = await learn.repo.liveKit(
      'start',
      userId: userId,
      sessionId: sessionId,
    );
    await _connect(grant);
    final me = room!.localParticipant!;
    await me.setMicrophoneEnabled(true);
    await me.setCameraEnabled(true);
    liveSince = DateTime.now();
  });

  Future<void> _run(Future<void> Function() body) async {
    state = LiveConnState.connecting;
    error = '';
    _notify();
    try {
      await body();
      state = LiveConnState.connected;
    } on Object catch (e) {
      await _closeRoom();
      error = e.toString().replaceFirst('Exception: ', '');
      state = LiveConnState.failed;
    }
    _notify();
  }

  Future<void> _connect(Map<String, dynamic> grant) async {
    final url = '${grant['url'] ?? ''}';
    final token = '${grant['token'] ?? ''}';
    if (url.isEmpty || token.isEmpty) {
      throw Exception('تعذر الحصول على إذن الدخول للبث.');
    }
    final r = lk.Room(
      roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _events = r.createListener()
      ..on<lk.RoomDisconnectedEvent>((_) {
        if (state == LiveConnState.connected) {
          state = LiveConnState.ended;
        }
        _notify();
      })
      ..listen((_) {
        peakViewers = max(peakViewers, r.remoteParticipants.length);
        _notify();
      });
    await r.connect(url, token);
    room = r;
  }

  Future<void> startAudio() async {
    await room?.startAudio();
    _notify();
  }

  Future<void> toggleMic() async {
    micOn = !micOn;
    _notify();
    await room?.localParticipant?.setMicrophoneEnabled(micOn);
  }

  Future<void> toggleCamera() async {
    cameraOn = !cameraOn;
    _notify();
    await room?.localParticipant?.setCameraEnabled(cameraOn);
  }

  /// Switches between the front and back camera. Browsers on phones do not
  /// always honour the facing mode, so fall back to picking the next camera
  /// device.
  Future<void> flipCamera() async {
    final pub = room?.localParticipant?.videoTrackPublications
        .where((p) => p.source == lk.TrackSource.camera)
        .firstOrNull;
    final track = pub?.track;
    if (track is! lk.LocalVideoTrack) {
      return;
    }
    final next = !frontCamera;
    try {
      if (kIsWeb) {
        final cameras = await lk.Hardware.instance.videoInputs();
        if (cameras.length > 1) {
          final wanted = cameras.where((c) {
            final label = c.label.toLowerCase();
            return next
                ? label.contains('front') || label.contains('user')
                : label.contains('back') ||
                      label.contains('rear') ||
                      label.contains('environment');
          }).firstOrNull;
          final current = track.currentOptions;
          final currentId = current is lk.CameraCaptureOptions
              ? current.deviceId
              : null;
          final target =
              wanted ??
              cameras[(cameras.indexWhere((c) => c.deviceId == currentId) + 1) %
                  cameras.length];
          await track.switchCamera(target.deviceId);
          frontCamera = next;
          _notify();
          return;
        }
      }
      await track.setCameraPosition(
        next ? lk.CameraPosition.front : lk.CameraPosition.back,
      );
      frontCamera = next;
    } on Object {
      // Keep the current camera when the device has no other one.
    }
    _notify();
  }

  Future<void> toggleScreenShare() async {
    final next = !screenOn;
    try {
      await room?.localParticipant?.setScreenShareEnabled(next);
      screenOn = next;
    } on Object {
      screenOn = false;
    }
    _notify();
  }

  /// Ends the broadcast for everyone.
  Future<void> endBroadcast() async {
    if (!demo) {
      try {
        await learn.repo.liveKit(
          'end',
          userId: userId,
          sessionId: sessionId,
          peakViewers: peakViewers,
        );
      } on Object {
        // Closing the room below still stops the stream for everyone.
      }
    }
    await _closeRoom();
    state = LiveConnState.ended;
    _notify();
  }

  Future<void> _closeRoom() async {
    final r = room;
    room = null;
    await _events?.dispose();
    _events = null;
    if (r != null) {
      await r.disconnect();
      await r.dispose();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_closeRoom());
    super.dispose();
  }
}

/// Video area of a LiveKit session for students.
class LiveKitViewerStage extends StatefulWidget {
  const LiveKitViewerStage({
    required this.session,
    required this.teacherName,
    super.key,
  });

  final EpsLiveSession session;
  final String? teacherName;

  @override
  State<LiveKitViewerStage> createState() => _LiveKitViewerStageState();
}

class _LiveKitViewerStageState extends State<LiveKitViewerStage> {
  late final LiveRoomConnection conn = LiveRoomConnection(
    learn: LearnScope.read(context),
    userId: StoreScope.of(context).currentUser!.id,
    sessionId: widget.session.id,
    host: false,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!conn.demo) {
        conn.join();
      }
    });
  }

  @override
  void didUpdateWidget(LiveKitViewerStage old) {
    super.didUpdateWidget(old);
    // The teacher went live after the student opened the room.
    if (!old.session.isLiveFlag &&
        widget.session.isLiveFlag &&
        conn.state != LiveConnState.connecting &&
        conn.room == null &&
        !conn.demo) {
      conn.join();
    }
  }

  @override
  void dispose() {
    conn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: conn,
      builder: (context, _) {
        final video = conn.mainVideo;
        final ended =
            conn.state == LiveConnState.ended ||
            widget.session.state == LiveState.past;
        Widget message(IconData icon, String title, String body) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white70, size: 30),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9, color: Colors.white70),
                ),
              ],
            ),
          ),
        );
        return _LiveFrame(
          viewers: conn.demo ? widget.session.attendees : conn.viewers + 1,
          showLive: !ended,
          child: ended
              ? message(
                  Icons.check_circle_outline_rounded,
                  'انتهت الجلسة',
                  'شكراً لحضورك',
                )
              : switch (conn.state) {
                  LiveConnState.idle || LiveConnState.connecting => message(
                    Icons.wifi_tethering_rounded,
                    'جارٍ الاتصال بالبث...',
                    widget.teacherName == null
                        ? ''
                        : 'مع ${widget.teacherName}',
                  ),
                  LiveConnState.failed => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        message(
                          Icons.wifi_off_rounded,
                          'تعذر الدخول إلى البث',
                          conn.error,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: conn.join,
                          child: const Text(
                            'إعادة المحاولة',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ when video == null => message(
                    Icons.hourglass_top_rounded,
                    'بانتظار الأستاذ',
                    'سيظهر البث هنا فور بدئه',
                  ),
                  _ => Stack(
                    children: [
                      Positioned.fill(
                        child: lk.VideoTrackRenderer(
                          video,
                          fit: conn.mainIsScreen
                              ? lk.VideoViewFit.contain
                              : lk.VideoViewFit.cover,
                        ),
                      ),
                      if (!conn.canPlayAudio)
                        Center(
                          child: FilledButton.icon(
                            onPressed: conn.startAudio,
                            icon: const Icon(Icons.volume_up_rounded),
                            label: const Text('تشغيل الصوت'),
                          ),
                        ),
                    ],
                  ),
                },
        );
      },
    );
  }
}

/// Dark video frame with the close button, LIVE badge and viewer count.
class _LiveFrame extends StatelessWidget {
  const _LiveFrame({
    required this.child,
    required this.viewers,
    this.showLive = true,
  });

  final Widget child;
  final int viewers;
  final bool showLive;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      height: 245 + top,
      padding: EdgeInsets.only(top: top),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17213B), Color(0xFF203A75)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 16,
            top: 15,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0x40000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
          ),
          if (showLive)
            const Positioned(
              right: 18,
              top: 18,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: EpsBadge('LIVE', tone: EpsTone.red, icon: Icons.circle),
              ),
            ),
          Positioned(
            right: 18,
            bottom: 14,
            child: _ViewerCount(count: viewers),
          ),
        ],
      ),
    );
  }
}

class _ViewerCount extends StatelessWidget {
  const _ViewerCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x77000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontFamily: Eps.fontNum,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.group_outlined, size: 12, color: Colors.white),
        ],
      ),
    );
  }
}

/// Sessions a teacher hosts, with "new session" and "go live".
class LiveHostPage extends StatefulWidget {
  const LiveHostPage({super.key});

  @override
  State<LiveHostPage> createState() => _LiveHostPageState();
}

class _LiveHostPageState extends State<LiveHostPage> {
  List<EpsLiveSession> sessions = [];
  List<EpsSubject> subjects = [];
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  AppUser get me => StoreScope.of(context).currentUser!;

  bool get isAdmin => me.role == UserRole.admin;

  Future<void> load() async {
    final learn = LearnScope.read(context);
    if (!learn.enabled) {
      setState(() {
        sessions = [...learn.liveSessions];
        subjects = [...learn.subjects];
        loading = false;
      });
      return;
    }
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final results = await Future.wait<Object>([
        learn.repo.hostedSessions(isAdmin ? null : me.id),
        learn.repo.subjects(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        sessions = results[0] as List<EpsLiveSession>;
        final all = results[1] as List<EpsSubject>;
        final mine = all.where((s) => s.teacherId == me.id).toList();
        subjects = isAdmin || mine.isEmpty ? all : mine;
        loading = false;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewSessionSheet(subjects: subjects, hostId: me.id),
    );
    if (created == true) {
      await load();
    }
  }

  Future<void> open(EpsLiveSession session) async {
    LearnScope.read(context).replaceLiveSession(session);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveStudioScreen(session: session),
      ),
    );
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final live = sessions.where((s) => s.state == LiveState.live).toList();
    final upcoming =
        sessions.where((s) => s.state == LiveState.upcoming).toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final past = sessions.where((s) => s.state == LiveState.past).toList();
    String subjectName(EpsLiveSession s) =>
        subjects.where((x) => x.id == s.subjectId).firstOrNull?.name ?? '';
    Widget tile(EpsLiveSession s) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: FlatCard(
        onTap: s.state == LiveState.past ? null : () => open(s),
        child: Row(
          children: [
            EpsMark(
              icon: s.state == LiveState.live
                  ? Icons.sensors_rounded
                  : s.state == LiveState.upcoming
                  ? Icons.event_rounded
                  : Icons.video_library_outlined,
              tone: s.state == LiveState.live
                  ? EpsTone.red
                  : s.state == LiveState.upcoming
                  ? EpsTone.blue
                  : EpsTone.gray,
              size: 40,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Eps.ink,
                    ),
                  ),
                  Text(
                    [
                      subjectName(s),
                      liveWhen(s.startsAt),
                      '${s.durationMinutes} دقيقة',
                    ].where((x) => x.isNotEmpty).join(' • '),
                    style: const TextStyle(fontSize: 8, color: Eps.muted),
                  ),
                  if (s.state == LiveState.past)
                    Text(
                      '${s.attendees} مشاهد',
                      style: const TextStyle(fontSize: 8, color: Eps.muted),
                    ),
                ],
              ),
            ),
            if (s.state != LiveState.past)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: s.state == LiveState.live ? Eps.red : Eps.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  s.isLiveFlag ? 'متابعة البث' : 'ابدأ البث',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return EpsPage(
      title: 'البث المباشر',
      action: EpsIconButton(
        icon: Icons.refresh_rounded,
        tooltip: 'تحديث',
        onTap: load,
      ),
      children: [
        EpsPrimaryButton(
          label: 'جدولة جلسة جديدة',
          icon: Icons.add_rounded,
          onPressed: create,
        ),
        const SizedBox(height: 14),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Eps.red, fontSize: 10))
        else if (sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Text(
              'لا توجد جلسات بعد. جدول جلستك الأولى ليتم إشعار طلابك.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Eps.muted),
            ),
          )
        else ...[
          if (live.isNotEmpty) ...[
            const HomeSectionTitle('مباشر الآن'),
            for (final s in live) tile(s),
          ],
          if (upcoming.isNotEmpty) ...[
            const HomeSectionTitle('الجلسات القادمة'),
            for (final s in upcoming) tile(s),
          ],
          if (past.isNotEmpty) ...[
            const HomeSectionTitle('الجلسات السابقة'),
            for (final s in past.take(15)) tile(s),
          ],
        ],
      ],
    );
  }
}

class _NewSessionSheet extends StatefulWidget {
  const _NewSessionSheet({required this.subjects, required this.hostId});

  final List<EpsSubject> subjects;
  final String hostId;

  @override
  State<_NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends State<_NewSessionSheet> {
  final title = TextEditingController();
  String? subjectId;
  DateTime startsAt = DateTime.now().add(const Duration(hours: 1));
  int duration = 60;
  bool free = false;
  bool saving = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    subjectId = widget.subjects.firstOrNull?.id;
    startsAt = DateTime(
      startsAt.year,
      startsAt.month,
      startsAt.day,
      startsAt.hour,
    );
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> pickTime() async {
    final day = await showDatePicker(
      context: context,
      initialDate: startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (day == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(startsAt),
    );
    if (time == null) {
      return;
    }
    setState(
      () => startsAt = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty || subjectId == null) {
      setState(() => error = 'اكتب عنوان الجلسة واختر المادة');
      return;
    }
    final learn = LearnScope.read(context);
    setState(() {
      saving = true;
      error = '';
    });
    final row = {
      'title': title.text.trim(),
      'subject_id': subjectId,
      'teacher_id': widget.hostId,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'duration_minutes': duration,
      'is_free': free,
    };
    try {
      if (learn.enabled) {
        await learn.repo.createLiveSession(row);
      } else {
        learn.replaceLiveSession(
          EpsLiveSession.fromRow({
            ...row,
            'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
          }),
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (e) {
      setState(() {
        saving = false;
        error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'جلسة مباشرة جديدة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'عنوان الجلسة',
                  hintText: 'مثال: مراجعة الفصل الثالث',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: subjectId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المادة'),
                items: [
                  for (final s in widget.subjects)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => subjectId = v),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: pickTime,
                icon: const Icon(Icons.event_rounded),
                label: Text(
                  '${startsAt.day} ${arMonth(startsAt)} • ${hhmm(startsAt)}',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('المدة', style: TextStyle(fontSize: 11)),
                  const Spacer(),
                  for (final d in const [45, 60, 90, 120])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: ChoiceChip(
                        label: Text('$d د'),
                        selected: duration == d,
                        onSelected: (_) => setState(() => duration = d),
                      ),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: free,
                onChanged: (v) => setState(() => free = v),
                title: const Text(
                  'جلسة مجانية لكل الطلاب',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    error,
                    style: const TextStyle(color: Eps.red, fontSize: 10),
                  ),
                ),
              EpsPrimaryButton(
                label: saving ? 'جارٍ الحفظ...' : 'حفظ الجلسة',
                onPressed: saving ? null : save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The teacher's broadcast screen: camera, controls, chat and questions.
class LiveStudioScreen extends StatefulWidget {
  const LiveStudioScreen({required this.session, super.key});

  final EpsLiveSession session;

  @override
  State<LiveStudioScreen> createState() => _LiveStudioScreenState();
}

class _LiveStudioScreenState extends State<LiveStudioScreen> {
  late final LearnStore learn = LearnScope.read(context);
  late final AppUser me = StoreScope.of(context).currentUser!;
  late final LiveRoomConnection conn = LiveRoomConnection(
    learn: learn,
    userId: me.id,
    sessionId: widget.session.id,
    host: true,
  );
  late final LiveChat chat = LiveChat(
    learn: learn,
    sessionId: widget.session.id,
  );
  final input = TextEditingController();
  bool questionsTab = true;
  Timer? clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => chat.start());
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (conn.state == LiveConnState.connected && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    input.dispose();
    chat.dispose();
    conn.dispose();
    super.dispose();
  }

  Future<void> end() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('إنهاء البث؟'),
        content: const Text('سيخرج جميع الطلاب من الجلسة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('متابعة البث'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Eps.red),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('إنهاء'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await conn.endBroadcast();
    }
  }

  String elapsed() {
    final since = conn.liveSince;
    if (since == null) {
      return '00:00';
    }
    final d = DateTime.now().difference(since);
    String two(int v) => v.toString().padLeft(2, '0');
    return d.inHours > 0
        ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
        : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([conn, chat]),
      builder: (context, _) {
        final live = conn.state == LiveConnState.connected;
        return PopScope(
          canPop: !live,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              end();
            }
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                _studioStage(live),
                if (live) _controls(),
                _chatTabs(),
                Expanded(child: _chatList()),
                if (conn.state != LiveConnState.ended) _composer(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _studioStage(bool live) {
    final video = conn.mainVideo;
    Widget center;
    switch (conn.state) {
      case LiveConnState.idle:
      case LiveConnState.failed:
        center = Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.session.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  conn.state == LiveConnState.failed
                      ? conn.error
                      : 'سيتم إشعار الطلاب المشتركين فور بدء البث.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: conn.state == LiveConnState.failed
                        ? const Color(0xFFFFB4BB)
                        : Colors.white70,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Eps.red,
                    minimumSize: const Size(170, 46),
                  ),
                  onPressed: conn.startBroadcast,
                  icon: const Icon(Icons.sensors_rounded),
                  label: Text(
                    conn.state == LiveConnState.failed
                        ? 'إعادة المحاولة'
                        : widget.session.isLiveFlag
                        ? 'متابعة البث'
                        : 'ابدأ البث الآن',
                  ),
                ),
              ],
            ),
          ),
        );
      case LiveConnState.connecting:
        center = const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 10),
              Text(
                'جارٍ تشغيل الكاميرا والاتصال...',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ],
          ),
        );
      case LiveConnState.ended:
        center = const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 32,
              ),
              SizedBox(height: 6),
              Text(
                'انتهى البث',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                'شكراً لك، خرج الطلاب من الجلسة',
                style: TextStyle(fontSize: 9, color: Colors.white70),
              ),
            ],
          ),
        );
      case LiveConnState.connected:
        center = video != null
            ? lk.VideoTrackRenderer(
                video,
                key: ValueKey(conn.frontCamera),
                mirrorMode: conn.frontCamera && !conn.mainIsScreen
                    ? lk.VideoViewMirrorMode.mirror
                    : lk.VideoViewMirrorMode.off,
                fit: conn.mainIsScreen
                    ? lk.VideoViewFit.contain
                    : lk.VideoViewFit.cover,
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      conn.cameraOn
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_rounded,
                      color: Colors.white70,
                      size: 30,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      conn.demo
                          ? 'وضع المعاينة: ستظهر الكاميرا هنا'
                          : conn.cameraOn
                          ? 'جارٍ تشغيل الكاميرا...'
                          : 'الكاميرا متوقفة، الطلاب يسمعونك فقط',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              );
    }
    return Stack(
      children: [
        _LiveFrame(viewers: conn.viewers, showLive: false, child: center),
        if (live)
          PositionedDirectional(
            start: 18,
            top: MediaQuery.paddingOf(context).top + 18,
            child: Row(
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: EpsBadge(
                    'LIVE ${elapsed()}',
                    tone: EpsTone.red,
                    icon: Icons.circle,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _controls() {
    Widget button(
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool active = true,
      Color? color,
    }) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color ?? (active ? Eps.blueSoft : Eps.gray),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: color != null
                    ? Colors.white
                    : active
                    ? Eps.blue
                    : Eps.grayInk,
              ),
            ),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 8, color: Eps.ink)),
          ],
        ),
      ),
    );
    // Phones (app or browser) can switch camera; computers share the screen.
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
      child: Row(
        children: [
          button(
            conn.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            conn.micOn ? 'الميكروفون' : 'مكتوم',
            conn.toggleMic,
            active: conn.micOn,
          ),
          button(
            conn.cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            'الكاميرا',
            conn.toggleCamera,
            active: conn.cameraOn,
          ),
          if (mobile)
            button(Icons.cameraswitch_rounded, 'تبديل', conn.flipCamera)
          else
            button(
              Icons.screen_share_outlined,
              conn.screenOn ? 'إيقاف المشاركة' : 'مشاركة الشاشة',
              conn.toggleScreenShare,
              active: conn.screenOn,
            ),
          button(Icons.call_end_rounded, 'إنهاء', end, color: Eps.red),
        ],
      ),
    );
  }

  Widget _chatTabs() {
    final open = chat.questions.where((q) => !q.answered).length;
    Widget tab(
      String label,
      bool selected,
      VoidCallback onTap, [
      int? n,
    ]) => GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? Eps.blue : Eps.muted,
            ),
          ),
          if (n != null) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Eps.orangeSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$n',
                style: const TextStyle(fontSize: 10, color: Color(0xFFB87400)),
              ),
            ),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Row(
        children: [
          tab(
            'أسئلة الطلاب',
            questionsTab,
            () => setState(() => questionsTab = true),
            open,
          ),
          const SizedBox(width: 25),
          tab(
            'المحادثة',
            !questionsTab,
            () => setState(() => questionsTab = false),
          ),
        ],
      ),
    );
  }

  Widget _chatList() {
    final items = questionsTab
        ? ([...chat.questions]..sort((a, b) {
            if (a.answered != b.answered) {
              return a.answered ? 1 : -1;
            }
            return a.createdAt.compareTo(b.createdAt);
          }))
        : chat.messages;
    if (items.isEmpty) {
      return Center(
        child: Text(
          questionsTab ? 'لا توجد أسئلة بعد' : 'لا توجد رسائل بعد',
          style: const TextStyle(fontSize: 10, color: Eps.muted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 6),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        if (!questionsTab) {
          return _ChatBubble(message: m);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Opacity(
            opacity: m.answered ? 0.55 : 1,
            child: FlatCard(
              shadow: false,
              radius: 12,
              padding: const EdgeInsets.fromLTRB(11, 8, 6, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${m.userName} • ${hhmm(m.createdAt)}',
                          style: const TextStyle(fontSize: 8, color: Eps.muted),
                        ),
                        Text(
                          m.body,
                          style: const TextStyle(fontSize: 10, color: Eps.ink),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => chat.setAnswered(m, !m.answered),
                    icon: Icon(
                      m.answered
                          ? Icons.check_circle_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: Eps.green,
                    ),
                    label: Text(
                      m.answered ? 'تمت الإجابة' : 'أجبت',
                      style: const TextStyle(fontSize: 9, color: Eps.green),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _composer() {
    Future<void> send() async {
      final text = input.text;
      if (text.trim().isEmpty) {
        return;
      }
      input.clear();
      // The teacher's own messages are in the chat tab.
      setState(() => questionsTab = false);
      try {
        await chat.send(me, text, teacher: true);
      } on Object catch (e) {
        input.text = text;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('لم تُرسل الرسالة: $e')));
        }
      }
    }

    return SafeArea(
      top: false,
      child: Container(
        height: 42,
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.only(left: 4, right: 12),
        decoration: BoxDecoration(
          color: Eps.gray,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: input,
                onSubmitted: (_) => send(),
                style: const TextStyle(fontSize: 9),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: 'اكتب رسالة للطلاب...',
                  hintStyle: TextStyle(fontSize: 9, color: Eps.faint),
                ),
              ),
            ),
            GestureDetector(
              onTap: send,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Eps.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
