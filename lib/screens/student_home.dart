part of '../main.dart';

/// Student app shell with the five-tab bottom navigation (Figma: home,
/// subjects, live, quizzes, profile).
class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => StudentShellState();
}

class StudentShellState extends State<StudentShell> {
  int tab = 0;
  bool showWelcome = false;

  static StudentShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<StudentShellState>();

  void goTab(int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => tab = index);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = StoreScope.of(context).currentUser;
    final learn = LearnScope.read(context);
    if (user != null && learn.userId != user.id) {
      learn.load(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final profile = learn.profile;
    if (profile != null && !profile.profileCompleted) {
      return ProfileSetupScreen(
        onDone: () => setState(() => showWelcome = true),
      );
    }
    if (showWelcome) {
      return WelcomeScreen(onStart: () => setState(() => showWelcome = false));
    }
    final hasLive = learn.liveSessions.any((s) => s.state == LiveState.live);
    final pages = [
      const StudentHomeTab(),
      const MySubjectsTab(),
      const LiveTab(),
      const QuizzesTab(),
      const ProfileTab(),
    ];
    return Scaffold(
      backgroundColor: Eps.bg,
      body: Stack(
        children: [
          IndexedStack(index: tab, children: pages),
          if (tab == 0)
            const Positioned(left: 14, bottom: 11, child: AssistantFab()),
        ],
      ),
      bottomNavigationBar: EpsBottomNav(
        index: tab,
        onChanged: goTab,
        items: [
          const EpsNavItem('الرئيسية', Icons.home_outlined),
          const EpsNavItem('موادي', Icons.menu_book_outlined),
          EpsNavItem('مباشر', Icons.sensors_rounded, dot: hasLive),
          const EpsNavItem('الاختبارات', Icons.sports_esports_outlined),
          const EpsNavItem('حسابي', Icons.person_outline_rounded),
        ],
      ),
    );
  }
}

/// Floating assistant button with a soft ring (`.ai-floating-button`).
class AssistantFab extends StatelessWidget {
  const AssistantFab({this.lessonTitle, this.subjectName, super.key});

  final String? lessonTitle;
  final String? subjectName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 73,
      height: 73,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 73,
            height: 73,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x442F5BD3), width: 2),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AssistantScreen(
                  lessonTitle: lessonTitle,
                  subjectName: subjectName,
                ),
              ),
            ),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Eps.blue, Color(0xFF6488E6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x462F5BD3),
                    blurRadius: 24,
                    offset: Offset(0, 9),
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 21,
                semanticLabel: 'مساعد إبسيلون',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a full-screen route.
void pushPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

/// Section title (`.section-title`): 15px/800 + 10px/700 link.
class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle(this.title, {this.link, this.onTap, super.key});

  final String title;
  final String? link;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(1, 14, 1, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Eps.ink,
                height: 1.5,
              ),
            ),
          ),
          if (link != null)
            GestureDetector(
              onTap: onTap,
              child: Text(
                link!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Eps.blue2,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Coloured square with the subject glyph (`.subject-mark`).
class SubjectMark extends StatelessWidget {
  const SubjectMark({
    required this.subject,
    this.size = 48,
    this.radius = 13,
    this.fontSize = 21,
    super.key,
  });

  final EpsSubject subject;
  final double size;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: subject.color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        subject.icon,
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontFamily: Eps.fontNum,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: subjectInk(subject.color),
          height: 1,
        ),
      ),
    );
  }
}

/// Darker ink colour that pairs with a pastel subject colour.
Color subjectInk(Color bg) {
  final hsl = HSLColor.fromColor(bg);
  return hsl.withSaturation(0.75).withLightness(0.45).toColor();
}

