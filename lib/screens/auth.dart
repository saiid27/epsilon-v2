part of '../main.dart';

/// Login / signup entry screen (Figma: login, signup).
class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.backendStatus, super.key});

  final BackendBootstrap backendStatus;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool registerMode = false;

  void toggleMode() => setState(() => registerMode = !registerMode);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Eps.bg,
      body: EpsGlowBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                    children: [
                      AuthHeader(
                        title: registerMode ? 'أنشئ حسابك' : 'مرحباً بعودتك',
                        subtitle: registerMode
                            ? 'خطوة واحدة تفصلك عن محتواك الجامعي'
                            : 'سجّل الدخول لمتابعة رحلتك التعليمية',
                        compact: registerMode,
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: registerMode
                            ? const RegisterCard(key: ValueKey('register'))
                            : const LoginCard(key: ValueKey('login')),
                      ),
                      const SizedBox(height: 16),
                      AuthSwitchLine(
                        question: registerMode
                            ? 'لديك حساب بالفعل؟'
                            : 'ليس لديك حساب؟',
                        action: registerMode ? 'تسجيل الدخول' : 'أنشئ حسابا',
                        onTap: toggleMode,
                      ),
                      const SizedBox(height: 18),
                      const AuthFreeCard(),
                      const SizedBox(height: 18),
                      const AuthFooterLinks(),
                      const SizedBox(height: 10),
                      const DeveloperCredit(),
                    ],
                  ),
                  if (registerMode)
                    PositionedDirectional(
                      top: 16,
                      end: 18,
                      child: EpsIconButton(
                        icon: Icons.arrow_forward_rounded,
                        tooltip: 'رجوع',
                        onTap: toggleMode,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    required this.title,
    required this.subtitle,
    this.compact = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EpsLogo(size: compact ? 76 : 108),
        SizedBox(height: compact ? 12 : 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: Eps.ink,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Eps.muted, height: 1.6),
        ),
      ],
    );
  }
}

