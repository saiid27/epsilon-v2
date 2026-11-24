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

  Future<void> load() async {
    try {
      final g = await repo.chatGroupFor(widget.subjectId);
      final list = await repo.chatMessages(g.id);
      final r = await repo.chatReactions([for (final m in list) m.id]);
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
      );
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

  @override
  Widget build(BuildContext context) {
    final g = group;
    final user = me;
    final locked = g?.locked ?? false;
    final canPost = isStaff || !locked;
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: EpsPageHeader(
                title: widget.subjectName,
                onBack: () => Navigator.of(context).maybePop(),
                action: isStaff
                    ? EpsIconButton(
                        icon: locked
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        tooltip: locked ? 'فتح المجموعة' : 'قفل المجموعة',
                        onTap: toggleLock,
                      )
                    : null,
              ),
            ),
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _Bubble(
                    message: messages[i],
                    mine: user != null && messages[i].senderId == user.id,
                    reactions: reactions[messages[i].id] ?? const [],
                    onLongPress: () => showReactions(messages[i]),
                    onPlay: playVoice,
                  ),
                ),
              ),
            if (locked && !isStaff)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Eps.orangeSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'المجموعة مقفلة الآن. سيفتحها الأستاذ لتطرح أسئلتك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Eps.orangeInk),
                ),
              ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  error,
                  style: const TextStyle(fontSize: 10, color: Eps.red),
                ),
              ),
            if (canPost && group != null)
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                color: Colors.white,
                child: Row(
                  children: [
                    if (isStaff)
                      IconButton(
                        tooltip: 'صورة',
                        icon: const Icon(Icons.image_outlined, color: Eps.blue),
                        onPressed: sending ? null : pickImage,
                      ),
                    if (!isStaff || input.text.trim().isEmpty)
                      IconButton(
                        tooltip: recording ? 'إيقاف وإرسال' : 'رسالة صوتية',
                        icon: Icon(
                          recording
                              ? Icons.stop_circle_rounded
                              : Icons.mic_rounded,
                          color: recording ? Eps.red : Eps.blue,
                        ),
                        onPressed: sending ? null : toggleRecording,
                      ),
                    Expanded(
                      child: TextField(
                        controller: input,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: isStaff
                              ? 'اكتب للمجموعة...'
                              : 'اطرح سؤالك...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (!recording)
                      IconButton(
                        tooltip: 'إرسال',
                        icon: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, color: Eps.blue),
                        onPressed: sending ? null : () => send(),
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
  });

  final EpsChatMessage message;
  final bool mine;
  final List<EpsChatReaction> reactions;
  final VoidCallback onLongPress;
  final void Function(String url) onPlay;

  @override
  Widget build(BuildContext context) {
    // Count each emoji, to show under the bubble like WhatsApp does.
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    final time = message.createdAt.toLocal();
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
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: mine ? Eps.blue : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: mine ? null : Border.all(color: Eps.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine && message.senderName.isNotEmpty)
                    Text(
                      message.senderName,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Eps.blue,
                      ),
                    ),
                  if (message.audioUrl.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.play_circle_fill_rounded,
                            color: mine ? Colors.white : Eps.blue,
                            size: 30,
                          ),
                          onPressed: () => onPlay(message.audioUrl),
                        ),
                        Text(
                          '${message.audioSeconds} ث',
                          style: TextStyle(
                            fontSize: 10,
                            color: mine ? Colors.white : Eps.ink,
                          ),
                        ),
                      ],
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
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          message.imageUrl,
                          fit: BoxFit.cover,
                          width: 200,
                        ),
                      ),
                    ),
                  if (message.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        message.body,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: mine ? Colors.white : Eps.ink,
                        ),
                      ),
                    ),
                  Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 8,
                      color: mine ? Colors.white70 : Eps.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (counts.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Eps.line),
                ),
                child: Text(
                  counts.entries
                      .map((e) => e.value > 1 ? '${e.key} ${e.value}' : e.key)
                      .join('  '),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
