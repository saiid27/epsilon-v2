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
              'poll_question': m.pollQuestion,
              'poll_options': m.pollOptions,
              'created_at': m.createdAt.toUtc().toIso8601String(),
            },
        ]),
      );
    } on Object {
      // The cache is a convenience: a failed save never breaks the chat.
    }
  }
}

/// The groups a user sees: an admin sees all of them, a teacher the groups of
/// the subjects he teaches, and a student the groups of the sections he is in.
/// The groups he has not paid for are listed, but locked.
List<EpsChatGroup> visibleChatGroups(
  LearnStore learn,
  UserRole? role,
  String? userId,
) {
  if (role == UserRole.admin) return [...learn.chatGroups];
  if (role == UserRole.teacher) {
    return [
      for (final g in learn.chatGroups)
        if (learn.subjectById(g.subjectId)?.teacherId == userId) g,
    ];
  }
  // A section counts for a student who has a subscription in it.
  final sections = <String?>{
    for (final g in learn.chatGroups)
      if (learn.canOpenGroup(g)) learn.courseOf(g.subjectId),
    for (final s in learn.subjects)
      if (learn.hasAccess(s.id)) s.courseId,
  };
  return [
    for (final g in learn.chatGroups)
      if (sections.contains(learn.courseOf(g.subjectId))) g,
  ];
}

