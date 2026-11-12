part of '../main.dart';

/// Upsell strip at the bottom of free content (`.free-upsell`).
class FreeUpsell extends StatelessWidget {
  const FreeUpsell({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => pushPage(context, const CatalogScreen()),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xEBF7FAFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD4DDF3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F1E3A8A),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Eps.blue, size: 18),
            SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'للوصول إلى كل محتوى المادة اشترك الآن',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Eps.blue,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    'اختر المادة المناسبة لك من القائمة',
                    style: TextStyle(
                      fontSize: 7,
                      color: Eps.muted,
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

/// Lesson page (Figma: freeLesson).
class LessonScreen extends StatefulWidget {
  const LessonScreen({required this.lessonId, super.key});

  final String lessonId;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  void play(EpsLesson lesson) {
    final learn = LearnScope.read(context);
    if (!learn.completedLessonIds.contains(lesson.id) && learn.userId != null) {
      learn.toggleLessonDone(lesson);
    }
    pushPage(
      context,
      SecureContentViewerPage(
        title: lesson.title,
        url: lesson.url,
        kind: SecureContentKind.video,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final lesson = learn.lessons
        .where((l) => l.id == widget.lessonId)
        .firstOrNull;
    if (lesson == null) {
      return const EpsPage(title: 'الدرس', children: []);
    }
    final subject = learn.subjectById(lesson.subjectId);
    final subscribed = learn.hasAccess(lesson.subjectId);
    const body = TextStyle(fontSize: 9, color: Eps.muted, height: 2);
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
              children: [
                EpsPageHeader(
                  title: lesson.isFree && !subscribed
                      ? 'شرح مجاني'
                      : subject?.name ?? 'الدرس',
                  action: lesson.isFree
                      ? const Center(
                          child: EpsBadge('مجاني', tone: EpsTone.green),
                        )
                      : null,
                ),
                GestureDetector(
                  onTap: lesson.url.isEmpty ? null : () => play(lesson),
                  child: Container(
                    height: 205,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2649AA), Eps.blue],
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        for (final d in [190.0, 120.0])
                          Container(
                            width: d,
                            height: d,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0x22FFFFFF),
                              ),
                              color: const Color(0x0DFFFFFF),
                            ),
                          ),
                        Text(
                          subject?.icon ?? 'lim',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontStyle: FontStyle.italic,
                            fontSize: 56,
                            color: Colors.white,
                          ),
                        ),
                        const Positioned(
                          left: 33,
                          top: 26,
                          child: Text(
                            'ƒ(x)',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontStyle: FontStyle.italic,
                              fontSize: 20,
                              color: Color(0xFFF4C737),
                            ),
                          ),
                        ),
                        if (lesson.url.isNotEmpty)
                          Positioned(
                            right: 22,
                            bottom: 20,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Eps.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: EpsBadge(
                    [
                      ?subject?.name,
                      if (lesson.duration.isNotEmpty) lesson.duration,
                    ].join(' • '),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  lesson.title,
                  style: const TextStyle(fontSize: 19, color: Eps.ink),
                ),
                if (lesson.description.isNotEmpty)
                  Text(lesson.description, style: body),
                if (lesson.keyIdea.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 14, 15, 12),
                    decoration: BoxDecoration(
                      color: Eps.orangeSoft,
                      borderRadius: BorderRadius.circular(11),
                      border: const BorderDirectional(
                        end: BorderSide(color: Eps.orange, width: 3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الفكرة الأساسية',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9A6800),
                          ),
                        ),
                        Text(lesson.keyIdea, style: body),
                      ],
                    ),
                  ),
                ],
                if (lesson.example.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'مثال تطبيقي',
                    style: TextStyle(fontSize: 12, color: Eps.ink),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(minHeight: 75),
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Eps.blueSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      lesson.example,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Eps.blue,
                      ),
                    ),
                  ),
                ],
                for (final ex in learn.exercisesFor(lesson.id)) ...[
                  const SizedBox(height: 10),
                  ExerciseCard(exercise: ex),
                ],
                const SizedBox(height: 10),
                AskLessonCard(
                  lessonTitle: lesson.title,
                  subjectName: subject?.name,
                ),
                if (!subscribed) ...[
                  const SizedBox(height: 9),
                  const FreeUpsell(),
                ],
                if (lesson.pdfUrl.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  EpsPrimaryButton(
                    label: 'ملخص الدرس PDF',
                    icon: Icons.description_outlined,
                    onPressed: () => pushPage(
                      context,
                      SecureContentViewerPage(
                        title: lesson.title,
                        url: lesson.pdfUrl,
                        kind: SecureContentKind.pdf,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Positioned(
              left: 14,
              bottom: 64,
              child: AssistantFab(
                lessonTitle: lesson.title,
                subjectName: subject?.name,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Exercise with a revealable step-by-step solution.
class ExerciseCard extends StatefulWidget {
  const ExerciseCard({required this.exercise, super.key});

  final EpsExercise exercise;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    return FlatCard(
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ex.question,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Eps.ink,
            ),
          ),
          if (ex.illustration.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Eps.blueSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                ex.illustration,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Eps.blue,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => open = !open),
            child: Text(
              open ? 'إخفاء الحل' : 'عرض الحل خطوة بخطوة',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Eps.blue,
              ),
            ),
          ),
          if (open)
            for (var i = 0; i < ex.solutionSteps.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ex.solutionSteps[i],
                        style: const TextStyle(fontSize: 9, color: Eps.ink),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// PDF viewer framed like a document (Figma: pdfViewer).
class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({required this.pdf, super.key});

  final EpsPdf pdf;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Column(
            children: [
              EpsPageHeader(
                title: pdf.title,
                action: EpsIconButton(
                  icon: Icons.download_outlined,
                  tooltip: 'تحميل',
                  onTap: () => launchUrl(
                    Uri.parse(pdf.url),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFE3EA),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SecureContentViewerPage(
                      title: pdf.title,
                      url: pdf.url,
                      kind: SecureContentKind.pdf,
                    ),
                  ),
                ),
              ),
              if (!learn.hasAccess(pdf.subjectId)) ...[
                const SizedBox(height: 8),
                const FreeUpsell(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet shown when opening locked content (Figma: locked).
Future<void> showLockedSheet(BuildContext context, String subjectId) {
  final learn = LearnScope.read(context);
  final subject = learn.subjectById(subjectId);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x44172039),
    builder: (sheetContext) => Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Color(0x2A172039), blurRadius: 40)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFC6CBD5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: Eps.blueSoft,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Eps.blue,
              size: 31,
            ),
          ),
          const SizedBox(height: 16),
          const EpsBadge('محتوى للمشتركين', tone: EpsTone.orange),
          const SizedBox(height: 10),
          const Text(
            'هذا المحتوى للمشتركين فقط',
            style: TextStyle(fontSize: 17, color: Eps.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'رقِّ مادة ${subject?.name ?? ''} للوصول إلى جميع الدروس والملفات والجلسات.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 8, color: Eps.muted),
          ),
          const SizedBox(height: 18),
          EpsPrimaryButton(
            label: 'ترقية الآن',
            icon: Icons.star_outline_rounded,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              learn.cart
                ..clear()
                ..add(subjectId);
              pushPage(context, SubjectDetailScreen(subjectId: subjectId));
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text(
              'العودة إلى المادة',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
}

/// Opens a session: live/joinable → room, upcoming → toggles reminder,
/// past → recording.
void openLiveSession(BuildContext context, EpsLiveSession session) {
  final learn = LearnScope.read(context);
  final allowed = session.isFree || learn.hasAccess(session.subjectId);
  if (!allowed) {
    showLockedSheet(context, session.subjectId);
    return;
  }
  switch (session.state) {
    case LiveState.live:
      pushPage(context, LiveRoomScreen(sessionId: session.id));
    case LiveState.upcoming:
      learn.toggleReminder(session.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            learn.reminders.contains(session.id)
                ? 'سنذكّرك قبل بدء الجلسة'
                : 'تم إلغاء التذكير',
          ),
        ),
      );
    case LiveState.past:
      if (session.recordingUrl.isNotEmpty) {
        pushPage(
          context,
          SecureContentViewerPage(
            title: session.title,
            url: session.recordingUrl,
            kind: SecureContentKind.video,
          ),
        );
      }
  }
}

/// "مباشر" tab (Figma: live).
class LiveTab extends StatelessWidget {
  const LiveTab({super.key});

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final now = learn.liveSessions
        .where((s) => s.state == LiveState.live)
        .toList();
    final upcoming = learn.liveSessions
        .where((s) => s.state == LiveState.upcoming)
        .toList();
    final past = learn.liveSessions
        .where((s) => s.state == LiveState.past && s.recordingUrl.isNotEmpty)
        .toList()
        .reversed
        .toList();
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: learn.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
          children: [
            TabTitle(
              small: 'تعلم مع أساتذتك',
              title: 'الجلسات المباشرة',
              action: EpsIconButton(
                icon: Icons.notifications_none_rounded,
                iconSize: 21,
                tooltip: 'الإشعارات',
                onTap: () =>
                    pushPage(context, const StudentNotificationsPage()),
              ),
            ),
            for (final s in now) _LiveNowCard(session: s),
            if (upcoming.isNotEmpty) ...[
              const HomeSectionTitle('القادمة', link: 'هذا الأسبوع'),
              for (final s in upcoming)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LiveSessionRow(session: s),
                ),
            ],
            if (past.isNotEmpty) ...[
              const HomeSectionTitle('التسجيلات السابقة'),
              for (final s in past)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecordingRow(session: s),
                ),
            ],
            if (learn.liveSessions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EpsLogoLoader(label: 'لا توجد جلسات مجدولة حالياً'),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveNowCard extends StatelessWidget {
  const _LiveNowCard({required this.session});

  final EpsLiveSession session;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final subject = learn.subjectById(session.subjectId);
    final teacher = learn.teacherById(session.teacherId);
    final minutes = DateTime.now().difference(session.startsAt).inMinutes;
    const meta = TextStyle(fontSize: 8, color: Eps.muted);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Eps.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 154,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1,
                colors: [Color(0xFF4875CA), Color(0xFF173575)],
              ),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: 88,
                  height: 120,
                  padding: const EdgeInsets.only(top: 14),
                  alignment: Alignment.topCenter,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(44),
                      bottom: Radius.circular(10),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.25, 0.26, 1],
                      colors: [
                        Color(0xFFE9B678),
                        Color(0xFFE9B678),
                        Color(0xFFF7F9FF),
                        Color(0xFFF7F9FF),
                      ],
                    ),
                  ),
                  child: Text(
                    teacher == null ? 'م' : firstLetter(teacher.name),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Eps.ink,
                    ),
                  ),
                ),
                const Positioned(
                  top: 9,
                  right: 9,
                  child: EpsBadge(
                    'مباشر الآن',
                    tone: EpsTone.red,
                    icon: Icons.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: const TextStyle(fontSize: 14, color: Eps.ink),
                ),
                Text(
                  [?subject?.name, ?teacher?.name].join(' • '),
                  style: const TextStyle(fontSize: 9, color: Eps.muted),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.group_outlined,
                      size: 13,
                      color: Eps.muted,
                    ),
                    const SizedBox(width: 3),
                    Text('${session.attendees} يشاهدون', style: meta),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: Eps.muted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'بدأ منذ ${minutes < 0 ? 0 : minutes} دقيقة',
                      style: meta,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          EpsPrimaryButton(
            label: 'انضم إلى الجلسة',
            icon: Icons.videocam_outlined,
            onPressed: () => openLiveSession(context, session),
          ),
        ],
      ),
    );
  }
}

