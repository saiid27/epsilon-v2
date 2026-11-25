part of '../main.dart';

/// The messages of one group kept on the phone, so the chat opens at once and
/// reads offline. The newest 1000 messages are kept per group.
class ChatCache {
  static String _key(String groupId) => 'chat_cache_$groupId';

  static Future<List<EpsChatMessage>> load(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(groupId));
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return [
        for (final m in list)
          EpsChatMessage.fromRow(Map<String, dynamic>.from(m as Map)),
      ];
    } on Object {
      return [];
    }
  }

  static Future<void> save(
    String groupId,
    List<EpsChatMessage> messages,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keep = messages.length > 1000
          ? messages.sublist(messages.length - 1000)
          : messages;
      await prefs.setString(
        _key(groupId),
        jsonEncode([
          for (final m in keep)
            {
              'id': m.id,
              'group_id': m.groupId,
              'sender_id': m.senderId,
              'sender_name': m.senderName,
              'body': m.body,
              'image_url': m.imageUrl,
              'audio_url': m.audioUrl,
              'audio_seconds': m.audioSeconds,
              'video_url': m.videoUrl,
              'reply_to': m.replyTo,
              'created_at': m.createdAt.toUtc().toIso8601String(),
            },
        ]),
      );
    } on Object {
      // The cache is a convenience: a failed save never breaks the chat.
    }
  }
}

/// The groups a user sees: a teacher or admin sees all of them. A student sees
/// the subjects of the sections they subscribed to (a section is chosen by
/// subscribing to one of its subjects); the groups they did not subscribe to
/// are listed with a lock.
List<EpsSubject> visibleChatSubjects(LearnStore learn, bool staff) {
  if (staff) return [...learn.subjects];
  final mySections = <String?>{
    for (final s in learn.subjects)
      if (learn.hasAccess(s.id)) s.courseId,
  };
  return [
    for (final s in learn.subjects)
      if (mySections.contains(s.courseId)) s,
  ];
}

/// The student's subject chats, grouped by section. Starred groups come first.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool loading = true;
  String error = '';
  Map<String, EpsChatGroup> groups = {};
  Map<String, EpsChatMessage> latest = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final learn = LearnScope.read(context);
    final store = StoreScope.of(context);
    final user = store.currentUser;
    final staff =
        user?.role == UserRole.teacher || user?.role == UserRole.admin;
    // Only the groups of the student's sections; the ones not subscribed are locked.
    final visible = visibleChatSubjects(learn, staff);
    final subjectIds = [for (final s in visible) s.id];
    final openIds = {
      for (final s in visible)
        if (staff || learn.hasAccess(s.id)) s.id,
    };
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final gs = await learn.repo.chatGroupsFor(subjectIds);
      // Previews only for the groups this student can open.
      final ms = await learn.repo.latestChatMessages([
        for (final g in gs)
          if (openIds.contains(g.subjectId)) g.id,
      ]);
      final last = <String, EpsChatMessage>{};
      for (final m in ms) {
        last.putIfAbsent(m.groupId, () => m);
      }
      if (mounted) {
        setState(() {
          groups = {for (final g in gs) g.subjectId: g};
          latest = last;
          loading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = friendlyApiError(e);
        });
      }
    }
  }

  String timeText(DateTime t) {
    final l = t.toLocal();
    final now = DateTime.now();
    if (now.difference(l).inHours < 24 && now.day == l.day) {
      return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    }
    return '${l.day}/${l.month}';
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final store = StoreScope.of(context);
    final user = store.currentUser;
    final staff =
        user?.role == UserRole.teacher || user?.role == UserRole.admin;
    final subjects = visibleChatSubjects(learn, staff);
    // Sections, each with its subjects. Starred groups first inside a section.
    final bySection = <String?, List<EpsSubject>>{};
    for (final s in subjects) {
      bySection.putIfAbsent(s.courseId, () => []).add(s);
    }
    int rank(EpsSubject s) {
      final g = groups[s.id];
      final t =
          latest[g?.id ?? '']?.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return (g?.starred ?? false) ? 1 << 30 : t.millisecondsSinceEpoch ~/ 1000;
    }

    return EpsPage(
      title: 'محادثات موادي',
      action: EpsIconButton(
        icon: Icons.refresh_rounded,
        tooltip: 'تحديث',
        onTap: load,
      ),
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Eps.red, fontSize: 10))
        else if (subjects.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'اشترك في مادة من قسمك لتظهر مجموعات قسمك هنا.',
              style: TextStyle(fontSize: 10, color: Eps.muted),
            ),
          )
        else
          for (final entry in bySection.entries) ...[
            HomeSectionTitle(
              entry.key == null
                  ? 'مواد أخرى'
                  : (store.courseById(entry.key!)?.title ?? 'قسم'),
            ),
            for (final s
                in (entry.value..sort((a, b) => rank(b).compareTo(rank(a)))))
              _ChatRow(
                subject: s,
                group: groups[s.id],
                last: latest[groups[s.id]?.id ?? ''],
                timeText: timeText,
                staff: staff,
                locked: !staff && !learn.hasAccess(s.id),
                onStar: () async {
                  final g = groups[s.id];
                  if (g == null) return;
                  await learn.repo.setChatStarred(g.id, !g.starred);
                  await load();
                },
              ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.subject,
    required this.group,
    required this.last,
    required this.timeText,
    required this.staff,
    required this.onStar,
    this.locked = false,
  });

  /// True when the student has not subscribed to the subject: the group is
  /// listed, but it cannot be opened.
  final bool locked;

  final EpsSubject subject;
  final EpsChatGroup? group;
  final EpsChatMessage? last;
  final String Function(DateTime) timeText;
  final bool staff;
  final VoidCallback onStar;

  @override
  Widget build(BuildContext context) {
    final starred = group?.starred ?? false;
    final preview = locked
        ? 'مقفلة. اشترك في المادة لفتحها'
        : last == null
        ? 'لا توجد رسائل بعد'
        : (last!.audioUrl.isNotEmpty
              ? 'رسالة صوتية'
              : (last!.imageUrl.isNotEmpty && last!.body.isEmpty
                    ? 'صورة'
                    : '${last!.senderName}: ${last!.body}'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FlatCard(
        onTap: () {
          if (locked) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('اشترك في هذه المادة لفتح مجموعتها.'),
              ),
            );
            return;
          }
          pushPage(
            context,
            GroupChatScreen(subjectId: subject.id, subjectName: subject.name),
          );
        },
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Eps.blue,
              child: Text(
                subject.name.characters.first,
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
                  Row(
                    children: [
                      if (locked)
                        const Padding(
                          padding: EdgeInsetsDirectional.only(end: 4),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 15,
                            color: Eps.muted,
                          ),
                        ),
                      if (starred)
                        const Padding(
                          padding: EdgeInsetsDirectional.only(end: 4),
                          child: Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFF1B91C),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          subject.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Eps.ink,
                          ),
                        ),
                      ),
                      if (last != null && !locked)
                        Text(
                          timeText(last!.createdAt),
                          style: const TextStyle(fontSize: 9, color: Eps.muted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Eps.muted),
                  ),
                ],
              ),
            ),
            if (staff && group != null)
              IconButton(
                tooltip: starred ? 'إزالة النجمة' : 'تثبيت بنجمة',
                icon: Icon(
                  starred ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFFF1B91C),
                ),
                onPressed: onStar,
              ),
          ],
        ),
      ),
    );
  }
}
