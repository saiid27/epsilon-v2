part of '../main.dart';

const _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// The chat group of one subject, like a WhatsApp group. The teacher posts
/// text and images, and can lock the group; students ask while it is open.
class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    required this.subjectId,
    required this.subjectName,
    super.key,
  });

  final String subjectId;
  final String subjectName;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  EpsChatGroup? group;
  List<EpsChatMessage> messages = [];
  // message id -> the reactions on it
  Map<String, List<EpsChatReaction>> reactions = {};
  final recorder = AudioRecorder();
  final player = AudioPlayer();
  bool recording = false;
  EpsChatMessage? replyingTo;
  bool loading = true;
  bool sending = false;
  String error = '';
  Timer? poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await load();
      // New messages arrive every few seconds without leaving the screen.
      poll = Timer.periodic(const Duration(seconds: 4), (_) => refresh());
    });
  }

  @override
  void dispose() {
    poll?.cancel();
    recorder.dispose();
    player.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  LearnRepository get repo => LearnScope.read(context).repo;

  AppUser? get me => StoreScope.of(context).currentUser;

  bool get isStaff =>
      me?.role == UserRole.teacher || me?.role == UserRole.admin;

  bool get lockedOut {
    final learn = LearnScope.read(context);
    return !isStaff && !learn.hasAccess(widget.subjectId);
  }

  Future<void> load() async {
    // A student who did not subscribe to the subject cannot open its group.
    if (lockedOut) {
      if (mounted) setState(() => loading = false);
      return;
    }
    // Show the kept messages at once, then update them from the server.
    final cachedGroup = group?.id ?? await _cachedGroupId();
    if (cachedGroup != null && messages.isEmpty) {
      final cached = await ChatCache.load(cachedGroup);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          messages = cached;
          loading = false;
        });
        scrollToEnd();
      }
    }
    try {
      final g = await repo.chatGroupFor(widget.subjectId);
      final list = await repo.chatMessages(g.id);
      final r = await repo.chatReactions([for (final m in list) m.id]);
      await ChatCache.save(g.id, list);
      if (mounted) {
        setState(() {
          group = g;
          messages = list;
          reactions = groupReactions(r);
          loading = false;
          error = '';
        });
        scrollToEnd();
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'تعذر فتح المجموعة: ${friendlyApiError(e)}';
        });
      }
    }
  }

  Future<String?> _cachedGroupId() async {
    try {
      final g = await repo.chatGroupFor(widget.subjectId);
      return g.id;
    } on Object {
      return null;
    }
  }

  Future<void> refresh() async {
    final g = group;
    if (g == null || !mounted) return;
    try {
      final last = messages.isEmpty ? null : messages.last.createdAt;
      final fresh = await repo.chatMessages(g.id, after: last);
      final lockNow = await repo.chatGroupFor(widget.subjectId);
      final r = await repo.chatReactions([for (final m in messages) m.id]);
      if (mounted) {
        setState(() {
          messages = [...messages, ...fresh];
          group = lockNow;
          reactions = groupReactions(r);
        });
        if (fresh.isNotEmpty) scrollToEnd();
      }
    } on Object {
      // A missed poll is retried in a few seconds.
    }
  }

  Map<String, List<EpsChatReaction>> groupReactions(
    List<EpsChatReaction> list,
  ) {
    final out = <String, List<EpsChatReaction>>{};
    for (final r in list) {
      out.putIfAbsent(r.messageId, () => []).add(r);
    }
    return out;
  }

  Future<void> react(EpsChatMessage m, String emoji) async {
    final user = me;
    if (user == null) return;
    final mine = (reactions[m.id] ?? const <EpsChatReaction>[])
        .where((r) => r.userId == user.id)
        .firstOrNull;
    try {
      await repo.toggleChatReaction(
        messageId: m.id,
        userId: user.id,
        emoji: emoji,
        removeSame: mine?.emoji == emoji,
      );
      await refresh();
    } on Object catch (e) {
      if (mounted) setState(() => error = friendlyApiError(e));
    }
  }

  void showReactions(EpsChatMessage m) {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(c);
                  setState(() => replyingTo = m);
                },
                icon: const Icon(Icons.reply_rounded),
                label: const Text('رد'),
              ),
              for (final e in _reactionEmojis)
                InkWell(
                  onTap: () {
                    Navigator.pop(c);
                    react(m, e);
                  },
                  child: Text(e, style: const TextStyle(fontSize: 30)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> toggleRecording() async {
    final g = group;
    final user = me;
    if (g == null || user == null) return;
    if (kIsWeb) {
      setState(() => error = 'التسجيل الصوتي متاح في التطبيق على الهاتف.');
      return;
    }
    try {
      if (!recording) {
        if (!await recorder.hasPermission()) {
          setState(() => error = 'اسمح للتطبيق باستعمال الميكروفون.');
          return;
        }
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        recordStarted = DateTime.now();
        setState(() {
          recording = true;
          error = '';
        });
        return;
      }
      final path = await recorder.stop();
      setState(() => recording = false);
      if (path == null) return;
      final seconds = DateTime.now()
          .difference(recordStarted ?? DateTime.now())
          .inSeconds;
      final bytes = await File(path).readAsBytes();
      if (bytes.length > 7 * 1024 * 1024) {
        setState(() => error = 'التسجيل طويل جداً.');
        return;
      }
      setState(() => sending = true);
      await repo.sendChatVoice(
        groupId: g.id,
        senderId: user.id,
        senderName: user.name,
        bytes: bytes,
        seconds: seconds,
        extension: 'm4a',
      );
      await refresh();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          recording = false;
          error = friendlyApiError(e);
        });
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  DateTime? recordStarted;

  Future<void> playVoice(String url) async {
    try {
      await player.stop();
      await player.play(UrlSource(url));
    } on Object catch (e) {
      if (mounted) setState(() => error = friendlyApiError(e));
    }
  }

  void scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> send({Uint8List? image, String? imageName}) async {
    final g = group;
    final user = me;
    final text = input.text.trim();
    if (g == null || user == null) return;
    if (text.isEmpty && image == null) return;
    setState(() {
      sending = true;
      error = '';
    });
    try {
      await repo.sendChatMessage(
        groupId: g.id,
        senderId: user.id,
        senderName: user.name,
        body: text,
        image: image,
        imageName: imageName,
        replyToId: replyingTo?.id,
      );
      replyingTo = null;
      input.clear();
      await refresh();
    } on Object catch (e) {
      if (mounted) {
        setState(() => error = friendlyApiError(e));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> pickImage() async {
    final picked = await NativeFilePicker.pickImage();
    if (picked == null) return;
    final bytes =
        NativeFilePicker.webFiles[picked.path] ??
        await File(picked.path).readAsBytes();
    if (bytes.length > 7 * 1024 * 1024) {
      setState(() => error = 'الصورة أكبر من 7 ميغابايت.');
      return;
    }
    await send(image: bytes, imageName: picked.name);
  }

  Future<void> toggleLock() async {
    final g = group;
    if (g == null) return;
    try {
      await repo.setChatLocked(g.id, !g.locked);
      await load();
    } on Object catch (e) {
      if (mounted) setState(() => error = friendlyApiError(e));
    }
  }

  static const _wall = Color(0xFF0B141A);
  static const _bar = Color(0xFF1F2C34);
  static const _accent = Color(0xFF00A884);
  static const _muted = Color(0xFF8696A0);

  @override
  Widget build(BuildContext context) {
    final g = group;
    final user = me;
    final locked = g?.locked ?? false;
    final canPost = isStaff || !locked;
    final typing = input.text.trim().isNotEmpty;
    // The list: a date line before the first message of each day.
    final rows = <Object>[];
    DateTime? lastDay;
    for (final m in messages) {
      final d = m.createdAt.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      if (lastDay != day) {
        rows.add(day);
        lastDay = day;
      }
      rows.add(m);
    }
    return Scaffold(
      backgroundColor: _wall,
      body: SafeArea(
        child: Column(
          children: [
            // Header: back, group name and state, and the lock for the teacher.
            Container(
              color: _bar,
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _accent,
                    child: Text(
                      widget.subjectName.characters.first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subjectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          locked ? 'مقفلة • الأستاذ يتكلم' : 'مفتوحة للأسئلة',
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (isStaff)
                    IconButton(
                      tooltip: locked ? 'فتح المجموعة' : 'قفل المجموعة',
                      icon: Icon(
                        locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                        color: Colors.white,
                      ),
                      onPressed: toggleLock,
                    ),
                ],
              ),
            ),
            if (lockedOut)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'هذه المجموعة للمشتركين في المادة. اشترك فيها لفتحها وطرح أسئلتك.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: _muted,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              )
            else if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    if (row is DateTime) {
                      return _DaySeparator(day: row);
                    }
                    final m = row as EpsChatMessage;
                    final idx = messages.indexOf(m);
                    final prev = idx > 0 ? messages[idx - 1] : null;
                    // Same sender within 5 minutes: no repeated name, like WhatsApp.
                    final sameRun =
                        prev != null &&
                        prev.senderId == m.senderId &&
                        m.createdAt.difference(prev.createdAt).inMinutes < 5;
                    return _Bubble(
                      message: m,
                      mine: user != null && m.senderId == user.id,
                      reactions: reactions[m.id] ?? const [],
                      quoted: m.replyTo == null
                          ? null
                          : messages
                                .where((x) => x.id == m.replyTo)
                                .firstOrNull,
                      showName: !sameRun,
                      onLongPress: () => showReactions(m),
                      onPlay: playVoice,
                    );
                  },
                ),
              ),
            if (replyingTo != null)
              Container(
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                decoration: BoxDecoration(
                  color: _bar,
                  borderRadius: BorderRadius.circular(10),
                  border: const Border(
                    left: BorderSide(color: _accent, width: 4),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            replyingTo!.senderName,
                            style: const TextStyle(
                              color: _accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            replyingTo!.body.isNotEmpty
                                ? replyingTo!.body
                                : (replyingTo!.imageUrl.isNotEmpty
                                      ? 'صورة'
                                      : 'رسالة صوتية'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _muted),
                      onPressed: () => setState(() => replyingTo = null),
                    ),
                  ],
                ),
              ),
            if (locked && !isStaff)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _bar,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'المجموعة مقفلة الآن. سيفتحها الأستاذ لتطرح أسئلتك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
              ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                child: Text(
                  error,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFFF6B6B),
                  ),
                ),
              ),
            if (canPost && group != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: _bar,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.sentiment_satisfied_alt_outlined,
                                color: _muted,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: input,
                                minLines: 1,
                                maxLines: 4,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: isStaff
                                      ? 'اكتب للمجموعة'
                                      : 'اطرح سؤالك',
                                  hintStyle: const TextStyle(color: _muted),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (isStaff)
                              IconButton(
                                tooltip: 'صورة',
                                icon: const Icon(
                                  Icons.attach_file_rounded,
                                  color: _muted,
                                ),
                                onPressed: sending ? null : pickImage,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: sending
                          ? null
                          : (typing ? () => send() : toggleRecording),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: recording
                            ? const Color(0xFFE53935)
                            : _accent,
                        child: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                typing
                                    ? Icons.send_rounded
                                    : (recording
                                          ? Icons.stop_rounded
                                          : Icons.mic_rounded),
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.reactions,
    required this.onLongPress,
    required this.onPlay,
    this.quoted,
    this.showName = true,
  });

  final EpsChatMessage message;
  final bool mine;
  final List<EpsChatReaction> reactions;
  final EpsChatMessage? quoted;
  final bool showName;
  final VoidCallback onLongPress;
  final void Function(String url) onPlay;

  static const _muted = Color(0xFF8696A0);
  static const _nameColors = [
    Color(0xFF53BDEB),
    Color(0xFFFFD279),
    Color(0xFFFF7EB6),
    Color(0xFF7AD17A),
  ];

  Color get nameColor =>
      _nameColors[message.senderName.hashCode.abs() % _nameColors.length];

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    final time = message.createdAt.toLocal();
    final timeText =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              decoration: BoxDecoration(
                color: mine ? _ChatStyle.outgoing : _ChatStyle.incoming,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (quoted != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: const Border(
                          left: BorderSide(color: Color(0xFF53BDEB), width: 3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quoted!.senderName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF53BDEB),
                            ),
                          ),
                          Text(
                            quoted!.body.isNotEmpty
                                ? quoted!.body
                                : (quoted!.imageUrl.isNotEmpty
                                      ? 'صورة'
                                      : 'رسالة صوتية'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFB0BEC5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!mine && showName && message.senderName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: nameColor,
                        ),
                      ),
                    ),
                  if (message.audioUrl.isNotEmpty)
                    _VoiceRow(
                      seed: message.id,
                      seconds: message.audioSeconds,
                      onPlay: () => onPlay(message.audioUrl),
                    ),
                  if (message.imageUrl.isNotEmpty)
                    GestureDetector(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (c) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(message.imageUrl),
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.network(
                          message.imageUrl,
                          fit: BoxFit.cover,
                          width: 230,
                        ),
                      ),
                    ),
                  if (message.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        message.body,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Color(0xFFE9EDEF),
                        ),
                      ),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      timeText,
                      style: const TextStyle(fontSize: 10, color: _muted),
                    ),
                  ),
                ],
              ),
            ),
            if (counts.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8, top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _ChatStyle.bar,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  counts.entries
                      .map((e) => e.value > 1 ? '${e.key} ${e.value}' : e.key)
                      .join('  '),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A line with the day of the messages below it ("اليوم", "أمس", or the date).
class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    final label = diff == 0
        ? 'اليوم'
        : diff == 1
        ? 'أمس'
        : '${day.day}/${day.month}/${day.year}';
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _ChatStyle.bar,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8696A0)),
        ),
      ),
    );
  }
}

/// Colours of the chat screen, shared by the bubbles.
class _ChatStyle {
  static const incoming = Color(0xFF1F2C34);
  static const outgoing = Color(0xFF005C4B);
  static const bar = Color(0xFF1F2C34);
}

/// A voice note row: play button, a waveform, and the length.
class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.seed,
    required this.seconds,
    required this.onPlay,
  });

  final String seed;
  final int seconds;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPlay,
          child: const CircleAvatar(
            radius: 19,
            backgroundColor: Color(0xFF00A884),
            child: Icon(Icons.play_arrow_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(width: 6),
        CustomPaint(size: const Size(130, 28), painter: _WavePainter(seed)),
        const SizedBox(width: 6),
        Text(
          '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF8696A0)),
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.seed);

  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8696A0)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    final bars = 28;
    final step = size.width / bars;
    // A stable pattern per message, so the bars do not change on rebuild.
    var h = seed.hashCode;
    for (var i = 0; i < bars; i++) {
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      final level = 0.25 + (h % 70) / 100;
      final x = i * step + step / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - size.height * level / 2),
        Offset(x, size.height / 2 + size.height * level / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.seed != seed;
}
