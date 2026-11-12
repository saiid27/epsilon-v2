part of '../main.dart';

/// Amber XP pill (`.xp-pill`).
class XpPill extends StatelessWidget {
  const XpPill({required this.xp, super.key});

  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Eps.orangeSoft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFFF1B91C), size: 15),
          const SizedBox(width: 4),
          Text(
            formatMru(xp),
            style: const TextStyle(
              fontFamily: Eps.fontNum,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Color(0xFFBB7600),
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'XP',
            style: TextStyle(
              fontFamily: Eps.fontNum,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFFBB7600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiz row used inside the subject page.
class QuizRow extends StatelessWidget {
  const QuizRow({required this.quiz, super.key});

  final EpsQuiz quiz;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final allowed =
        quiz.isFree ||
        quiz.subjectId == null ||
        learn.hasAccess(quiz.subjectId);
    return _ListRow(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Eps.orangeSoft,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(
          Icons.sports_esports_outlined,
          color: Color(0xFFD78500),
          size: 20,
        ),
      ),
      title: quiz.title,
      subtitle: '${quiz.questionsCount} أسئلة • ${quiz.xpReward} XP',
      onTap: () => allowed
          ? pushPage(context, QuestionScreen(quizId: quiz.id))
          : showLockedSheet(context, quiz.subjectId!),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Eps.line),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Eps.ink,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 7,
                      color: Eps.muted,
                      height: 1.5,
                    ),
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

/// "الاختبارات" tab (Figma: quizzes).
class QuizzesTab extends StatefulWidget {
  const QuizzesTab({super.key});

  @override
  State<QuizzesTab> createState() => _QuizzesTabState();
}

class _QuizzesTabState extends State<QuizzesTab> {
  int? myRank;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRank();
  }

  Future<void> _loadRank() async {
    final learn = LearnScope.read(context);
    if (!learn.enabled || learn.userId == null) {
      return;
    }
    try {
      final board = await learn.repo.leaderboard();
      final i = board.indexWhere((e) => e.studentId == learn.userId);
      if (mounted) {
        setState(() => myRank = i < 0 ? null : i + 1);
      }
    } on Object {
      // Rank is optional.
    }
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final daily = learn.dailyQuiz;
    final subjects = learn.subjects
        .where((s) => learn.quizzesFor(s.id).isNotEmpty)
        .toList();
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: learn.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
          children: [
            TabTitle(
              small: 'اختبر معلوماتك',
              title: 'الاختبارات',
              action: XpPill(xp: learn.totalXp),
            ),
            if (daily != null)
              _DailyCard(quiz: daily, streak: learn.profile?.activeStreak ?? 0),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    icon: Icons.sports_esports_outlined,
                    title: 'لعب سريع',
                    subtitle: 'أسئلة عشوائية',
                    onTap: () {
                      final pool = learn.quizzes
                          .where(
                            (q) =>
                                q.questionsCount > 0 &&
                                (q.isFree ||
                                    q.subjectId == null ||
                                    learn.hasAccess(q.subjectId)),
                          )
                          .toList();
                      if (pool.isEmpty) {
                        return;
                      }
                      final q = pool[Random().nextInt(pool.length)];
                      pushPage(context, QuestionScreen(quizId: q.id));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeCard(
                    icon: Icons.group_outlined,
                    title: 'تحدّ صديقاً',
                    subtitle: 'شارك رمز اللعب',
                    onTap: () {
                      final code = (learn.userId ?? '').substring(
                        0,
                        min(6, (learn.userId ?? '').length),
                      );
                      share.SharePlus.instance.share(
                        share.ShareParams(
                          text:
                              'تحداك صديقك في Epsilon Education! حمّل التطبيق وأدخل رمز اللعب: ${code.toUpperCase()}',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (subjects.isNotEmpty) const HomeSectionTitle('حسب المادة'),
            for (final s in subjects)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _ListRow(
                  leading: SubjectMark(subject: s, size: 40, fontSize: 16),
                  title: s.name,
                  subtitle: '${learn.quizzesFor(s.id).length} اختبارات متاحة',
                  onTap: () =>
                      pushPage(context, SubjectQuizzesPage(subject: s)),
                ),
              ),
            const SizedBox(height: 5),
            GestureDetector(
              onTap: () => pushPage(context, const LeaderboardScreen()),
              child: Container(
                height: 45,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Eps.orangeSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF8DDA3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      color: Color(0xFFD78500),
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'لوحة المتصدرين',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF986000),
                              height: 1.5,
                            ),
                          ),
                          Text(
                            myRank == null
                                ? 'شارك في الاختبارات لتظهر في الترتيب'
                                : 'أنت في المركز $myRank هذا الأسبوع',
                            style: const TextStyle(
                              fontSize: 7,
                              color: Eps.muted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF986000),
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.quiz, required this.streak});

  final EpsQuiz quiz;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final minutes = (quiz.timeLimitSeconds / 60).ceil();
    return GestureDetector(
      onTap: () => pushPage(context, QuestionScreen(quizId: quiz.id)),
      child: Container(
        height: 174,
        padding: const EdgeInsets.fromLTRB(17, 17, 17, 17),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: const LinearGradient(
            begin: Alignment(-1, -0.84),
            end: Alignment(1, 0.84),
            colors: [Color(0xFF153274), Color(0xFF295AB7)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              left: -10,
              bottom: -14,
              child: Icon(
                Icons.bolt_rounded,
                size: 60,
                color: Color(0x14FFFFFF),
              ),
            ),
            Positioned(
              left: -60,
              top: -60,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x10FFFFFF), width: 18),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 58,
                  height: 83,
                  decoration: BoxDecoration(
                    color: const Color(0x18FFFFFF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFF1B91C),
                        size: 19,
                      ),
                      Text(
                        '$streak',
                        style: const TextStyle(
                          fontFamily: Eps.fontNum,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'أيام',
                        style: TextStyle(fontSize: 7, color: Color(0xFFDCE6FF)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EpsBadge('تحدي اليوم', tone: EpsTone.orange),
                      const SizedBox(height: 6),
                      const Text(
                        'هل أنت مستعد؟',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      Text(
                        '${quiz.questionsCount} أسئلة • ${quiz.xpReward} XP • ${minutes == 2 ? 'دقيقتان' : '$minutes دقائق'}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFFCEDAF5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Text(
                            'ابدأ التحدي',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ],
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

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Eps.line),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Eps.blueSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Eps.blue, size: 21),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Eps.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 7, color: Eps.muted),
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

/// List of quizzes for one subject.
class SubjectQuizzesPage extends StatelessWidget {
  const SubjectQuizzesPage({required this.subject, super.key});

  final EpsSubject subject;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    return EpsPage(
      title: subject.name,
      children: [
        for (final q in learn.quizzesFor(subject.id))
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: QuizRow(quiz: q),
          ),
      ],
    );
  }
}

/// Question screen with per-question timer (Figma: question).
class QuestionScreen extends StatefulWidget {
  const QuestionScreen({required this.quizId, super.key});

  final String quizId;

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  List<EpsQuestion>? questions;
  final answers = <int>[];
  int index = 0;
  int? picked;
  int secondsLeft = 30;
  final watch = Stopwatch();
  Timer? timer;
  bool saving = false;
  String? error;

  EpsQuiz get quiz =>
      LearnScope.read(context).quizzes.firstWhere((q) => q.id == widget.quizId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final items = await LearnScope.read(
        context,
      ).repo.questions(widget.quizId);
      if (!mounted) {
        return;
      }
      setState(() => questions = items);
      watch.start();
      startTimer();
    } on Object catch (e) {
      setState(() => error = '$e');
    }
  }

  void startTimer() {
    timer?.cancel();
    secondsLeft = quiz.questionSeconds;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        return;
      }
      if (secondsLeft <= 1) {
        t.cancel();
        next(timeout: true);
        return;
      }
      setState(() => secondsLeft--);
    });
  }

  Future<void> next({bool timeout = false}) async {
    final items = questions!;
    answers.add(timeout ? (picked ?? -1) : picked!);
    if (index < items.length - 1) {
      setState(() {
        index++;
        picked = null;
      });
      startTimer();
      return;
    }
    timer?.cancel();
    watch.stop();
    setState(() => saving = true);
    try {
      await LearnScope.read(context).finishQuiz(
        quiz: quiz,
        questions: items,
        answers: answers,
        seconds: watch.elapsed.inSeconds,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const QuizResultScreen()),
        );
      }
    } on Object catch (e) {
      setState(() {
        saving = false;
        error = 'تعذر حفظ النتيجة: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final items = questions;
    final q = items == null || items.isEmpty ? null : items[index];
    final subject = learn.subjectById(quiz.subjectId);
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
          children: [
            SizedBox(
              height: 70,
              child: Row(
                children: [
                  EpsIconButton(
                    icon: Icons.close_rounded,
                    size: 35,
                    tooltip: 'إغلاق',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      subject?.name ?? quiz.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Eps.ink,
                      ),
                    ),
                  ),
                  XpPill(xp: quiz.xpReward),
                ],
              ),
            ),
            if (error != null) AuthErrorText(error!),
            if (items == null && error == null)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: EpsLogoLoader(),
              ),
            if (items != null && q == null)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Text(
                  'لا توجد أسئلة في هذا الاختبار بعد',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Eps.muted),
                ),
              ),
            if (q != null) ...[
              Row(
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'السؤال ',
                      children: [
                        TextSpan(
                          text: '${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' من ${items!.length}'),
                      ],
                    ),
                    style: const TextStyle(fontSize: 9, color: Eps.muted),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: secondsLeft / quiz.questionSeconds,
                          strokeWidth: 4,
                          color: Eps.orange,
                          backgroundColor: const Color(0xFFF3E6C2),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$secondsLeft',
                              style: const TextStyle(
                                fontFamily: Eps.fontNum,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Eps.ink,
                                height: 1,
                              ),
                            ),
                            const Text(
                              'ث',
                              style: TextStyle(
                                fontSize: 6,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              EpsProgress(value: (index + 1) / items.length, height: 5),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: Eps.line),
                  boxShadow: Eps.cardShadow,
                ),
                child: Column(
                  children: [
                    if (q.formula.isNotEmpty)
                      const Text(
                        '∫',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 25,
                          color: Eps.blue,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      q.prompt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Eps.ink),
                    ),
                    if (q.formula.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Eps.blueSoft,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          q.formula,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Eps.blue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 13),
              for (var i = 0; i < q.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _OptionTile(
                    letter: String.fromCharCode(65 + i),
                    text: q.options[i],
                    selected: picked == i,
                    onTap: () => setState(() => picked = i),
                  ),
                ),
              const SizedBox(height: 5),
              EpsPrimaryButton(
                label: index == items.length - 1
                    ? 'إنهاء الاختبار'
                    : 'السؤال التالي',
                icon: Icons.chevron_right_rounded,
                loading: saving,
                onPressed: picked == null ? null : () => next(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: selected ? Eps.blueSoft : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? Eps.blue2 : Eps.line),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Eps.blue : Eps.gray,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontFamily: Eps.fontNum,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF687188),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Eps.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Result screen (Figma: result).
class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final result = learn.lastResult;
    final name = firstName(StoreScope.of(context).currentUser?.name ?? '');
    if (result == null) {
      return const EpsPage(title: 'النتيجة', children: []);
    }
    final a = result.attempt;
    final accuracy = a.total == 0
        ? 0
        : (a.correctCount * 100 / a.total).round();
    final stars = accuracy >= 80
        ? 3
        : accuracy >= 50
        ? 2
        : accuracy > 0
        ? 1
        : 0;
    final time =
        '${a.durationSeconds ~/ 60}:${(a.durationSeconds % 60).toString().padLeft(2, '0')}';
    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontFamily: Eps.fontNum,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Eps.blue,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 7, color: Eps.muted)),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
          children: [
            const SizedBox(
              height: 130,
              child: Align(
                alignment: Alignment(0.5, -0.2),
                child: Text(
                  '✦',
                  style: TextStyle(fontSize: 30, color: Eps.orange),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 81,
                height: 81,
                decoration: BoxDecoration(
                  color: Eps.orangeSoft,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33F1B91C),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: Color(0xFFD78500),
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              accuracy >= 50 ? 'أداء رائع يا $name!' : 'حاول مرة أخرى يا $name',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, color: Eps.ink),
            ),
            Text(
              result.quiz.kind == 'daily'
                  ? 'لقد أتممت تحدي اليوم بنجاح'
                  : 'لقد أتممت الاختبار',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: Eps.muted),
            ),
            const SizedBox(height: 18),
            Center(
              child: Container(
                width: 119,
                height: 119,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Eps.green, width: 8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2216A36A),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: '${a.correctCount}',
                        children: [
                          TextSpan(
                            text: '/${a.total}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Eps.muted,
                            ),
                          ),
                        ],
                      ),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: Eps.fontNum,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Eps.ink,
                      ),
                    ),
                    const Text(
                      'النتيجة',
                      style: TextStyle(fontSize: 8, color: Eps.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                stat('$accuracy%', 'الدقة'),
                stat('+${a.xpEarned}', 'XP مكتسب'),
                stat(time, 'الوقت'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Icon(
                    i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Eps.orange,
                    size: 26,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            EpsPrimaryButton(
              label: 'مراجعة الإجابات',
              icon: Icons.fact_check_outlined,
              onPressed: () => pushPage(context, const AnswerReviewPage()),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: Color(0xFFBCC6DC)),
                textStyle: const TextStyle(
                  fontFamily: Eps.font,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => QuestionScreen(quizId: result.quiz.id),
                ),
              ),
              icon: const Icon(Icons.sports_esports_outlined, size: 17),
              label: const Text('العب مرة أخرى'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Review of each question with the correct answer.
class AnswerReviewPage extends StatelessWidget {
  const AnswerReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final result = LearnScope.of(context).lastResult!;
    return EpsPage(
      title: 'مراجعة الإجابات',
      children: [
        for (var i = 0; i < result.questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FlatCard(
              radius: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${i + 1}. ${result.questions[i].prompt}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (result.questions[i].formula.isNotEmpty)
                    Text(
                      result.questions[i].formula,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Eps.blue),
                    ),
                  const SizedBox(height: 6),
                  for (var o = 0; o < result.questions[i].options.length; o++)
                    Text(
                      '${String.fromCharCode(65 + o)}. ${result.questions[i].options[o]}',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: o == result.questions[i].correctIndex
                            ? FontWeight.w800
                            : FontWeight.w400,
                        color: o == result.questions[i].correctIndex
                            ? Eps.green
                            : i < result.answers.length &&
                                  result.answers[i] == o
                            ? Eps.red
                            : Eps.muted,
                      ),
                    ),
                  if (result.questions[i].explanation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      result.questions[i].explanation,
                      style: const TextStyle(fontSize: 9, color: Eps.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Leaderboard (Figma: leaderboard).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int tab = 0;
  String? subjectId;
  List<EpsLeader>? board;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final learn = LearnScope.read(context);
    setState(() => board = null);
    if (tab == 2) {
      subjectId ??= learn.subjects.firstOrNull?.id;
    }
    final items = await learn.repo.leaderboard(
      weekly: tab == 0,
      subjectId: tab == 2 ? subjectId : null,
    );
    if (mounted) {
      setState(() => board = items);
    }
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final me = learn.userId;
    final items = board ?? [];
    final myIndex = items.indexWhere((e) => e.studentId == me);
    final top = items.take(3).toList();
    return EpsPage(
      title: 'لوحة المتصدرين',
      children: [
        EpsSegmented(
          labels: const ['أسبوعي', 'كل الأوقات', 'حسب المادة'],
          index: tab,
          onChanged: (i) {
            setState(() => tab = i);
            load();
          },
        ),
        if (tab == 2 && learn.subjects.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final s in learn.subjects)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      label: Text(s.name, style: const TextStyle(fontSize: 9)),
                      selected: s.id == subjectId,
                      onSelected: (_) {
                        subjectId = s.id;
                        load();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (board == null)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: EpsLogoLoader(),
          )
        else ...[
          const SizedBox(height: 12),
          const Center(
            child: Icon(
              Icons.emoji_events_outlined,
              color: Color(0xFFD78500),
              size: 24,
            ),
          ),
          if (top.isNotEmpty)
            SizedBox(
              height: 157,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (top.length > 1) _Podium(leader: top[1], height: 120),
                  const SizedBox(width: 8),
                  _Podium(leader: top[0], height: 157, winner: true),
                  const SizedBox(width: 8),
                  if (top.length > 2) _Podium(leader: top[2], height: 120),
                ],
              ),
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length && i < 10; i++)
            _LeaderRow(
              rank: i + 1,
              leader: items[i],
              me: items[i].studentId == me,
            ),
          if (myIndex >= 10)
            _LeaderRow(rank: myIndex + 1, leader: items[myIndex], me: true),
        ],
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({
    required this.leader,
    required this.height,
    this.winner = false,
  });

  final EpsLeader leader;
  final double height;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: height,
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: winner ? Eps.orangeSoft : const Color(0xFFE8EDF8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          Container(
            width: 45,
            height: 45,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              firstLetter(leader.name),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Eps.blue,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            firstName(leader.name),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Eps.ink,
            ),
          ),
          Text(
            '${formatMru(leader.xp)} XP',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontFamily: Eps.fontNum,
              fontSize: 7,
              fontWeight: FontWeight.w600,
              color: Eps.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.leader,
    required this.me,
  });

  final int rank;
  final EpsLeader leader;
  final bool me;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: me ? Eps.blueSoft : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: me ? Eps.blue2 : Eps.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: Eps.fontNum,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Eps.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1C887),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              firstLetter(leader.name),
              style: const TextStyle(fontSize: 10, color: Eps.ink),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              me ? '${leader.name} (أنت)' : leader.name,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Eps.ink,
              ),
            ),
          ),
          Text(
            '${formatMru(leader.xp)} XP',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontFamily: Eps.fontNum,
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: Eps.blue,
            ),
          ),
        ],
      ),
    );
  }
}