/// The groups of the user, by section. Starred groups first inside a section.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool loading = true;
  String error = '';
  List<EpsChatGroup> groups = [];
  Map<String, EpsChatMessage> latest = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  bool get _staff {
    final role = StoreScope.of(context).currentUser?.role;
    return role == UserRole.teacher || role == UserRole.admin;
  }

  Future<void> load() async {
    final learn = LearnScope.read(context);
    final user = StoreScope.of(context).currentUser;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      // The groups and the subscriptions, as they are now.
      final uid = learn.userId;
      if (uid != null) await learn.load(uid);
      final visible = visibleChatGroups(learn, user?.role, user?.id);
      final openIds = [
        for (final g in visible)
          if (_staff || learn.canOpenGroup(g)) g.id,
      ];
      // Previews only for the groups this user can open.
      final ms = await learn.repo.latestChatMessages(openIds);
      final last = <String, EpsChatMessage>{};
      for (final m in ms) {
        last.putIfAbsent(m.groupId, () => m);
      }
      if (mounted) {
        setState(() {
          groups = visible;
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

  /// The admin or the teacher adds a group to one of the subjects they teach.
  /// Only the admin sets the price.
  Future<void> newGroup() async {
    final learn = LearnScope.read(context);
    final user = StoreScope.of(context).currentUser;
    final isAdmin = user?.role == UserRole.admin;
    final mine = [
      for (final s in learn.subjects)
        if (isAdmin || s.teacherId == user?.id) s,
    ];
    if (mine.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مواد لإضافة مجموعة إليها.')),
      );
      return;
    }
    var subjectId = mine.first.id;
    final name = TextEditingController();
    final price = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('مجموعة جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_staff && groups.any(learn.canOpenGroup))
                const FeatureArt(
                  'assets/art/success_celebrate.png',
                  height: 110,
                ),
              DropdownButtonFormField<String>(
                initialValue: subjectId,
                decoration: const InputDecoration(labelText: 'المادة'),
                items: [
                  for (final s in mine)
                    DropdownMenuItem(value: s.id, child: Text(s.displayName)),
                ],
                onChanged: (v) => set(() => subjectId = v ?? subjectId),
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'اسم المجموعة'),
              ),
              if (isAdmin)
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'سعر الاشتراك (MRU / شهر)',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await learn.repo.createChatGroup(
        subjectId: subjectId,
        name: name.text,
        price: isAdmin ? int.tryParse(price.text.trim()) ?? 0 : 0,
        createdBy: user?.id,
      );
      await load();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyApiError(e))));
      }
    }
  }

  /// The admin or the teacher gives the group its name.
  Future<void> rename(EpsChatGroup g) async {
    final learn = LearnScope.read(context);
    final ctl = TextEditingController(text: g.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('اسم المجموعة'),
        content: TextField(controller: ctl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok != true || ctl.text.trim().isEmpty) return;
    await learn.repo.updateChatGroup(g.id, name: ctl.text);
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final store = StoreScope.of(context);
    final staff = _staff;
    // Sections, each with its groups. Starred groups first inside a section.
    final bySection = <String?, List<EpsChatGroup>>{};
    for (final g in groups) {
      bySection.putIfAbsent(learn.courseOf(g.subjectId), () => []).add(g);
    }
    int rank(EpsChatGroup g) {
      final t =
          latest[g.id]?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return g.starred ? 1 << 30 : t.millisecondsSinceEpoch ~/ 1000;
    }

    final isAdmin = StoreScope.of(context).currentUser?.role == UserRole.admin;
    return EpsPage(
      title: isAdmin ? 'نظرة عامة على المجموعات' : 'المجموعات',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (staff)
            EpsIconButton(
              icon: Icons.add_rounded,
              tooltip: 'مجموعة جديدة',
              onTap: newGroup,
            ),
          EpsIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'تحديث',
            onTap: load,
          ),
        ],
      ),
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Eps.red, fontSize: 10))
        else if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'لا توجد مجموعات بعد.',
              style: TextStyle(fontSize: 10, color: Eps.muted),
            ),
          )
        else
          for (final entry in bySection.entries) ...[
            HomeSectionTitle(
              entry.key == null
                  ? 'مواد أخرى'
                  : (learn.sectionById(entry.key!)?.title ??
                        store.courseById(entry.key!)?.title ??
                        'قسم'),
            ),
            for (final g
                in (entry.value..sort((a, b) => rank(b).compareTo(rank(a)))))
              _ChatGroupRow(
                group: g,
                subject: learn.subjectById(g.subjectId),
                last: latest[g.id],
                timeText: timeText,
                staff: staff,
                locked: !staff && !learn.canOpenGroup(g),
                onOpen: () {
                  if (!staff && !learn.canOpenGroup(g)) {
                    pushPage(context, GroupCheckoutScreen(group: g));
                    return;
                  }
                  pushPage(
                    context,
                    GroupChatScreen(
                      group: g,
                      subjectName:
                          learn.subjectById(g.subjectId)?.displayName ?? '',
                    ),
                  );
                },
                onRename: () => rename(g),
                onStar: () async {
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

class _ChatGroupRow extends StatelessWidget {
  const _ChatGroupRow({
    required this.group,
    required this.subject,
    required this.last,
    required this.timeText,
    required this.staff,
    required this.locked,
    required this.onOpen,
    required this.onRename,
    required this.onStar,
  });

  final EpsChatGroup group;
  final EpsSubject? subject;
  final EpsChatMessage? last;
  final String Function(DateTime) timeText;
  final bool staff;
  // True when the student has not paid for this group: it is listed, locked.
  final bool locked;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onStar;

  @override
  Widget build(BuildContext context) {
    final name = group.name.isNotEmpty
        ? group.name
        : (subject?.displayName ?? 'مجموعة');
    final preview = locked
        ? (group.price > 0
              ? 'مقفلة · ${formatMru(group.price)} MRU / شهر'
              : 'غير متاحة للاشتراك بعد')
        : last == null
        ? 'لا توجد رسائل بعد'
        : (last!.audioUrl.isNotEmpty
              ? 'رسالة صوتية'
              : (last!.imageUrl.isNotEmpty && last!.body.isEmpty
                    ? 'صورة'
                    : '${last!.senderName}: ${last!.body}'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onLongPress: staff ? onRename : null,
        child: FlatCard(
          onTap: onOpen,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Eps.blue,
                child: Text(
                  name.characters.first,
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
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: Eps.muted,
                            ),
                          ),
                        if (group.starred)
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
                            name,
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
                            style: const TextStyle(
                              fontSize: 9,
                              color: Eps.muted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subject?.displayName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: Eps.blue),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Eps.muted),
                    ),
                  ],
                ),
              ),
              if (staff)
                IconButton(
                  tooltip: group.starred ? 'إلغاء التمييز' : 'تمييز',
                  onPressed: onStar,
                  icon: Icon(
                    group.starred
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Eps.muted,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
