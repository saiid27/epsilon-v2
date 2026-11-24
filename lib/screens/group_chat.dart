part of '../main.dart';

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
      if (mounted) {
        setState(() {
          group = g;
          messages = list;
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
      if (mounted && (fresh.isNotEmpty || lockNow.locked != g.locked)) {
        setState(() {
          messages = [...messages, ...fresh];
          group = lockNow;
        });
        if (fresh.isNotEmpty) scrollToEnd();
      }
    } on Object {
      // A missed poll is retried in a few seconds.
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
                    IconButton(
                      tooltip: 'إرسال',
                      icon: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
  const _Bubble({required this.message, required this.mine});

  final EpsChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 8),
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
              '${message.createdAt.toLocal().hour.toString().padLeft(2, '0')}:${message.createdAt.toLocal().minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 8,
                color: mine ? Colors.white70 : Eps.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