/// Upcoming session row with date box and reminder bell (`.upcoming-card`).
class LiveSessionRow extends StatelessWidget {
  const LiveSessionRow({required this.session, super.key});

  final EpsLiveSession session;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final subject = learn.subjectById(session.subjectId);
    final teacher = learn.teacherById(session.teacherId);
    final days = DateUtils.dateOnly(
      session.startsAt,
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    final soon = days <= 2;
    final when = switch (session.state) {
      LiveState.live => 'مباشر الآن',
      LiveState.past => 'انتهت',
      _ =>
        days <= 0
            ? 'اليوم'
            : days == 1
            ? 'غداً'
            : days == 2
            ? 'بعد يومين'
            : 'بعد $days أيام',
    };
    final reminded = learn.reminders.contains(session.id);
    return GestureDetector(
      onTap: () => openLiveSession(context, session),
      child: Container(
        height: 75,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Eps.line),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 51,
              decoration: BoxDecoration(
                color: soon ? Eps.blueSoft : Eps.orangeSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${session.startsAt.day}',
                    style: TextStyle(
                      fontFamily: Eps.fontNum,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: soon ? Eps.blue : const Color(0xFFB87100),
                      height: 1.2,
                    ),
                  ),
                  Text(
                    arMonth(session.startsAt),
                    style: TextStyle(
                      fontSize: 8,
                      color: soon ? Eps.blue : const Color(0xFFB87100),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EpsBadge(when, tone: soon ? EpsTone.blue : EpsTone.gray),
                  const SizedBox(height: 2),
                  Text(
                    subject?.name ?? session.title,
                    style: const TextStyle(fontSize: 10, color: Eps.ink),
                  ),
                  Text(
                    [?teacher?.name, hhmm(session.startsAt)].join(' • '),
                    style: const TextStyle(fontSize: 8, color: Eps.muted),
                  ),
                ],
              ),
            ),
            EpsIconButton(
              icon: reminded
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              tooltip: 'تذكير',
              onTap: () => learn.toggleReminder(session.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingRow extends StatelessWidget {
  const _RecordingRow({required this.session});

  final EpsLiveSession session;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openLiveSession(context, session),
      child: Container(
        height: 61,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Eps.line),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 43,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF173676), Color(0xFF6F8CCA)],
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Eps.ink,
                    ),
                  ),
                  Text(
                    '${session.durationMinutes} دقيقة • ${session.startsAt.day} ${arMonth(session.startsAt)}',
                    style: const TextStyle(fontSize: 7, color: Eps.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Eps.ink, size: 17),
          ],
        ),
      ),
    );
  }
}

