part of '../main.dart';

/// Animated splash (Figma: splash, `.splash-screen`).
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
    final logoScale = CurvedAnimation(
      parent: intro,
      curve: Curves.elasticOut,
    ).drive(Tween(begin: 0.6, end: 1.0));
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.42, -1),
                    end: Alignment(0.42, 1),
                    colors: [Color(0xFFF9FCFF), Color(0xFFEAF3FF)],
                  ),
                ),
              ),
            ),
            Positioned(top: -155, right: -145, child: _ring(310)),
            Positioned(bottom: -120, left: -110, child: _ring(230)),
            AnimatedBuilder(
              animation: loop,
              builder: (context, _) {
                final t = sin(loop.value * 2 * pi);
                return Stack(
                  children: [
                    Positioned(
                      top: 120 + t * 11,
                      right: -55 - t * 12,
                      child: _blob(const Color(0xFF4D78E1), 155),
                    ),
                    Positioned(
                      bottom: 105 - t * 11,
                      left: -42 + t * 12,
                      child: _blob(const Color(0xFFF4CA3E), 125),
                    ),
                  ],
                );
              },
            ),
            SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 390,
                          height: 230,
                          child: AnimatedBuilder(
                            animation: loop,
                            builder: (context, _) {
                              final t = loop.value * 2 * pi;
                              return Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  FadeTransition(
                                    opacity: intro,
                                    child: ScaleTransition(
                                      scale: logoScale,
                                      child: const EpsLogo(
                                        size: 210,
                                        shadow: BoxShadow(
                                          color: Color(0x322F5BD3),
                                          blurRadius: 40,
                                          offset: Offset(0, 16),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 42,
                                    top: 13 + sin(t) * 6,
                                    child: Transform.rotate(
                                      angle: sin(t) * 0.087,
                                      child: const _FloatTile(
                                        icon: Icons.menu_book_outlined,
                                        color: Eps.blue,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 39,
                                    top: 62 - sin(t * 1.1) * 6.5,
                                    child: Transform.rotate(
                                      angle: 0.03 + sin(t * 1.1) * 0.11,
                                      child: const _FloatTile(
                                        icon: Icons.edit_outlined,
                                        color: Color(0xFFB57A00),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 62,
                                    top: -52,
                                    child: Opacity(
                                      opacity: 0.75 + 0.25 * sin(t * 2),
                                      child: Transform.scale(
                                        scale: 1.025 + 0.225 * sin(t * 2),
                                        child: const _FloatTile(
                                          icon: Icons.auto_awesome_outlined,
                                          color: Eps.blue,
                                          size: 29,
                                          iconSize: 19,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Epsilon Education',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: Eps.blue,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'أبسيلون للتعليم',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Eps.blue,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'رفيقك نحو التميز الجامعي',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF75839A),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const EpsLogoLoader(),
                      ],
                    ),
                  ),
                  if (widget.onSkip != null)
                    Positioned(
                      top: 18,
                      left: 18,
                      child: GestureDetector(
                        onTap: widget.onSkip,
                        child: Container(
                          width: 42,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0x9EFFFFFF),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Text(
                            'تخطي',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Eps.blue,
                            ),
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
    );
  }

  static Widget _ring(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0x243A7DCC)),
    ),
  );

  static Widget _blob(Color color, double size) => ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
    child: Opacity(
      opacity: 0.34,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    ),
  );
}

class _FloatTile extends StatelessWidget {
  const _FloatTile({
    required this.icon,
    required this.color,
    this.size = 42,
    this.iconSize = 24,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xB5FFFFFF),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17223B7B),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

/// Logo inside a white circle with a spinning two-colour ring
/// (`.logo-loader`).
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
    return SizedBox(
      height: 130,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                RotationTransition(
                  turns: spin,
                  child: const CustomPaint(
                    size: Size(68, 68),
                    painter: _ArcPainter(),
                  ),
                ),
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x222F5BD3),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const EpsLogo(size: 36, shadow: null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.label,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 8, color: Eps.muted),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // border-top (blue) and border-right (yellow) of a circle.
    canvas.drawArc(rect, -pi * 3 / 4, pi / 2, false, p(Eps.blue));
    canvas.drawArc(rect, -pi / 4, pi / 2, false, p(const Color(0xFFF2C532)));
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => false;
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.text,
    required this.miniA,
    required this.miniB,
    required this.color,
    required this.bgFrom,
    required this.bgTo,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String text;
  final IconData miniA;
  final IconData miniB;
  final Color color;
  final Color bgFrom;
  final Color bgTo;
}

const _onboardingSlides = [
  _OnboardingSlide(
    icon: Icons.videocam_outlined,
    eyebrow: 'فصول بلا حدود',
    title: 'جلسات مباشرة\nمع أفضل الأساتذة',
    text: 'تابع الشرح لحظة بلحظة، اطرح أسئلتك وتفاعل مع زملائك من أي مكان.',
    miniA: Icons.group_outlined,
    miniB: Icons.mic_none_rounded,
    color: Eps.blue,
    bgFrom: Color(0xFFE9F3FF),
    bgTo: Color(0xFFF7FBFF),
  ),
  _OnboardingSlide(
    icon: Icons.sports_esports_outlined,
    eyebrow: 'تعلم باللعب',
    title: 'اختبارات QCM\nتجعل التعلم ممتعاً',
    text: 'اكسب النقاط، حافظ على سلسلتك وتنافس أسبوعياً على لوحة المتصدرين.',
    miniA: Icons.emoji_events_outlined,
    miniB: Icons.bolt_outlined,
    color: Color(0xFFC78104),
    bgFrom: Color(0xFFFFF4C9),
    bgTo: Color(0xFFFFFDF3),
  ),
  _OnboardingSlide(
    icon: Icons.credit_card_outlined,
    eyebrow: 'بسيط وآمن',
    title: 'اشترك وادفع\nبالطريقة التي تناسبك',
    text: 'خطط مرنة ودفع محلي عبر Bankily ومصرفي والسداد مع متابعة فورية.',
    miniA: Icons.receipt_long_outlined,
    miniB: Icons.check_rounded,
    color: Color(0xFF168467),
    bgFrom: Color(0xFFE3F8F0),
    bgTo: Color(0xFFF7FFFC),
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
  int slide = 0;

  void next() {
    if (slide == _onboardingSlides.length - 1) {
      widget.onFinish();
      return;
    }
    setState(() => slide += 1);
  }

  @override
  Widget build(BuildContext context) {
    final item = _onboardingSlides[slide];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v > 200) {
              next();
            } else if (v < -200 && slide > 0) {
              setState(() => slide -= 1);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 67,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        key: const ValueKey('onboarding-skip'),
                        onTap: widget.onFinish,
                        child: const Text(
                          'تخطي',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF818B9E),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const EpsLogo(
                        size: 43,
                        shadow: BoxShadow(
                          color: Color(0x1E173B8A),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: _OnboardingArt(
                  key: ValueKey(slide),
                  slide: item,
                  index: slide,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(25, 24, 25, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.eyebrow,
                        style: const TextStyle(
                          color: Eps.blue,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          color: Eps.ink,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(
                          item.text,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Eps.muted,
                            height: 1.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          for (var i = 0; i < _onboardingSlides.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsetsDirectional.only(end: 5),
                              width: i == slide ? 19 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: i == slide
                                    ? Eps.blue
                                    : const Color(0xFFCCD1DE),
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          const Spacer(),
                          GestureDetector(
                            key: const ValueKey('onboarding-next'),
                            onTap: next,
                            child: Container(
                              width: 49,
                              height: 49,
                              decoration: BoxDecoration(
                                color: Eps.blue,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x3B2F5BD3),
                                    blurRadius: 22,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _OnboardingArt extends StatelessWidget {
  const _OnboardingArt({
    required this.slide,
    required this.index,
    super.key,
  });

  final _OnboardingSlide slide;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = slide.color;
    return Container(
      height: 395,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: const Alignment(-0.57, -1),
          end: const Alignment(0.57, 1),
          colors: [slide.bgFrom, slide.bgTo],
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final d in [310.0, 215.0])
              Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.withValues(alpha: 0.15)),
                ),
              ),
            Transform.rotate(
              angle: -3 * pi / 180,
              child: Container(
                width: 170,
                height: 196,
                decoration: BoxDecoration(
                  color: const Color(0xDDFFFFFF),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: Colors.white),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24174B91),
                      blurRadius: 45,
                      offset: Offset(0, 24),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(slide.icon, size: 58, color: c),
                    const SizedBox(height: 21),
                    Container(
                      width: 35,
                      height: 35,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontFamily: Eps.fontNum,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 74,
              right: 42,
              child: _MiniCard(icon: slide.miniA, color: c, angle: 8),
            ),
            Positioned(
              left: 38,
              bottom: 70,
              child: _MiniCard(icon: slide.miniB, color: c, angle: -8),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.color,
    required this.angle,
  });

  final IconData icon;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle * pi / 180,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2221446E),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 27),
      ),
    );
  }
}
