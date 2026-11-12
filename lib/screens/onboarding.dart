part of '../main.dart';

/// Animated splash (Figma: splash).
class StartupSplashScreen extends StatefulWidget {
  const StartupSplashScreen({this.onSkip, super.key});

  final VoidCallback? onSkip;

  @override
  State<StartupSplashScreen> createState() => _StartupSplashScreenState();
}

class _StartupSplashScreenState extends State<StartupSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  late final AnimationController loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    intro.dispose();
    loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoScale = CurvedAnimation(parent: intro, curve: Curves.elasticOut);
    return Scaffold(
      backgroundColor: Eps.bg,
      body: EpsGlowBackground(
        child: SafeArea(
          child: Stack(
            children: [
              if (widget.onSkip != null)
                PositionedDirectional(
                  top: 12,
                  end: 16,
                  child: TextButton(
                    onPressed: widget.onSkip,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.8),
                      foregroundColor: Eps.blue,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('تخطي'),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 300,
                      height: 260,
                      child: AnimatedBuilder(
                        animation: loop,
                        builder: (context, _) {
                          final t = loop.value * 2 * pi;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              ScaleTransition(
                                scale: logoScale,
                                child: const EpsLogo(size: 210),
                              ),
                              Positioned(
                                left: 0,
                                top: 50 + sin(t) * 6,
                                child: Transform.rotate(
                                  angle: sin(t) * 0.09,
                                  child: const _FloatTile(
                                    icon: Icons.menu_book_rounded,
                                    color: Eps.blue,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 110 - sin(t + 1) * 7,
                                child: Transform.rotate(
                                  angle: cos(t) * 0.1,
                                  child: const _FloatTile(
                                    icon: Icons.edit_outlined,
                                    color: Eps.orangeInk,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Opacity(
                                  opacity: 0.6 + 0.4 * sin(t * 2).abs(),
                                  child: Transform.scale(
                                    scale: 0.85 + 0.25 * sin(t * 2).abs(),
                                    child: const _FloatTile(
                                      icon: Icons.auto_awesome_outlined,
                                      color: Eps.blue,
                                      size: 38,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    FadeTransition(
                      opacity: intro,
                      child: const Column(
                        children: [
                          Text(
                            'Epsilon Education',
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              color: Eps.blue,
                            ),
                          ),
                          Text(
                            'أبسيلون للتعليم',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Eps.blue,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'رفيقك نحو التميز الجامعي',
                            style: TextStyle(fontSize: 13.5, color: Eps.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const EpsLogoLoader(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatTile extends StatelessWidget {
  const _FloatTile({required this.icon, required this.color, this.size = 42});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A1E3A8A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

/// Small logo with rotating two-tone arc (`LogoLoader`).
class EpsLogoLoader extends StatefulWidget {
  const EpsLogoLoader({this.label = 'جار التحميل...', super.key});

  final String label;

  @override
  State<EpsLogoLoader> createState() => _EpsLogoLoaderState();
}

class _EpsLogoLoaderState extends State<EpsLogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: spin,
                child: const CustomPaint(
                  size: Size(50, 50),
                  painter: _ArcPainter(),
                ),
              ),
              const EpsLogo(size: 36, ring: false),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.label,
          style: const TextStyle(fontSize: 11, color: Eps.muted),
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(2), -pi / 2, pi * 0.8, false, p(Eps.orange));
    canvas.drawArc(rect.deflate(2), pi / 2, pi * 0.8, false, p(Eps.blue));
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => false;
}

class _OnboardingSlide {
  const _OnboardingSlide(
    this.icon,
    this.eyebrow,
    this.title,
    this.text,
    this.miniA,
    this.miniB,
  );

  final IconData icon;
  final String eyebrow;
  final String title;
  final String text;
  final IconData miniA;
  final IconData miniB;
}

const _onboardingSlides = [
  _OnboardingSlide(
    Icons.videocam_outlined,
    'فصول بلا حدود',
    'دروس وفيديوهات\nمع أفضل الأساتذة',
    'تابع الشرح في أي وقت ومن أي مكان، وراجع الدروس بقدر ما تحتاج.',
    Icons.groups_outlined,
    Icons.mic_none_rounded,
  ),
  _OnboardingSlide(
    Icons.sports_esports_outlined,
    'تعلم باللعب',
    'اختبارات QCM\nتجعل التعلم ممتعاً',
    'اكسب النقاط، حافظ على سلسلتك وتنافس أسبوعياً على لوحة المتصدرين.',
    Icons.emoji_events_outlined,
    Icons.bolt_rounded,
  ),
  _OnboardingSlide(
    Icons.credit_card_rounded,
    'بسيط وآمن',
    'اشترك وادفع\nبالطريقة التي تناسبك',
    'دفع محلي عبر Bankily ومصرفي والسداد مع متابعة فورية لطلبك.',
    Icons.receipt_long_outlined,
    Icons.check_rounded,
  ),
];

/// Three-slide onboarding (Figma: onboarding).
class EpsOnboarding extends StatefulWidget {
  const EpsOnboarding({required this.onFinish, super.key});

  final VoidCallback onFinish;

  @override
  State<EpsOnboarding> createState() => _EpsOnboardingState();
}

class _EpsOnboardingState extends State<EpsOnboarding> {
  final controller = PageController();
  int slide = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void next() {
    if (slide == _onboardingSlides.length - 1) {
      widget.onFinish();
      return;
    }
    controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Row(
                  children: [
                    const EpsLogo(size: 44, ring: true),
                    const Spacer(),
                    TextButton(
                      key: const ValueKey('onboarding-skip'),
                      onPressed: widget.onFinish,
                      style: TextButton.styleFrom(foregroundColor: Eps.muted),
                      child: const Text('تخطي'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: controller,
                  itemCount: _onboardingSlides.length,
                  onPageChanged: (value) => setState(() => slide = value),
                  itemBuilder: (context, index) =>
                      _OnboardingPage(slide: _onboardingSlides[index]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 22, top: 8),
                child: Row(
                  children: [
                    for (var i = 0; i < _onboardingSlides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsetsDirectional.only(end: 5),
                        width: i == slide ? 19 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == slide
                              ? Eps.blue
                              : const Color(0xFFCDD3E0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    const Spacer(),
                    Material(
                      color: Eps.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0x552F5BD3),
                      child: InkWell(
                        key: const ValueKey('onboarding-next'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: next,
                        child: const SizedBox(
                          width: 50,
                          height: 50,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final artHeight = (constraints.maxHeight * 0.62).clamp(220.0, 400.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: artHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE6EEFF), Color(0xFFF3F6FD)],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (final d in [artHeight * 0.8, artHeight * 0.55])
                    Container(
                      width: d,
                      height: d,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD3DDF2)),
                      ),
                    ),
                  Transform.rotate(
                    angle: -0.06,
                    child: Container(
                      width: artHeight * 0.44,
                      height: artHeight * 0.48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F1E3A8A),
                            blurRadius: 30,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Icon(slide.icon, size: 58, color: Eps.blue),
                    ),
                  ),
                  PositionedDirectional(
                    top: artHeight * 0.18,
                    start: 28,
                    child: _MiniCard(icon: slide.miniA),
                  ),
                  PositionedDirectional(
                    bottom: artHeight * 0.2,
                    end: 36,
                    child: _MiniCard(icon: slide.miniB),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              slide.eyebrow,
              style: const TextStyle(
                color: Eps.blue,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              slide.title,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: Eps.ink,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              slide.text,
              style: const TextStyle(
                fontSize: 13.5,
                color: Eps.muted,
                height: 1.6,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.08,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A1E3A8A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Eps.blue, size: 27),
      ),
    );
  }
}
