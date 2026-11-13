part of '../main.dart';

(String, EpsTone)? subscriptionBadge(EpsSubscription? sub) =>
    switch (sub?.status) {
      null => null,
      SubscriptionStatus.active => ('نشط', EpsTone.green),
      SubscriptionStatus.pending => ('قيد المراجعة', EpsTone.orange),
      SubscriptionStatus.rejected => ('مرفوض', EpsTone.red),
      SubscriptionStatus.expired => ('منتهي', EpsTone.gray),
    };

/// Catalog of subjects with multi-select (Figma: catalog).
/// First step of subscribing: choose a section, then its subjects.
class SectionsScreen extends StatelessWidget {
  const SectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final store = StoreScope.of(context);
    final ids = <String>[
      for (final s in learn.subjects)
        if (s.courseId != null) s.courseId!,
    ].toSet().toList();
    final sections = [
      for (final id in ids)
        (
          id,
          store.courseById(id)?.title ?? 'قسم',
          store.courseById(id)?.description ?? '',
          learn.subjects.where((s) => s.courseId == id).toList(),
        ),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final other = learn.subjects.where((s) => s.courseId == null).toList();
    return EpsPage(
      title: 'اختر القسم',
      children: [
        const Text(
          'اختر قسمك أولاً، ثم اختر المواد التي تريد الاشتراك فيها.',
          style: TextStyle(fontSize: 9, color: Eps.muted),
        ),
        const SizedBox(height: 14),
        for (final (id, title, description, subjects) in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SectionCard(
              title: title,
              description: description,
              subjects: subjects,
              onTap: () =>
                  pushPage(context, CatalogScreen(courseId: id, title: title)),
            ),
          ),
        if (other.isNotEmpty)
          _SectionCard(
            title: 'مواد أخرى',
            description: '',
            subjects: other,
            onTap: () => pushPage(
              context,
              const CatalogScreen(courseId: '', title: 'مواد أخرى'),
            ),
          ),
        if (sections.isEmpty && other.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EpsLogoLoader(label: 'لا توجد أقسام متاحة حالياً'),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.description,
    required this.subjects,
    required this.onTap,
  });

  final String title;
  final String description;
  final List<EpsSubject> subjects;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final from = subjects.isEmpty
        ? 0
        : subjects.map((s) => s.monthlyPrice).reduce(min);
    return FlatCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF172F77), Eps.blue],
              ),
            ),
            child: const Icon(
              Icons.school_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Eps.ink,
                  ),
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 8, color: Eps.muted),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final s in subjects.take(4))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          s.name,
                          style: const TextStyle(fontSize: 7, color: Eps.ink),
                        ),
                      ),
                    if (subjects.length > 4)
                      Text(
                        '+${subjects.length - 4}',
                        style: const TextStyle(fontSize: 7, color: Eps.muted),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${subjects.length} مواد',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Eps.blue,
                ),
              ),
              if (from > 0)
                Text(
                  'من ${formatMru(from)} MRU',
                  style: const TextStyle(fontSize: 7, color: Eps.muted),
                ),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right_rounded, color: Eps.ink, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({this.courseId, this.title, super.key});

  /// Section to list; `''` means subjects without a section, null means all.
  final String? courseId;
  final String? title;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final search = TextEditingController();
  String? faculty;
  String level = 'الكل';

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    final learn = LearnScope.read(context);
    final profile = widget.courseId == null ? learn.profile : null;
    final faculties = {for (final s in learn.subjects) s.faculty}..remove('');
    if (profile != null && faculties.contains(profile.faculty)) {
      faculty = profile.faculty;
    }
    if (profile != null &&
        learn.subjects.any((s) => s.level == profile.level)) {
      level = profile.level;
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final pool = widget.courseId == null
        ? learn.subjects
        : learn.subjects
              .where((s) => (s.courseId ?? '') == widget.courseId)
              .toList();
    final faculties = widget.courseId == null
        ? ({for (final s in pool) s.faculty}..remove(''))
        : <String>{};
    final levels = {for (final s in pool) s.level}..remove('');
    final q = search.text.trim();
    final items = pool.where((s) {
      if (faculty != null && s.faculty != faculty) {
        return false;
      }
      if (level != 'الكل' && s.level != level) {
        return false;
      }
      if (q.isEmpty) {
        return true;
      }
      final teacher = learn.teacherById(s.teacherId)?.name ?? '';
      return s.name.contains(q) || teacher.contains(q);
    }).toList();
    Widget chip(
      String label,
      bool active,
      VoidCallback onTap, {
      Widget? lead,
    }) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 7),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 31,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Eps.blue : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? Eps.blue : Eps.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?lead,
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : Eps.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
              children: [
                EpsPageHeader(title: widget.title ?? 'استكشف المواد'),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Eps.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF8C94A8),
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: search,
                          style: const TextStyle(fontSize: 11),
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: 'ابحث عن مادة أو أستاذ...',
                            hintStyle: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8C94A8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                SizedBox(
                  height: 31,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (faculties.isNotEmpty)
                        chip(
                          faculty ?? 'كل الكليات',
                          false,
                          () async {
                            final picked = await showModalBottomSheet<String>(
                              context: context,
                              builder: (c) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      title: const Text('كل الكليات'),
                                      onTap: () => Navigator.pop(c, ''),
                                    ),
                                    for (final f in faculties)
                                      ListTile(
                                        title: Text(f),
                                        onTap: () => Navigator.pop(c, f),
                                      ),
                                  ],
                                ),
                              ),
                            );
                            if (picked != null) {
                              setState(
                                () => faculty = picked.isEmpty ? null : picked,
                              );
                            }
                          },
                          lead: const Padding(
                            padding: EdgeInsetsDirectional.only(end: 4),
                            child: Icon(
                              Icons.expand_more_rounded,
                              size: 14,
                              color: Eps.ink,
                            ),
                          ),
                        ),
                      chip(
                        'الكل',
                        level == 'الكل',
                        () => setState(() => level = 'الكل'),
                      ),
                      for (final l in levels)
                        chip(l, level == l, () => setState(() => level = l)),
                    ],
                  ),
                ),
                const SizedBox(height: 17),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'المواد المتاحة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Eps.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${items.length} مواد',
                      style: const TextStyle(fontSize: 9, color: Eps.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final s in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CatalogCard(subject: s),
                  ),
              ],
            ),
            if (learn.cart.isNotEmpty)
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: _SelectionBar(
                  count: learn.cart.length,
                  total: learn.cartMonthlyTotal,
                  onCheckout: () => pushPage(context, const PlansScreen()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.subject});

  final EpsSubject subject;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final selected = learn.cart.contains(subject.id);
    final sub = learn.subscriptionFor(subject.id);
    final badge = subscriptionBadge(sub);
    final teacher = learn.teacherById(subject.teacherId);
    final canSelect =
        sub == null ||
        sub.status == SubscriptionStatus.expired ||
        sub.status == SubscriptionStatus.rejected;
    return GestureDetector(
      onTap: () {
        learn.openSubject(subject.id);
        pushPage(context, SubjectDetailScreen(subjectId: subject.id));
      },
      child: Container(
        height: 117,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: selected ? Eps.blue : Eps.line),
          boxShadow: selected ? Eps.cardShadow : null,
        ),
        child: Row(
          children: [
            Container(
              width: 92,
              decoration: BoxDecoration(
                color: subject.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      subject.icon,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: Eps.fontNum,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Eps.blue,
                      ),
                    ),
                  ),
                  if (subject.level.isNotEmpty)
                    PositionedDirectional(
                      top: 7,
                      start: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xC9FFFFFF),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          subject.level,
                          style: const TextStyle(
                            fontFamily: Eps.fontNum,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Eps.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) EpsBadge(badge.$1, tone: badge.$2),
                  const SizedBox(height: 3),
                  Text(
                    subject.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Eps.ink),
                  ),
                  if (teacher != null)
                    Text(
                      teacher.name,
                      style: const TextStyle(fontSize: 9, color: Eps.muted),
                    ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        '${learn.lessonsFor(subject.id).length} درس',
                        style: const TextStyle(fontSize: 9, color: Eps.muted),
                      ),
                      const Spacer(),
                      Text(
                        '${formatMru(subject.monthlyPrice)} أوقية / شهر',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Eps.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: canSelect ? () => learn.toggleCart(subject.id) : null,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected ? Eps.blue : Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: selected ? Eps.blue : const Color(0xFFCBD2DF),
                    ),
                  ),
                  child: Icon(
                    selected ? Icons.check_rounded : Icons.add_rounded,
                    size: 16,
                    color: selected
                        ? Colors.white
                        : canSelect
                        ? Eps.muted
                        : Eps.line,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.total,
    required this.onCheckout,
  });

  final int count;
  final int total;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xEE172657),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33172657),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count مواد مختارة',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${formatMru(total)} MRU / شهر',
                  style: const TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFCBD6F2),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCheckout,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Text(
                    'متابعة للدفع',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Eps.blue,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: Eps.blue, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subject details (Figma: subject).
class SubjectDetailScreen extends StatefulWidget {
  const SubjectDetailScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final s = learn.subjectById(widget.subjectId);
    if (s == null) {
      return const EpsPage(title: 'تفاصيل المادة', children: []);
    }
    final teacher = learn.teacherById(s.teacherId);
    final lessons = learn.lessonsFor(s.id);
    final subscribed = learn.hasAccess(s.id);
    const tabs = [
      'الدروس',
      'البث المباشر',
      'الملفات',
      'التمارين',
      'الاختبارات',
    ];
    final exercises = [for (final l in lessons) ...learn.exercisesFor(l.id)];
    Widget stat(String v, String l) => Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            v,
            style: const TextStyle(
              fontFamily: Eps.fontNum,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Eps.blue,
            ),
          ),
          Text(l, style: const TextStyle(fontSize: 7, color: Eps.muted)),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 110),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: EpsPageHeader(
                    title: 'تفاصيل المادة',
                    action: EpsIconButton(
                      icon: Icons.share_outlined,
                      tooltip: 'مشاركة',
                      onTap: () => share.SharePlus.instance.share(
                        share.ShareParams(
                          text:
                              'اكتشف مادة ${s.name} على Epsilon Education${teacher == null ? '' : ' مع ${teacher.name}'}',
                        ),
                      ),
                    ),
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 228,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF172F77), Color(0xFF2A5AB5)],
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 22),
                          Container(
                            width: 68,
                            height: 68,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0x18FFFFFF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0x30FFFFFF),
                              ),
                            ),
                            child: Text(
                              s.icon,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontFamily: Eps.fontNum,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (s.level.isNotEmpty || s.faculty.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x20FFFFFF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                [
                                  s.level,
                                  s.faculty,
                                ].where((e) => e.isNotEmpty).join(' • '),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          const SizedBox(height: 7),
                          Text(
                            s.name,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                          if (teacher != null) ...[
                            const SizedBox(height: 6),
                            const Text(
                              'أستاذ المادة',
                              style: TextStyle(
                                fontSize: 7,
                                color: Color(0xFFBCCCF2),
                              ),
                            ),
                            Text(
                              teacher.name,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: -58,
                      child: Container(
                        height: 71,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Eps.line),
                          boxShadow: Eps.cardShadow,
                        ),
                        child: Row(
                          children: [
                            stat('${lessons.length}', 'درساً'),
                            stat(
                              '${teacher?.yearsOfExperience ?? 0}',
                              'سنوات خبرة',
                            ),
                            stat(
                              (teacher?.rating ?? 0).toStringAsFixed(1),
                              'التقييم',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 75, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (s.description.isNotEmpty) ...[
                        const Text(
                          'عن المادة',
                          style: TextStyle(fontSize: 13, color: Eps.ink),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.description,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Eps.muted,
                            height: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (teacher != null) ...[
                        const Text(
                          'أستاذ المادة',
                          style: TextStyle(fontSize: 13, color: Eps.ink),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Eps.line),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 58,
                                  height: 70,
                                  color: const Color(0xFFF1C887),
                                  alignment: Alignment.center,
                                  child: teacher.photoUrl.isEmpty
                                      ? Text(
                                          firstLetter(teacher.name),
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        )
                                      : Image.network(
                                          teacher.photoUrl,
                                          width: 58,
                                          height: 70,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      teacher.name,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Eps.ink,
                                      ),
                                    ),
                                    if (teacher.specialty.isNotEmpty)
                                      Text(
                                        teacher.specialty,
                                        style: const TextStyle(
                                          fontSize: 7,
                                          color: Eps.blue,
                                        ),
                                      ),
                                    if (teacher.bio.isNotEmpty)
                                      Text(
                                        teacher.bio,
                                        style: const TextStyle(
                                          fontSize: 7,
                                          color: Eps.muted,
                                          height: 1.7,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                      ],
                      SizedBox(
                        height: 34,
                        child: Row(
                          children: [
                            for (var i = 0; i < tabs.length; i++) ...[
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => tab = i),
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: i == tab ? Eps.blue : Colors.white,
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: i == tab ? Eps.blue : Eps.line,
                                      ),
                                    ),
                                    child: Text(
                                      tabs[i],
                                      style: TextStyle(
                                        fontSize: 7,
                                        fontWeight: i == tab
                                            ? FontWeight.w800
                                            : FontWeight.w400,
                                        color: i == tab
                                            ? Colors.white
                                            : const Color(0xFF7A8395),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (i < tabs.length - 1) const SizedBox(width: 4),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      ...switch (tab) {
                        0 => [
                          for (final l in lessons)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: LessonRow(lesson: l),
                            ),
                        ],
                        1 => [
                          for (final x in learn.liveFor(s.id))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: LiveSessionRow(session: x),
                            ),
                        ],
                        2 => [
                          for (final p in learn.pdfsFor(s.id))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: PdfRow(pdf: p),
                            ),
                        ],
                        3 => [
                          for (final e in exercises)
                            if (e.isFree || subscribed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: ExerciseCard(exercise: e),
                              ),
                        ],
                        _ => [
                          for (final q in learn.quizzesFor(s.id))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: QuizRow(quiz: q),
                            ),
                        ],
                      },
                      const SizedBox(height: 7),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Eps.blueSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'الاشتراك الشهري',
                                style: TextStyle(fontSize: 9, color: Eps.blue),
                              ),
                            ),
                            Text(
                              formatMru(s.monthlyPrice),
                              style: const TextStyle(
                                fontFamily: Eps.fontNum,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Eps.blue,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'أوقية / شهر',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                                color: Eps.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 23, 18, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.25],
                    colors: [Color(0x00F7F8FC), Eps.bg],
                  ),
                ),
                child: EpsPrimaryButton(
                  label: subscribed ? 'افتح المادة' : 'متابعة للدفع',
                  icon: Icons.chevron_right_rounded,
                  onPressed: () {
                    if (subscribed) {
                      pushPage(context, CourseScreen(subjectId: s.id));
                      return;
                    }
                    if (!learn.cart.contains(s.id)) {
                      learn.toggleCart(s.id);
                    }
                    pushPage(context, const PlansScreen());
                  },
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 70,
              child: AssistantFab(subjectName: s.name),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plan picker (Figma: plans).
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final monthly = learn.cartMonthlyTotal;
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
              children: [
                const EpsPageHeader(title: 'اختيار الخطة'),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Eps.blue,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: Eps.buttonShadow,
                      ),
                      child: const Text(
                        '1',
                        style: TextStyle(
                          fontFamily: Eps.fontNum,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اختر الخطة المناسبة لك',
                            style: TextStyle(fontSize: 16, color: Eps.ink),
                          ),
                          Text(
                            'يمكنك البدء مجاناً أو فتح جميع المزايا بخطة مدفوعة.',
                            style: TextStyle(fontSize: 8, color: Eps.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final plan in learn.plans)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PlanCard(
                      plan: plan,
                      price: plan.priceFor(monthly),
                      selected: learn.selectedPlanCode == plan.code,
                      onTap: () => learn.selectPlan(plan.code),
                    ),
                  ),
              ],
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 8,
              child: EpsPrimaryButton(
                label: learn.planByCode(learn.selectedPlanCode)?.isFree ?? false
                    ? 'ابدأ مجاناً'
                    : 'اشترك الآن',
                icon: Icons.chevron_right_rounded,
                onPressed:
                    learn.cart.isEmpty &&
                        !(learn.planByCode(learn.selectedPlanCode)?.isFree ??
                            false)
                    ? null
                    : () {
                        if (learn.planByCode(learn.selectedPlanCode)?.isFree ??
                            false) {
                          pushPage(context, const FreePlanScreen());
                          return;
                        }
                        pushPage(context, const CheckoutScreen());
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final EpsPlan plan;
  final int price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: selected ? Eps.blue : Eps.line),
          boxShadow: selected ? Eps.cardShadow : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (plan.badge.isNotEmpty)
                        EpsBadge(
                          plan.badge,
                          tone: plan.isFree ? EpsTone.green : EpsTone.blue,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        plan.title,
                        style: const TextStyle(fontSize: 13, color: Eps.ink),
                      ),
                      Text(
                        plan.subtitle,
                        style: const TextStyle(fontSize: 7, color: Eps.muted),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    plan.isFree ? 'مجاناً' : '${formatMru(price)} MRU',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: plan.isFree ? Eps.green : Eps.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Eps.blue : Colors.transparent,
                    border: Border.all(
                      color: selected ? Eps.blue : const Color(0xFFCCD3DF),
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFDCE1EA))),
              ),
              child: Wrap(
                runSpacing: 6,
                children: [
                  for (final f in plan.features)
                    FractionallySizedBox(
                      widthFactor: 0.5,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            size: 11,
                            color: Eps.green,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              f,
                              style: const TextStyle(
                                fontSize: 7,
                                color: Color(0xFF667084),
                              ),
                            ),
                          ),
                        ],
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

const _payColors = [Color(0xFF203D89), Color(0xFF14855F), Color(0xFFE69315)];

/// Payment method selection (Figma: checkout).
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? methodId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final learn = LearnScope.of(context);
    final plan = learn.planByCode(learn.selectedPlanCode);
    final methods = store.paymentMethods;
    methodId ??= methods.firstOrNull?.id;
    final method = methods.where((m) => m.id == methodId).firstOrNull;
    final total =
        plan?.priceFor(learn.cartMonthlyTotal) ?? learn.cartMonthlyTotal;
    return EpsPage(
      title: 'إتمام الدفع',
      bottom: EpsPrimaryButton(
        label: 'تم التحويل، رفع الوصل',
        icon: Icons.upload_rounded,
        onPressed: method == null
            ? null
            : () => pushPage(
                context,
                ReceiptUploadScreen(paymentMethodId: method.id),
              ),
      ),
      children: [
        Container(
          height: 101,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: const LinearGradient(
              begin: Alignment(-1, -0.58),
              end: Alignment(1, 0.58),
              colors: [Color(0xFF244AB1), Eps.blue],
            ),
            boxShadow: Eps.buttonShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'المواد المختارة',
                      style: TextStyle(fontSize: 7, color: Color(0xFFD7E1FF)),
                    ),
                    Text(
                      '${learn.cart.length} مادة',
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan == null
                          ? ''
                          : plan.months <= 1
                          ? 'اشتراك شهري قابل للتجديد'
                          : 'اشتراك ${plan.months} أشهر',
                      style: const TextStyle(
                        fontSize: 7,
                        color: Color(0xFFD7E1FF),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatMru(total),
                style: const TextStyle(
                  fontFamily: Eps.fontNum,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'MRU',
                style: TextStyle(
                  fontFamily: Eps.fontNum,
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD7E1FF),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        for (final s in learn.cartSubjects)
          Container(
            height: 50,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Eps.line),
            ),
            child: Row(
              children: [
                SubjectMark(subject: s, size: 34, radius: 9, fontSize: 12),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Eps.ink,
                        ),
                      ),
                      Text(
                        learn.teacherById(s.teacherId)?.name ?? '',
                        style: const TextStyle(fontSize: 6, color: Eps.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${formatMru(plan?.priceFor(s.monthlyPrice) ?? s.monthlyPrice)} MRU',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Eps.blue,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'اختر طريقة الدفع',
          style: TextStyle(fontSize: 13, color: Eps.ink),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < methods.length && i < 3; i++) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => methodId = methods[i].id),
                  child: Container(
                    height: 104,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: methods[i].id == methodId ? Eps.blue2 : Eps.line,
                      ),
                      boxShadow: methods[i].id == methodId
                          ? Eps.cardShadow
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 35,
                              height: 35,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: _payColors[i % 3],
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: methods[i].imageUrl.startsWith('http')
                                  ? Image.network(
                                      methods[i].imageUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                            ),
                            const Spacer(),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: methods[i].id == methodId
                                    ? Eps.blue
                                    : Colors.transparent,
                                border: Border.all(
                                  color: methods[i].id == methodId
                                      ? Eps.blue
                                      : const Color(0xFFC9D0DC),
                                ),
                              ),
                              child: methods[i].id == methodId
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          methods[i].name,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Eps.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (i < min(methods.length, 3) - 1) const SizedBox(width: 7),
            ],
          ],
        ),
        if (methods.isEmpty)
          const Text(
            'لا توجد طرق دفع مفعّلة حالياً. تواصل مع الإدارة.',
            style: TextStyle(fontSize: 9, color: Eps.red),
          ),
        if (method != null) ...[
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD8F5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'حوّل المبلغ إلى الرقم التالي',
                  style: TextStyle(fontSize: 8, color: Color(0xFF65728B)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        method.accountNumber,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: Eps.fontNum,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Eps.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: method.accountNumber),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ الرقم')),
                        );
                      },
                      child: Container(
                        height: 31,
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        decoration: BoxDecoration(
                          color: Eps.blue,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'نسخ',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'اسم الحساب: Epsilon Education',
                  style: TextStyle(fontSize: 7, color: Eps.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          FlatCard(
            shadow: false,
            radius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'خطوات الدفع',
                  style: TextStyle(fontSize: 10, color: Eps.ink),
                ),
                for (final (i, step) in [
                  'افتح تطبيق الدفع',
                  'حوّل المبلغ إلى الرقم أعلاه',
                  'صوّر الوصل وارفعه',
                ].indexed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Eps.blue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontFamily: Eps.fontNum,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          step,
                          style: const TextStyle(fontSize: 8, color: Eps.ink),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Receipt upload (Figma: receipt).
class ReceiptUploadScreen extends StatefulWidget {
  const ReceiptUploadScreen({this.paymentMethodId, super.key});

  final String? paymentMethodId;

  @override
  State<ReceiptUploadScreen> createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> {
  final refController = TextEditingController();
  PickedNativeFile? file;
  bool sending = false;
  String? error;

  @override
  void dispose() {
    refController.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    final picked = await NativeFilePicker.pickImage();
    if (picked != null && mounted) {
      setState(() => file = picked);
    }
  }

  Future<void> submit() async {
    final learn = LearnScope.read(context);
    final fallbackMethod = StoreScope.of(
      context,
    ).paymentMethods.firstOrNull?.id;
    final picked = file;
    if (picked == null) {
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final dataUri = await paymentProofDataUri(picked.path, picked.name);
      await learn.submitPayment(
        paymentMethodId: widget.paymentMethodId ?? fallbackMethod,
        receiptUrl: dataUri,
        transactionRef: refController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PaymentConfirmationScreen()),
          (route) => route.isFirst,
        );
      }
    } on Object catch (e) {
      setState(() => error = 'تعذر إرسال الوصل: $e');
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget smallBtn(IconData icon, String label) => Expanded(
      child: GestureDetector(
        onTap: pick,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Eps.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Eps.ink),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 8, color: Eps.ink)),
            ],
          ),
        ),
      ),
    );
    return EpsPage(
      title: 'رفع وصل الدفع',
      bottom: EpsPrimaryButton(
        label: 'إرسال الوصل',
        icon: Icons.send_rounded,
        loading: sending,
        onPressed: file == null ? null : submit,
      ),
      children: [
        const SizedBox(height: 10),
        const Center(
          child: Icon(Icons.cloud_upload_outlined, color: Eps.blue, size: 34),
        ),
        const SizedBox(height: 8),
        const Text(
          'ارفع صورة الوصل',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Eps.ink),
        ),
        const Text(
          'تأكد من وضوح المبلغ ورقم العملية قبل الإرسال.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 8, color: Eps.muted),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: pick,
          child: CustomPaint(
            foregroundPainter: const DashedRRectPainter(
              color: Color(0xFFB4C4EA),
              radius: 16,
            ),
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F9FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: file == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          color: Eps.blue,
                          size: 26,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'اضغط لرفع صورة الوصل',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Eps.blue,
                          ),
                        ),
                        Text(
                          'PNG, JPG أو PDF • حتى 5MB',
                          style: TextStyle(fontSize: 7, color: Eps.muted),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(file!.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            smallBtn(Icons.photo_camera_outlined, 'التقاط صورة'),
            const SizedBox(width: 8),
            smallBtn(Icons.add_photo_alternate_outlined, 'اختيار من المعرض'),
          ],
        ),
        const SizedBox(height: 14),
        const Text.rich(
          TextSpan(
            text: 'رقم العملية ',
            children: [
              TextSpan(
                text: '(اختياري)',
                style: TextStyle(fontWeight: FontWeight.w400, color: Eps.muted),
              ),
            ],
          ),
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        AuthField(
          controller: refController,
          hint: 'مثال: 86629103',
          keyboardType: TextInputType.number,
          height: 44,
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 12, color: Eps.muted),
            SizedBox(width: 4),
            Text(
              'بياناتك المالية مشفرة وآمنة',
              style: TextStyle(fontSize: 7, color: Eps.muted),
            ),
          ],
        ),
        if (error != null) AuthErrorText(error!),
      ],
    );
  }
}

/// Confirmation after sending the receipt (Figma: confirmation).
class PaymentConfirmationScreen extends StatelessWidget {
  const PaymentConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final ref = learn.lastRequest.firstOrNull?.ref ?? '';
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 120, 22, 32),
          children: [
            Center(
              child: Container(
                width: 128,
                height: 128,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE9F7F0),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const EpsLogo(size: 92),
                    Positioned(
                      left: 6,
                      bottom: 10,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Eps.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Center(child: EpsBadge('قيد المراجعة', tone: EpsTone.orange)),
            const SizedBox(height: 10),
            const Text(
              'تم استلام وصلك بنجاح',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, color: Eps.ink),
            ),
            const Text(
              'سيتم التحقق وتفعيل اشتراكك خلال 24 ساعة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, color: Eps.muted),
            ),
            const SizedBox(height: 20),
            FlatCard(
              shadow: false,
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Column(
                children: [
                  const Text(
                    'رقم الطلب',
                    style: TextStyle(fontSize: 7, color: Eps.muted),
                  ),
                  Text(
                    '#$ref',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: Eps.fontNum,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Eps.ink,
                    ),
                  ),
                  const Text(
                    'سنرسل إليك إشعاراً فور تحديث الحالة',
                    style: TextStyle(fontSize: 7, color: Eps.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            EpsPrimaryButton(
              label: 'العودة للرئيسية',
              onPressed: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
                StudentShellState.of(context)?.goTab(0);
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                textStyle: const TextStyle(
                  fontFamily: Eps.font,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const PaymentsStatusPage()),
              ),
              child: const Text('تتبع حالة الطلب'),
            ),
          ],
        ),
      ),
    );
  }
}