/// Plain white card used across the student screens (`.continue-card`).
class FlatCard extends StatelessWidget {
  const FlatCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.radius = 17,
    this.color = Colors.white,
    this.border = Eps.line,
    this.gradient,
    this.shadow = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color border;
  final Gradient? gradient;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: gradient == null ? color : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border),
          boxShadow: shadow
              ? const [
                  BoxShadow(
                    color: Color(0x0918254A),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

String firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

String timeAgo(DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) {
    return 'الآن';
  }
  if (diff.inMinutes < 60) {
    return 'منذ ${diff.inMinutes} دقيقة';
  }
  if (diff.inHours < 24) {
    return diff.inHours == 1
        ? 'منذ ساعة'
        : diff.inHours == 2
        ? 'منذ ساعتين'
        : 'منذ ${diff.inHours} ساعات';
  }
  if (diff.inDays == 1) {
    return 'أمس';
  }
  return 'منذ ${diff.inDays} أيام';
}

const _arMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String arMonth(DateTime d) => _arMonths[d.month - 1];

String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String liveWhen(DateTime d) {
  final now = DateTime.now();
  if (DateUtils.isSameDay(d, now)) {
    return 'اليوم، ${hhmm(d)}';
  }
  return '${d.day} ${arMonth(d)} • ${hhmm(d)}';
}

String formatMru(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      buf.write(',');
    }
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Home tab (Figma: home).
class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  bool bannerCollapsed = false;
  int heroIndex = 0;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final learn = LearnScope.of(context);
    final user = store.currentUser!;
    final shell = StudentShellState.of(context);
    final pending = learn.withStatus(SubscriptionStatus.pending);
    final rejected = learn.withStatus(SubscriptionStatus.rejected);
    final heroes = [
      ...learn.liveSessions.where((s) => s.state == LiveState.live),
      ...learn.liveSessions.where((s) => s.state == LiveState.upcoming),
    ].take(3).toList();
    final active = learn.activeSubjects.firstOrNull;
    final daily = learn.dailyQuiz;
    final announcement = learn.announcements.firstOrNull;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: learn.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
          children: [
            _HomeHead(
              name: firstName(user.name),
              unread: learn.unreadNotices,
              onProfile: () => shell?.goTab(4),
              onBell: () => pushPage(context, const StudentNotificationsPage()),
            ),
            if (!learn.isSubscribed)
              UpgradeBanner(
                collapsed: bannerCollapsed,
                onToggle: () =>
                    setState(() => bannerCollapsed = !bannerCollapsed),
                onUpgrade: () => pushPage(context, const UpgradeScreen()),
              ),
            _FreeCta(onTap: () => pushPage(context, const FreePlanScreen())),
            const SizedBox(height: 12),
            _AddSubjectCard(
              onTap: () => pushPage(context, const SectionsScreen()),
            ),
            for (final sub in pending)
              _StateCard(
                pending: true,
                title: learn.subjectById(sub.subjectId)?.name ?? '',
                note: 'سيظهر في موادي بعد موافقة الإدارة',
                onTap: () => pushPage(context, const PaymentsStatusPage()),
              ),
            for (final sub in rejected)
              _StateCard(
                pending: false,
                title: learn.subjectById(sub.subjectId)?.name ?? '',
                note:
                    '${sub.rejectionReason.isEmpty ? 'الوصل غير واضح' : sub.rejectionReason} • إعادة رفع الوصل',
                onTap: () {
                  learn.cart
                    ..clear()
                    ..add(sub.subjectId);
                  pushPage(context, const ReceiptUploadScreen());
                },
              ),
            if (heroes.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 206,
                child: PageView.builder(
                  itemCount: heroes.length,
                  onPageChanged: (i) => setState(() => heroIndex = i),
                  itemBuilder: (context, i) => _LiveHero(session: heroes[i]),
                ),
              ),
              _PagerDots(count: heroes.length, index: heroIndex),
            ],
            HomeSectionTitle(
              'تابع التعلّم',
              link: 'عرض موادي',
              onTap: () => shell?.goTab(1),
            ),
            if (active != null)
              _ContinueCard(subject: active)
            else
              _EmptyContinueCard(
                onTap: () => pushPage(context, const SectionsScreen()),
              ),
            if (daily != null) ...[
              const HomeSectionTitle('تحدي اليوم'),
              _ChallengeCard(
                quiz: daily,
                streak: learn.profile?.activeStreak ?? 0,
              ),
            ],
            if (announcement != null) ...[
              HomeSectionTitle(
                'إعلانات الجامعة',
                link: 'الكل',
                onTap: () => pushPage(context, const AnnouncementsPage()),
              ),
              _AnnouncementCard(item: announcement),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeHead extends StatelessWidget {
  const _HomeHead({
    required this.name,
    required this.unread,
    required this.onProfile,
    required this.onBell,
  });

  final String name;
  final int unread;
  final VoidCallback onProfile;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    Widget blob(Color c, double size) => ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5),
      child: Opacity(
        opacity: 0.2,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
      ),
    );
    return SizedBox(
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(right: 42, top: -46, child: blob(Eps.blue, 83)),
          Positioned(
            left: 17,
            top: -27,
            child: blob(const Color(0xFFF5C52F), 58),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 18),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onProfile,
                  child: const EpsLogo(size: 44, shadow: null),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'أهلاً بعودتك',
                        style: TextStyle(
                          fontSize: 11,
                          color: Eps.muted,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        'مرحباً، $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                const SizedBox(width: 12),
                EpsIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'الإشعارات',
                  iconSize: 21,
                  badge: unread,
                  onTap: onBell,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "You are on the free plan" strip (`.upgrade-banner`).
class UpgradeBanner extends StatelessWidget {
  const UpgradeBanner({
    required this.collapsed,
    required this.onToggle,
    required this.onUpgrade,
    super.key,
  });

  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        constraints: BoxConstraints(minHeight: collapsed ? 34 : 59),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment(1, -0.27),
            end: Alignment(-1, 0.27),
            colors: [Color(0xFF294FB7), Color(0xFF6E98EE)],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFADC4F6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2A1E3A8A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: collapsed ? 22 : 36,
              height: collapsed ? 22 : 36,
              decoration: BoxDecoration(
                color: const Color(0x1BFFFFFF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.star_rounded,
                color: const Color(0xFFF9CE42),
                size: collapsed ? 13 : 18,
              ),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'أنت على الخطة المجانية',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    'رقِّ خطتك لتستفيد أكثر',
                    style: TextStyle(
                      fontSize: 6,
                      color: Color(0xFFDBE6FF),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (!collapsed)
              GestureDetector(
                onTap: onUpgrade,
                child: Container(
                  width: 49,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text(
                    'ترقية',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: Eps.blue,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x10FFFFFF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    collapsed ? '+' : '−',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1,
                      color: Color(0xFFDCE6FF),
                    ),
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

class _FreeCta extends StatelessWidget {
  const _FreeCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      gradient: const LinearGradient(
        begin: Alignment(-1, -0.18),
        end: Alignment(1, 0.18),
        colors: [Color(0xFFEBFAF3), Color(0xFFF8FFFC)],
      ),
      border: const Color(0xFFCCE9DB),
      child: Row(
        children: [
          Container(
            width: 41,
            height: 41,
            decoration: BoxDecoration(
              color: Eps.green,
              borderRadius: BorderRadius.circular(13),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3316A36A),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'محتوى مجاني للجميع',
                  style: TextStyle(
                    fontSize: 8,
                    color: Color(0xFF5C8D79),
                    height: 1.5,
                  ),
                ),
                Text(
                  'ابدأ مجاناً',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A7750),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF0A7750),
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _AddSubjectCard extends StatelessWidget {
  const _AddSubjectCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: const DashedRRectPainter(
          color: Color(0xFFAEBDE2),
          radius: 14,
        ),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F8FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.add_rounded, color: Eps.blue, size: 18),
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
                        color: Eps.blue,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      'اختر عدة مواد وادفع مرة واحدة',
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
      ),
    );
  }
}

/// Dashed rounded border.
class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({
    required this.color,
    required this.radius,
    this.dash = 4,
    this.gap = 3,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.pending,
    required this.title,
    required this.note,
    required this.onTap,
  });

  final bool pending;
  final String title;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = pending ? const Color(0xFFA96C00) : Eps.red;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: pending ? const Color(0xFFFFF9E9) : const Color(0xFFFFF4F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: pending
                  ? const Color(0xFFF0D18F)
                  : const Color(0xFFEFC0C5),
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
                      title,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 7,
                        color: Eps.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveHero extends StatelessWidget {
  const _LiveHero({required this.session});

  final EpsLiveSession session;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final subject = learn.subjectById(session.subjectId);
    final teacher = learn.teacherById(session.teacherId);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172D72), Color(0xFF2E5CB5)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2B1E3A8A),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          Positioned(
            left: -12,
            bottom: -8,
            width: 150,
            height: 190,
            child: _TeacherVisual(
              initial: teacher == null ? 'م' : firstLetter(teacher.name),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 19, 18, 19),
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 0.64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EpsBadge(
                    session.state == LiveState.live
                        ? 'جلسة مباشرة'
                        : 'جلسة قادمة',
                    tone: EpsTone.orange,
                  ),
                  const SizedBox(height: 11),
                  Text(
                    subject?.name ?? session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    teacher == null ? session.title : 'مع ${teacher.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFD6E2FF),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: Color(0xFFE4EAFF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        liveWhen(session.startsAt),
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFFE4EAFF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.group_outlined,
                        size: 15,
                        color: Color(0xFFE4EAFF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${session.attendees} طالب',
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFFE4EAFF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => openLiveSession(context, session),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            size: 16,
                            color: Eps.blue,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            session.state == LiveState.live
                                ? 'انضم الآن'
                                : 'ذكّرني',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Eps.blue,
                            ),
                          ),
                        ],
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

String firstLetter(String name) {
  final parts = name
      .replaceAll(RegExp(r'^(د\.|أ\.)\s*'), '')
      .trim()
      .split(RegExp(r'\s+'));
  return parts.first.isEmpty ? 'م' : parts.first.characters.first;
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x18FFFFFF);
    for (var x = 9.0; x < size.width; x += 18) {
      for (var y = 9.0; y < size.height; y += 18) {
        canvas.drawCircle(Offset(x, y), 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) => false;
}

class _TeacherVisual extends StatelessWidget {
  const _TeacherVisual({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(left: -15, right: -5, top: 18, bottom: -20, child: _orbit()),
        Positioned(left: 20, right: 15, top: 45, bottom: 8, child: _orbit()),
        Positioned(
          left: 29,
          bottom: 0,
          child: Container(
            width: 92,
            height: 137,
            padding: const EdgeInsets.only(top: 17),
            alignment: Alignment.topCenter,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(46),
                bottom: Radius.circular(20),
              ),
              border: Border.all(color: const Color(0x33FFFFFF), width: 4),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.25, 0.26, 1],
                colors: [
                  Color(0xFFF2BD87),
                  Color(0xFFF2BD87),
                  Color(0xFFF7F9FF),
                  Color(0xFFF7F9FF),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66071A53),
                  blurRadius: 30,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF53351D),
                height: 1,
              ),
            ),
          ),
        ),
        Positioned(
          top: 30,
          left: 12,
          child: Transform.rotate(
            angle: -8 * pi / 180,
            child: const Text(
              'f(x)',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                fontSize: 16,
                color: Color(0xBBFFFFFF),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _orbit() => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0x30FFFFFF)),
    ),
  );
}

class _PagerDots extends StatelessWidget {
  const _PagerDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: i == index ? 19 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: i == index ? Eps.blue : const Color(0xFFCCD1DE),
                borderRadius: BorderRadius.circular(9),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.subject});

  final EpsSubject subject;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final teacher = learn.teacherById(subject.teacherId);
    final progress = learn.progressFor(subject.id);
    return FlatCard(
      onTap: () {
        learn.openSubject(subject.id);
        pushPage(context, CourseScreen(subjectId: subject.id));
      },
      child: Row(
        children: [
          SubjectMark(subject: subject),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacher?.name ?? '',
                  style: const TextStyle(fontSize: 9, color: Eps.muted),
                ),
                Text(
                  subject.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Eps.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: EpsProgress(value: progress / 100, height: 5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$progress%',
                      style: const TextStyle(
                        fontFamily: Eps.fontNum,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Eps.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Eps.blue,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyContinueCard extends StatelessWidget {
  const _EmptyContinueCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Eps.blueSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.add_rounded, color: Eps.blue, size: 24),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ابدأ بإضافة أول مادة',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Eps.ink,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 13),
                Text(
                  'اختر من المواد المتاحة حسب مستواك',
                  style: TextStyle(fontSize: 9, color: Eps.muted, height: 1.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Eps.ink, size: 24),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.quiz, required this.streak});

  final EpsQuiz quiz;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      onTap: () => pushPage(context, QuestionScreen(quizId: quiz.id)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      gradient: const LinearGradient(
        begin: Alignment(-1, -0.18),
        end: Alignment(1, 0.18),
        colors: [Color(0xFFFFFAF0), Color(0xFFFFF4D8)],
      ),
      border: const Color(0xFFFCE4AA),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x28E3A62C),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFFD78500),
              size: 25,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اختبار يومي سريع',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF916818),
                    height: 1.5,
                  ),
                ),
                Text(
                  '${quiz.questionsCount} أسئلة، ${quiz.xpReward} نقطة خبرة',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Eps.ink,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 7),
                Text.rich(
                  TextSpan(
                    text: 'حافظ على سلسلة ',
                    children: [
                      TextSpan(
                        text: '$streak أيام',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF916818),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Eps.ink, size: 22),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});

  final EpsAnnouncement item;

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      onTap: () => pushPage(context, const AnnouncementsPage()),
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: Eps.blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Eps.blue,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 11, color: Eps.ink),
                ),
                Text(
                  item.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: Eps.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  timeAgo(item.createdAt),
                  style: const TextStyle(fontSize: 8, color: Color(0xFFA4AABD)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// List of university announcements ("الكل").
class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    return EpsPage(
      title: 'إعلانات الجامعة',
      children: [
        for (final item in learn.announcements)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AnnouncementCard(item: item),
          ),
      ],
    );
  }
}