/// Live room with video stage, chat and questions (Figma: liveRoom).
class LiveRoomScreen extends StatefulWidget {
  const LiveRoomScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  final input = TextEditingController();
  List<EpsLiveMessage> messages = [];
  bool questionsTab = false;
  Timer? poll;

  @override
  void initState() {
    super.initState();
    load();
    poll = Timer.periodic(const Duration(seconds: 4), (_) => load());
  }

  @override
  void dispose() {
    poll?.cancel();
    input.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final learn = LearnScope.read(context);
    if (!learn.enabled) {
      return;
    }
    try {
      final items = await learn.repo.liveMessages(widget.sessionId);
      if (mounted) {
        setState(() => messages = items);
      }
    } on Object {
      // Keep the last messages on transient network errors.
    }
  }

  Future<void> send(String text, {bool question = false}) async {
    final body = text.trim();
    if (body.isEmpty) {
      return;
    }
    final learn = LearnScope.read(context);
    final user = StoreScope.of(context).currentUser!;
    input.clear();
    await learn.repo.sendLiveMessage(
      sessionId: widget.sessionId,
      userId: user.id,
      userName: user.name,
      body: body,
      isQuestion: question || questionsTab,
      isTeacher: user.role == UserRole.teacher,
    );
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final session = learn.liveSessions
        .where((s) => s.id == widget.sessionId)
        .firstOrNull;
    if (session == null) {
      return const EpsPage(title: 'الجلسة', children: []);
    }
    final subject = learn.subjectById(session.subjectId);
    final teacher = learn.teacherById(session.teacherId);
    final questions = messages.where((m) => m.isQuestion).toList();
    final shown = questionsTab ? questions : messages;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _VideoStage(session: session, teacherName: teacher?.name),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: const TextStyle(fontSize: 13, color: Eps.ink),
                      ),
                      Text(
                        [?subject?.name, ?teacher?.name].join(' • '),
                        style: const TextStyle(fontSize: 8, color: Eps.muted),
                      ),
                    ],
                  ),
                ),
                EpsIconButton(
                  icon: learn.reminders.contains(session.id)
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  tooltip: 'تذكير',
                  onTap: () => learn.toggleReminder(session.id),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => questionsTab = false),
                  child: Text(
                    'المحادثة المباشرة',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: questionsTab
                          ? FontWeight.w400
                          : FontWeight.w700,
                      color: questionsTab ? Eps.muted : Eps.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 25),
                GestureDetector(
                  onTap: () => setState(() => questionsTab = true),
                  child: Row(
                    children: [
                      Text(
                        'الأسئلة',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: questionsTab
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: questionsTab ? Eps.blue : Eps.muted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Eps.orangeSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${questions.length}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFB87400),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
              itemCount: shown.length,
              itemBuilder: (context, i) => _ChatBubble(message: shown[i]),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Eps.line)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 9),
            child: Row(
              children: [
                _ReactButton(label: '+1', onTap: () => send('👍')),
                const SizedBox(width: 7),
                _ReactButton(
                  icon: Icons.star_border_rounded,
                  onTap: () => send('⭐'),
                ),
                const Spacer(),
                _ReactButton(
                  icon: Icons.mic_none_rounded,
                  label: 'ارفع يدك',
                  wide: true,
                  onTap: () => send('✋ رفع يده لطرح سؤال', question: true),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              height: 42,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                      onSubmitted: send,
                      style: const TextStyle(fontSize: 9),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'اكتب سؤالك...',
                        hintStyle: TextStyle(fontSize: 9, color: Eps.faint),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => send(input.text),
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
          ),
        ],
      ),
    );
  }
}