class AuthSwitchLine extends StatelessWidget {
  const AuthSwitchLine({
    required this.question,
    required this.action,
    required this.onTap,
    super.key,
  });

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          question,
          style: const TextStyle(color: Eps.muted, fontSize: 13),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              action,
              style: const TextStyle(
                color: Eps.blue,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Phone input with fixed +222 country prefix (`.phone-field`).
class EpsPhoneField extends StatelessWidget {
  const EpsPhoneField({
    required this.controller,
    this.textInputAction,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 15, letterSpacing: 1),
        decoration: InputDecoration(
          hintText: 'XX XX XX XX',
          suffixIcon: Container(
            width: 70,
            margin: const EdgeInsetsDirectional.only(start: 10),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: BorderDirectional(start: BorderSide(color: Eps.line)),
            ),
            child: const Text(
              '+222',
              style: TextStyle(
                color: Eps.blue,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Password input with lock icon and visibility toggle.
class EpsPasswordField extends StatefulWidget {
  const EpsPasswordField({
    required this.controller,
    this.hint = 'أدخل كلمة المرور',
    this.textInputAction,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<EpsPasswordField> createState() => _EpsPasswordFieldState();
}

class _EpsPasswordFieldState extends State<EpsPasswordField> {
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: obscure,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
          onPressed: () => setState(() => obscure = !obscure),
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

class AuthErrorText extends StatelessWidget {
  const AuthErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Eps.redSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Eps.redInk, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Eps.redInk,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginCard extends StatefulWidget {
  const LoginCard({super.key});

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  String? error;
  bool submitting = false;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final store = StoreScope.of(context);
    setState(() => submitting = true);
    final ok = await store.login(phoneController.text, passwordController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      submitting = false;
      error = ok
          ? null
          : store.lastError?.replaceFirst('ApiException: ', '') ??
                'بيانات الدخول غير صحيحة.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EpsFieldLabel('رقم الهاتف'),
        EpsPhoneField(
          controller: phoneController,
          textInputAction: TextInputAction.next,
        ),
        EpsFieldLabel(
          'كلمة المرور',
          trailing: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
            ),
            child: const Text(
              'نسيت كلمة المرور؟',
              style: TextStyle(
                color: Eps.blue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        EpsPasswordField(
          controller: passwordController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
        ),
        if (error != null) AuthErrorText(error!),
        const SizedBox(height: 24),
        EpsPrimaryButton(
          label: 'تسجيل الدخول',
          loading: submitting,
          onPressed: submit,
        ),
      ],
    );
  }
}

/// Single-form signup (Figma: signup). Level/section is chosen on the next
/// page from the real courses list, exactly as before.
class RegisterCard extends StatefulWidget {
  const RegisterCard({super.key});

  @override
  State<RegisterCard> createState() => _RegisterCardState();
}

class _RegisterCardState extends State<RegisterCard> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String? validate(SchoolStore store) {
    if (nameController.text.trim().isEmpty) {
      return 'اكتب الاسم الكامل.';
    }
    if (phoneController.text.trim().isEmpty) {
      return 'اكتب رقم الهاتف.';
    }
    if (passwordController.text.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.';
    }
    if (confirmPasswordController.text != passwordController.text) {
      return 'تأكيد كلمة المرور غير مطابق.';
    }
    if (store.courses.isEmpty) {
      return 'لا توجد أقسام متاحة حاليا.';
    }
    return null;
  }

  void submit() {
    final store = StoreScope.of(context);
    final problem = validate(store);
    setState(() => error = problem);
    if (problem != null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentCourseSelectionPage(
          name: nameController.text.trim(),
          phone: phoneController.text.trim(),
          password: passwordController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EpsFieldLabel('الاسم الكامل'),
        TextField(
          controller: nameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'مثال: محمد الأمين',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const EpsFieldLabel('رقم الهاتف'),
        EpsPhoneField(
          controller: phoneController,
          textInputAction: TextInputAction.next,
        ),
        const EpsFieldLabel('كلمة المرور'),
        EpsPasswordField(
          controller: passwordController,
          hint: '6 أحرف على الأقل',
          textInputAction: TextInputAction.next,
        ),
        const EpsFieldLabel('تأكيد كلمة المرور'),
        EpsPasswordField(
          controller: confirmPasswordController,
          hint: 'أعد كتابة كلمة المرور',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
        ),
        if (error != null) AuthErrorText(error!),
        const SizedBox(height: 22),
        EpsPrimaryButton(
          label: 'متابعة لاختيار القسم',
          icon: Icons.arrow_forward_rounded,
          onPressed: submit,
        ),
      ],
    );
  }
}

/// "Try for free" card on auth screens (`.auth-free-card`). Opens the
/// existing guest area (free videos, archive, national results).
class AuthFreeCard extends StatelessWidget {
  const AuthFreeCard({super.key});

  @override
  Widget build(BuildContext context) {
    void open() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GuestPage()));

    const features = [
      (Icons.play_circle_outline_rounded, 'فيديوهات مجانية'),
      (Icons.folder_open_rounded, 'الأرشيف'),
      (Icons.emoji_events_outlined, 'نتائج الباك'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3F7FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7E2F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'جرّب مجاناً 🎁',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Eps.ink,
                      ),
                    ),
                    Text(
                      'تصفّح المحتوى المجاني دون اشتراك',
                      style: TextStyle(fontSize: 11.5, color: Eps.muted),
                    ),
                  ],
                ),
              ),
              EpsBadge('ضيف', tone: EpsTone.green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (icon, label) in features) ...[
                Expanded(
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Eps.line),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: Eps.blue, size: 22),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Eps.grayInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (label != features.last.$2) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
          EpsPrimaryButton(
            label: 'تصفّح المحتوى المجاني',
            icon: Icons.chevron_right_rounded,
            color: Eps.green,
            height: 48,
            onPressed: open,
          ),
        ],
      ),
    );
  }
}

class AuthFooterLinks extends StatelessWidget {
  const AuthFooterLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextButton.styleFrom(
      foregroundColor: Eps.blue,
      textStyle: const TextStyle(
        fontFamily: Eps.font,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      children: [
        TextButton(
          style: linkStyle,
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AboutPage())),
          child: const Text('من نحن'),
        ),
        TextButton(
          style: linkStyle,
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
          child: const Text('سياسة الخصوصية'),
        ),
        TextButton(
          style: linkStyle,
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ContactUsPage())),
          child: const Text('تواصل معنا'),
        ),
      ],
    );
  }
}
