part of '../main.dart';

String currentSemesterLabel() {
  final now = DateTime.now();
  final second = now.month >= 2 && now.month <= 7;
  return '${second ? 'الفصل الثاني' : 'الفصل الأول'} • ${now.year}';
}

/// Title block used by the tab roots (`.title-action`).
class TabTitle extends StatelessWidget {
  const TabTitle({
    required this.small,
    required this.title,
    this.action,
    super.key,
  });

  final String small;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  small,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Eps.muted,
                    height: 1.5,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Eps.ink,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// "موادي" tab (Figma: subjects).
class MySubjectsTab extends StatelessWidget {
  const MySubjectsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final active = learn.activeSubjects;
    void openCatalog() => pushPage(context, const CatalogScreen());
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: learn.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
          children: [
            TabTitle(
              small: 'مكتبتك الدراسية',
              title: 'موادي',
              action: EpsIconButton(
                icon: Icons.search_rounded,
                tooltip: 'بحث',
                iconSize: 21,
                onTap: openCatalog,
              ),
            ),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Eps.blue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.school_outlined,
                    color: Colors.white,
                    size: 21,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الفصل الحالي',
                          style: TextStyle(
                            fontSize: 7,
                            color: Color(0xFFC9D6F5),
                            height: 1.5,
                          ),
                        ),
                        Text(
                          currentSemesterLabel(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1FFFFFFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${active.length} مواد نشطة',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: openCatalog,
              child: Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment(-1, -0.36),
                    end: Alignment(1, 0.36),
                    colors: [Eps.blue, Color(0xFF5079DC)],
                  ),
                  boxShadow: Eps.buttonShadow,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'أضف مادة جديدة',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.5,
                            ),
                          ),
                          Text(
                            'اختر مادة أو أكثر واشترك مباشرة',
                            style: TextStyle(
                              fontSize: 7,
                              color: Color(0xFFDCE5FF),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
            for (final sub in learn.withStatus(SubscriptionStatus.pending))
              SubscriptionStateRow(subscription: sub),
            for (final sub in learn.withStatus(SubscriptionStatus.rejected))
              SubscriptionStateRow(subscription: sub),
            const SizedBox(height: 8),
            if (active.isEmpty)
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: CustomPaint(
                  foregroundPainter: const DashedRRectPainter(
                    color: Color(0xFFB8C4DF),
                    radius: 16,
                  ),
                  child: const Center(
                    child: EpsLogoLoader(label: 'لا توجد مواد نشطة بعد'),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (final subject in active)
                  _ActiveSubjectTile(subject: subject),
                GestureDetector(
                  onTap: openCatalog,
                  child: CustomPaint(
                    foregroundPainter: const DashedRRectPainter(
                      color: Color(0xFFAEB8D2),
                      radius: 16,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F5FC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 35,
                            height: 35,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '+',
                              style: TextStyle(
                                fontSize: 21,
                                color: Eps.blue,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'استكشف مواد جديدة',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Eps.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pending / rejected subscription row (`.subscription-state`).
class SubscriptionStateRow extends StatelessWidget {
  const SubscriptionStateRow({required this.subscription, super.key});

  final EpsSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final pending = subscription.status == SubscriptionStatus.pending;
    final accent = pending ? const Color(0xFFA96C00) : Eps.red;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        height: 69,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: pending ? const Color(0xFFFFF9E9) : const Color(0xFFFFF4F5),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: pending ? const Color(0xFFF0D18F) : const Color(0xFFEFC0C5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              pending ? Icons.schedule_rounded : Icons.close_rounded,
              color: pending ? const Color(0xFFB96D00) : Eps.red,
              size: 24,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EpsBadge(
                    pending ? 'قيد المراجعة' : 'مرفوض',
                    tone: pending ? EpsTone.orange : EpsTone.red,
                  ),
                  Text(
                    learn.subjectById(subscription.subjectId)?.name ?? '',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    pending
                        ? 'سيتم التفعيل بعد موافقة الإدارة'
                        : (subscription.rejectionReason.isEmpty
                              ? 'الوصل غير واضح'
                              : subscription.rejectionReason),
                    style: TextStyle(fontSize: 7, color: accent, height: 1.5),
                  ),
                ],
              ),
            ),
            if (!pending)
              GestureDetector(
                onTap: () {
                  learn.cart
                    ..clear()
                    ..add(subscription.subjectId);
                  learn.selectPlan(subscription.planCode);
                  pushPage(context, const ReceiptUploadScreen());
                },
                child: Container(
                  height: 21,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Eps.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'إعادة رفع الوصل',
                    style: TextStyle(fontSize: 6, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveSubjectTile extends StatelessWidget {
  const _ActiveSubjectTile({required this.subject});

  final EpsSubject subject;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final progress = learn.progressFor(subject.id);
    final teacher = learn.teacherById(subject.teacherId);
    return FlatCard(
      radius: 16,
      onTap: () {
        learn.openSubject(subject.id);
        pushPage(context, CourseScreen(subjectId: subject.id));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SubjectMark(subject: subject, size: 44),
          const Spacer(),
          Text(
            subject.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Eps.ink,
            ),
          ),
          Text(
            teacher?.name ?? '${learn.lessonsFor(subject.id).length} درس',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 8, color: Eps.muted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: EpsProgress(value: progress / 100, height: 5)),
              const SizedBox(width: 6),
              Text(
                '$progress%',
                style: const TextStyle(
                  fontFamily: Eps.fontNum,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Eps.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Segmented tabs (`.tabs`).
class EpsSegmented extends StatelessWidget {
  const EpsSegmented({
    required this.labels,
    required this.index,
    required this.onChanged,
    super.key,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF5),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: i == index
                        ? const [
                            BoxShadow(
                              color: Color(0x14182850),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: i == index
                          ? FontWeight.w800
                          : FontWeight.w400,
                      color: i == index ? Eps.blue : Eps.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Subject page for subscribed students (Figma: course).
class CourseScreen extends StatefulWidget {
  const CourseScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final subject = learn.subjectById(widget.subjectId);
    if (subject == null) {
      return const EpsPage(title: 'المادة', children: []);
    }
    final lessons = learn.lessonsFor(subject.id);
    final progress = learn.progressFor(subject.id);
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
              children: [
                EpsPageHeader(
                  title: subject.name,
                  action: EpsIconButton(
                    icon: Icons.notifications_none_rounded,
                    iconSize: 21,
                    tooltip: 'الإشعارات',
                    onTap: () =>
                        pushPage(context, const StudentNotificationsPage()),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    gradient: const LinearGradient(
                      begin: Alignment(-1, -0.58),
                      end: Alignment(1, 0.58),
                      colors: [Eps.blue, Color(0xFF3564C3)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'تقدمك في المادة',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            '$progress%',
                            style: const TextStyle(
                              fontFamily: Eps.fontNum,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      EpsProgress(
                        value: progress / 100,
                        height: 5,
                        color: Eps.orange,
                        track: const Color(0x30FFFFFF),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${lessons.length} درساً في المادة',
                        style: const TextStyle(
                          fontSize: 8,
                          color: Color(0xFFD6E0F7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AskLessonCard(subjectName: subject.name),
                const SizedBox(height: 15),
                EpsSegmented(
                  labels: const ['الدروس', 'المباشر', 'الاختبارات', 'المصادر'],
                  index: tab,
                  onChanged: (i) => setState(() => tab = i),
                ),
                const SizedBox(height: 14),
                ...switch (tab) {
                  0 => _lessonsTab(context, learn, lessons),
                  1 => [
                    for (final s in learn.liveFor(subject.id))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: LiveSessionRow(session: s),
                      ),
                    if (learn.liveFor(subject.id).isEmpty)
                      const _EmptyNote('لا توجد جلسات مباشرة لهذه المادة بعد'),
                  ],
                  2 => [
                    for (final q in learn.quizzesFor(subject.id))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: QuizRow(quiz: q),
                      ),
                    if (learn.quizzesFor(subject.id).isEmpty)
                      const _EmptyNote('لا توجد اختبارات لهذه المادة بعد'),
                  ],
                  _ => [
                    for (final pdf in learn.pdfsFor(subject.id))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PdfRow(pdf: pdf),
                      ),
                    if (learn.pdfsFor(subject.id).isEmpty)
                      const _EmptyNote('لا توجد ملفات لهذه المادة بعد'),
                  ],
                },
              ],
            ),
            Positioned(
              left: 14,
              bottom: 11,
              child: AssistantFab(subjectName: subject.name),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _lessonsTab(
    BuildContext context,
    LearnStore learn,
    List<EpsLesson> lessons,
  ) {
    if (lessons.isEmpty) {
      return const [_EmptyNote('لم تُنشر دروس لهذه المادة بعد')];
    }
    final units = <String, List<EpsLesson>>{};
    for (final l in lessons) {
      units.putIfAbsent(l.unit.isEmpty ? 'الدروس' : l.unit, () => []).add(l);
    }
    final out = <Widget>[];
    var n = 0;
    for (final entry in units.entries) {
      n++;
      final done = entry.value
          .where((l) => learn.completedLessonIds.contains(l.id))
          .length;
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Eps.blueSoft,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'الوحدة $n',
                  style: const TextStyle(fontSize: 7, color: Eps.blue),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Eps.ink,
                  ),
                ),
              ),
              Text(
                '$done من ${entry.value.length} مكتملة',
                style: const TextStyle(fontSize: 7, color: Eps.muted),
              ),
            ],
          ),
        ),
      );
      for (final lesson in entry.value) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: LessonRow(lesson: lesson),
          ),
        );
      }
    }
    return out;
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 9, color: Eps.muted),
      ),
    );
  }
}

/// "اسأل عن هذا الدرس" card (`.lesson-ai-cta`).
class AskLessonCard extends StatelessWidget {
  const AskLessonCard({this.lessonTitle, this.subjectName, super.key});

  final String? lessonTitle;
  final String? subjectName;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => pushPage(
        context,
        AssistantScreen(lessonTitle: lessonTitle, subjectName: subjectName),
      ),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD8FA)),
          gradient: const LinearGradient(
            begin: Alignment(-1, -0.18),
            end: Alignment(1, 0.18),
            colors: [Color(0xFFEEF3FF), Color(0xFFFAFCFF)],
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: Eps.blue, size: 19),
            SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اسأل عن هذا الدرس',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Eps.blue,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    'مساعد إبسيلون متصل الآن',
                    style: TextStyle(
                      fontSize: 7,
                      color: Color(0xFF7181A5),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Eps.blue, size: 17),
          ],
        ),
      ),
    );
  }
}

/// Lesson row with status icon (`.lesson-row`).
class LessonRow extends StatelessWidget {
  const LessonRow({required this.lesson, super.key});

  final EpsLesson lesson;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final done = learn.completedLessonIds.contains(lesson.id);
    final open = learn.canOpenLesson(lesson);
    final meta = [
      if (lesson.url.isNotEmpty) 'فيديو' else 'درس',
      if (lesson.duration.isNotEmpty) lesson.duration,
      if (lesson.isFree) 'مجاني',
    ].join(' • ');
    return GestureDetector(
      onTap: () => open
          ? pushPage(context, LessonScreen(lessonId: lesson.id))
          : showLockedSheet(context, lesson.subjectId),
      child: Container(
        height: 53,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Eps.line),
        ),
        child: Row(
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: done || !open ? const Color(0xFFE5F8EF) : Eps.blueSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                done
                    ? Icons.check_rounded
                    : open
                    ? Icons.play_arrow_rounded
                    : Icons.lock_outline_rounded,
                size: 16,
                color: done || !open ? Eps.green : Eps.blue,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Eps.ink,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 7,
                      color: Eps.muted,
                      height: 1.5,
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

/// PDF resource row.
class PdfRow extends StatelessWidget {
  const PdfRow({required this.pdf, super.key});

  final EpsPdf pdf;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final open = pdf.isFree || learn.hasAccess(pdf.subjectId);
    return GestureDetector(
      onTap: () => open
          ? pushPage(context, PdfViewerScreen(pdf: pdf))
          : showLockedSheet(context, pdf.subjectId),
      child: Container(
        height: 53,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Eps.line),
        ),
        child: Row(
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: Eps.redSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                open ? Icons.description_outlined : Icons.lock_outline_rounded,
                size: 16,
                color: Eps.red,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pdf.title,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Eps.ink,
                    ),
                  ),
                  Text(
                    [
                      'PDF',
                      if (pdf.pageCount > 0) '${pdf.pageCount} صفحة',
                      if (pdf.sizeText.isNotEmpty) pdf.sizeText,
                      if (pdf.isFree) 'مجاني',
                    ].join(' • '),
                    style: const TextStyle(fontSize: 7, color: Eps.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.download_outlined, size: 17, color: Eps.muted),
          ],
        ),
      ),
    );
  }
}