class _VideoStage extends StatefulWidget {
  const _VideoStage({required this.session, this.teacherName});

  final EpsLiveSession session;
  final String? teacherName;

  @override
  State<_VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends State<_VideoStage> {
  WebViewController? web;

  @override
  void initState() {
    super.initState();
    final url = Uri.tryParse(widget.session.liveUrl);
    if (url != null && url.hasScheme) {
      web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF17213B))
        ..loadRequest(url);
    }
  }

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
          if (web != null)
            Positioned.fill(child: WebViewWidget(controller: web!))
          else ...[
            const Positioned(
              right: 35,
              top: 40,
              child: Text(
                '∫ f(x) dx',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontStyle: FontStyle.italic,
                  fontSize: 27,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              left: 18,
              bottom: 14,
              child: Container(
                width: 75,
                height: 92,
                padding: const EdgeInsets.only(top: 6),
                alignment: Alignment.topCenter,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(40),
                    bottom: Radius.circular(10),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.3, 0.31, 1],
                    colors: [
                      Color(0xFFE6B274),
                      Color(0xFFE6B274),
                      Color(0xFFF7F9FF),
                      Color(0xFFF7F9FF),
                    ],
                  ),
                ),
                child: Text(
                  widget.teacherName == null
                      ? ''
                      : widget.teacherName!.split(' ').take(2).join(' '),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF543B2B),
                  ),
                ),
              ),
            ),
          ],
          Positioned(
            left: 16,
            top: 15,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0x20FFFFFF),
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
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0x77000000),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    '${widget.session.attendees}',
                    style: const TextStyle(
                      fontFamily: Eps.fontNum,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.group_outlined,
                    size: 12,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final EpsLiveMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 29,
            height: 29,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF0C991),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              firstLetter(message.userName.isEmpty ? '؟' : message.userName),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Eps.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
              decoration: BoxDecoration(
                color: message.isTeacher
                    ? Eps.blueSoft
                    : const Color(0xFFF2F4F8),
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(3),
                  topEnd: Radius.circular(11),
                  bottomStart: Radius.circular(11),
                  bottomEnd: Radius.circular(11),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.userName,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Eps.ink,
                        ),
                      ),
                      if (message.isTeacher) ...[
                        const SizedBox(width: 5),
                        const Text(
                          'الأستاذ',
                          style: TextStyle(
                            fontSize: 6.4,
                            fontWeight: FontWeight.w700,
                            color: Eps.blue,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    message.body,
                    style: const TextStyle(fontSize: 9, color: Eps.ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactButton extends StatelessWidget {
  const _ReactButton({
    required this.onTap,
    this.label,
    this.icon,
    this.wide = false,
  });

  final VoidCallback onTap;
  final String? label;
  final IconData? icon;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: wide ? 80 : 40,
        height: 35,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Eps.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: wide ? 9 : 16,
                  color: wide ? Eps.blue : Eps.ink,
                ),
              ),
            if (icon != null && label != null) const SizedBox(width: 4),
            if (icon != null)
              Icon(
                icon,
                size: wide ? 14 : 18,
                color: wide ? Eps.blue : Eps.ink,
              ),
          ],
        ),
      ),
    );
  }
}
