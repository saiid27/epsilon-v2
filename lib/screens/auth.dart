part of '../main.dart';

// Exact values come from the Figma Make design (`.auth-*` rules).
const _authFieldBorder = Color(0xFFDFE4ED);
const _authIconColor = Color(0xFF8A94A6);
const _placeholder = Color(0xFFA9A9A9);

/// Login / signup entry screen (Figma: login, signup).
class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.backendStatus, super.key});

  final BackendBootstrap backendStatus;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool registerMode = false;

  void setMode(bool register) => setState(() => registerMode = register);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 57),
                  children: [
                    if (registerMode)
                      const AuthHeader(
                        title: 'أنشئ حسابك',
                        subtitle: 'خطوة واحدة تفصلك عن محتواك الجامعي',
                        compact: true,
                      )
                    else
                      const AuthHeader(
                        title: 'مرحباً بعودتك',
                        subtitle: 'سجّل الدخول لمتابعة رحلتك التعليمية',
                      ),
                    if (registerMode)
                      const RegisterCard(key: ValueKey('register'))
                    else
                      const LoginCard(key: ValueKey('login')),
                    const SizedBox(height: 17),
                    AuthSwitchLine(
                      question: registerMode
                          ? 'لديك حساب بالفعل؟'
                          : 'ليس لديك حساب؟',
                      action: registerMode ? 'تسجيل الدخول' : 'أنشئ حساباً',
                      onTap: () => setMode(!registerMode),
                    ),
                    SizedBox(height: registerMode ? 11 : 17),
                    AuthFreeCard(onCreate: () => setMode(true)),
                  ],
                ),
                if (registerMode)
                  Positioned(
                    top: 17,
                    left: 18,
                    child: AuthBackButton(onTap: () => setMode(false)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 38x38 back button on auth screens (`.auth-back`), always at the left.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: EpsIconButton(
        icon: Icons.arrow_back_rounded,
        tooltip: 'رجوع',
        size: 38,
        radius: 12,
        iconSize: 20,
        onTap: onTap,
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
    return Padding(
      padding: EdgeInsets.only(
        top: compact ? 10 : 16,
        bottom: compact ? 20 : 27,
      ),
      child: Column(
        children: [
          EpsLogo(
            size: compact ? 75 : 108,
            shadow: compact
                ? const BoxShadow(
                    color: Color(0x24173B8A),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  )
                : const BoxShadow(
                    color: Color(0x22173B8A),
                    blurRadius: 22,
                    offset: Offset(0, 8),
                  ),
          ),
          SizedBox(height: compact ? 8 : 25),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 19 : 23,
              fontWeight: FontWeight.w400,
              color: Eps.ink,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: Eps.muted, height: 1.8),
          ),
        ],
      ),
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
          '$question ',
          style: const TextStyle(color: Eps.muted, fontSize: 9, height: 1.5),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              color: Eps.blue,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Field label (`.auth-form > label`): 9px bold with 3px side margin.
class AuthLabel extends StatelessWidget {
  const AuthLabel(this.text, {this.top = 0, this.trailing, super.key});

  final String text;
  final double top;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(3, top, 3, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Eps.ink,
                height: 1.5,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Bordered input box (`.auth-field`) with optional error state.
class AuthField extends StatefulWidget {
  const AuthField({
    required this.controller,
    this.hint,
    this.leading,
    this.trailing,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.inputFormatters,
    this.error,
    this.height = 50,
    this.ltr = false,
    this.textStyle,
    super.key,
  });

  final TextEditingController controller;
  final String? hint;
  final Widget? leading;
  final Widget? trailing;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final String? error;
  final double height;
  final bool ltr;
  final TextStyle? textStyle;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    final focused = focus.hasFocus;
    final iconColor = focused && !hasError ? Eps.blue : _authIconColor;
    final style =
        widget.textStyle ??
        const TextStyle(fontSize: 10, color: Eps.ink, height: 1.5);
    final field = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError
              ? Eps.red
              : focused
              ? Eps.blue2
              : _authFieldBorder,
        ),
        boxShadow: hasError
            ? const [BoxShadow(color: Color(0xFFFFF0F1), spreadRadius: 3)]
            : focused
            ? const [BoxShadow(color: Eps.blueSoft, spreadRadius: 3)]
            : null,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: iconColor, size: 18),
        child: Row(
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: 9),
            ],
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: focus,
                obscureText: widget.obscure,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                onSubmitted: widget.onSubmitted,
                inputFormatters: widget.inputFormatters,
                textAlign: widget.ltr ? TextAlign.left : TextAlign.start,
                style: style,
                cursorColor: Eps.blue,
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: style.copyWith(color: _placeholder),
                ),
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 9),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
    if (!hasError) {
      return field;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        Padding(
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
          child: Text(
            widget.error!,
            style: const TextStyle(fontSize: 7, color: Eps.red, height: 1.5),
          ),
        ),
      ],
    );
  }
}

/// Phone field with `+222` on the right (`.phone-field`).
class EpsPhoneField extends StatelessWidget {
  const EpsPhoneField({
    required this.controller,
    this.textInputAction,
    this.onSubmitted,
    this.errorText,
    this.height = 50,
    super.key,
  });

  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AuthField(
        controller: controller,
        hint: 'XX XX XX XX',
        height: height,
        ltr: true,
        error: errorText,
        keyboardType: TextInputType.phone,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(8),
        ],
        textStyle: const TextStyle(
          fontFamily: Eps.fontNum,
          fontSize: 10,
          letterSpacing: 1,
          color: Eps.ink,
          height: 1.5,
        ),
        trailing: Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Eps.line)),
          ),
          child: const Text(
            '+222',
            style: TextStyle(
              fontFamily: Eps.fontNum,
              color: Eps.blue,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

/// Password field with lock icon and visibility toggle (`PasswordInput`).
class EpsPasswordField extends StatefulWidget {
  const EpsPasswordField({
    required this.controller,
    this.hint = 'أدخل كلمة المرور',
    this.textInputAction,
    this.onSubmitted,
    this.errorText,
    this.height = 50,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final double height;

  @override
  State<EpsPasswordField> createState() => _EpsPasswordFieldState();
}

class _EpsPasswordFieldState extends State<EpsPasswordField> {
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    return AuthField(
      controller: widget.controller,
      hint: widget.hint,
      height: widget.height,
      obscure: obscure,
      error: widget.errorText,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      leading: const Icon(Icons.lock_outline_rounded),
      trailing: GestureDetector(
        onTap: () => setState(() => obscure = !obscure),
        child: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: const Color(0xFF8C95A7),
          size: 18,
          semanticLabel: 'إظهار أو إخفاء كلمة المرور',
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Eps.red, fontSize: 9, height: 1.5),
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
  bool submitted = false;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool get phoneInvalid => phoneController.text.trim().length != 8;
  bool get passwordInvalid => passwordController.text.length < 6;

  Future<void> submit() async {
    setState(() => submitted = true);
    if (phoneInvalid || passwordInvalid) {
      return;
    }
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
        Stack(
          clipBehavior: Clip.none,
          children: [
            const AuthLabel('رقم الهاتف'),
            Positioned(
              left: -3,
              top: -37,
              child: LoginMascot(shy: passwordController.text.isNotEmpty),
            ),
          ],
        ),
        EpsPhoneField(
          controller: phoneController,
          textInputAction: TextInputAction.next,
          errorText: submitted && phoneInvalid
              ? 'أدخل رقم هاتف صحيحاً من 8 أرقام'
              : null,
        ),
        AuthLabel(
          'كلمة المرور',
          top: 14,
          trailing: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
            ),
            child: const Text(
              'نسيت كلمة المرور؟',
              style: TextStyle(
                color: Eps.blue,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ),
        EpsPasswordField(
          controller: passwordController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          errorText: submitted && passwordInvalid
              ? 'كلمة المرور مطلوبة (6 أحرف على الأقل)'
              : null,
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

/// Character above the login form that covers its eyes while the password is
/// typed (`.login-mascot`, 58x43).
class LoginMascot extends StatelessWidget {
  const LoginMascot({required this.shy, super.key});

  final bool shy;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 250);
    Widget eye() => AnimatedOpacity(
      duration: duration,
      opacity: shy ? 0 : 1,
      child: Container(
        width: 5,
        height: 6,
        decoration: const BoxDecoration(
          color: Color(0xFF283044),
          borderRadius: BorderRadius.all(Radius.elliptical(2.5, 3)),
        ),
      ),
    );
    Widget hand(double turn, double dx) => AnimatedOpacity(
      duration: duration,
      opacity: shy ? 1 : 0,
      child: AnimatedContainer(
        duration: duration,
        transform: shy
            ? (Matrix4.translationValues(dx, 0, 0)..rotateZ(turn))
            : Matrix4.identity(),
        width: 18,
        height: 9,
        decoration: BoxDecoration(
          color: const Color(0xFFF7CF7D),
          borderRadius: BorderRadius.circular(9),
        ),
      ),
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 58,
        height: 43,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 0,
              top: -2,
              child: Transform.rotate(
                angle: 0.384,
                child: Container(
                  width: 17,
                  height: 21,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5AA3E),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                      bottom: Radius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 6,
              bottom: 0,
              child: Container(
                width: 46,
                height: 40,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Color(0xFFDDA340),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.elliptical(22, 19),
                    bottom: Radius.elliptical(21, 18),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      bottom: 5,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0BD56),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.elliptical(22, 19),
                            bottom: Radius.elliptical(21, 16),
                          ),
                        ),
                      ),
                    ),
                    Positioned(left: 11, top: 14, child: eye()),
                    Positioned(right: 11, top: 14, child: eye()),
                    Positioned(
                      left: 19,
                      bottom: 10,
                      child: Container(
                        width: 8,
                        height: 4,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFF8E5D28),
                              width: 2,
                            ),
                          ),
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(4, 2),
                          ),
                        ),
                      ),
                    ),
                    Positioned(left: -2, top: 12, child: hand(0.227, 8)),
                    Positioned(right: -2, top: 12, child: hand(-0.227, -8)),
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

/// Single-form signup (Figma: signup). After this form the student picks the
/// section on the existing course selection page.
class RegisterCard extends StatefulWidget {
  const RegisterCard({super.key});

  @override
  State<RegisterCard> createState() => _RegisterCardState();
}

class _RegisterCardState extends State<RegisterCard> {
  static const levels = ['Bac', 'L1', 'L2', 'L3', 'M1', 'M2'];

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  String level = 'L1';
  bool submitted = false;
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool get nameInvalid => nameController.text.trim().isEmpty;
  bool get phoneInvalid => phoneController.text.trim().length != 8;
  bool get passwordInvalid => passwordController.text.length < 6;
  bool get confirmInvalid =>
      confirmPasswordController.text != passwordController.text;

  bool sending = false;

  Future<void> submit() async {
    final store = StoreScope.of(context);
    setState(() {
      submitted = true;
      error = null;
    });
    if (nameInvalid || phoneInvalid || passwordInvalid || confirmInvalid) {
      return;
    }
    setState(() => sending = true);
    try {
      await store.registerFreeStudent(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        password: passwordController.text,
        level: level,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SignupOtpScreen(
            phone: phoneController.text.trim(),
            password: passwordController.text,
          ),
        ),
      );
    } on Object catch (e) {
      setState(() => error = friendlyApiError(e));
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthLabel('الاسم الكامل'),
        AuthField(
          controller: nameController,
          height: 44,
          hint: 'مثال: محمد الأمين',
          textInputAction: TextInputAction.next,
          leading: const Icon(Icons.person_outline_rounded),
          error: submitted && nameInvalid ? 'الاسم الكامل مطلوب' : null,
        ),
        const AuthLabel('رقم الهاتف', top: 7),
        EpsPhoneField(
          controller: phoneController,
          height: 44,
          textInputAction: TextInputAction.next,
          errorText: submitted && phoneInvalid ? 'رقم الهاتف غير مكتمل' : null,
        ),
        const AuthLabel('المستوى الدراسي', top: 7),
        Row(
          children: [
            for (final item in levels) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => level = item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: level == item ? Eps.blue : Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: level == item ? Eps.blue : _authFieldBorder,
                      ),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontFamily: Eps.fontNum,
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        color: level == item
                            ? Colors.white
                            : const Color(0xFF70798B),
                      ),
                    ),
                  ),
                ),
              ),
              if (item != levels.last) const SizedBox(width: 4),
            ],
          ],
        ),
        const AuthLabel('كلمة المرور', top: 11),
        EpsPasswordField(
          controller: passwordController,
          height: 44,
          hint: '6 أحرف على الأقل',
          textInputAction: TextInputAction.next,
          errorText: submitted && passwordInvalid ? 'كلمة المرور قصيرة' : null,
        ),
        const AuthLabel('تأكيد كلمة المرور', top: 7),
        EpsPasswordField(
          controller: confirmPasswordController,
          height: 44,
          hint: 'أعد كتابة كلمة المرور',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          errorText: submitted && confirmInvalid
              ? 'كلمتا المرور غير متطابقتين'
              : null,
        ),
        if (error != null) AuthErrorText(error!),
        EpsPrimaryButton(
          label: 'إنشاء الحساب',
          loading: sending,
          onPressed: submit,
        ),
      ],
    );
  }
}

/// "Try for free" card on auth screens (`.auth-free-card`).
class AuthFreeCard extends StatelessWidget {
  const AuthFreeCard({required this.onCreate, super.key});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.sensors_rounded, 'بث مباشر', true),
      (Icons.description_outlined, 'ملفات PDF', false),
      (Icons.receipt_long_outlined, 'تمارين مع الحلول', false),
      (Icons.play_arrow_outlined, 'شروحات', false),
      (Icons.emoji_events_outlined, 'المسابقة', false),
    ];

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F5FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFCBD8F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C203C7D),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
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
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Eps.ink,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      'ابدأ التعلم الآن دون اشتراك',
                      style: TextStyle(
                        fontSize: 7,
                        color: Eps.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              EpsBadge('ضيف', tone: EpsTone.green),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (icon, label, live) in features) ...[
                Expanded(
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFE1E6F1)),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: Eps.blue, size: 16),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 6,
                                  height: 1.35,
                                  color: Color(0xFF5D677A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (live)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Eps.red,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  fontFamily: Eps.fontNum,
                                  color: Colors.white,
                                  fontSize: 4,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (label != features.last.$2) const SizedBox(width: 5),
              ],
            ],
          ),
          const SizedBox(height: 9),
          EpsPrimaryButton(
            label: 'أنشئ حساباً مجانياً',
            icon: Icons.chevron_right_rounded,
            color: Eps.green,
            height: 39,
            radius: 11,
            fontSize: 9,
            onPressed: onCreate,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'احفظ تقدمك وابدأ بالخطة المجانية تلقائياً',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 6,
                color: Color(0xFF71809B),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phone verification after signup (Figma: otp).
class SignupOtpScreen extends StatefulWidget {
  const SignupOtpScreen({
    required this.phone,
    required this.password,
    super.key,
  });

  final String phone;
  final String password;

  @override
  State<SignupOtpScreen> createState() => _SignupOtpScreenState();
}

class _SignupOtpScreenState extends State<SignupOtpScreen> {
  static const codeLength = 6;
  final code = TextEditingController();
  final focus = FocusNode();
  int seconds = 60;
  Timer? timer;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    code.addListener(() => setState(() {}));
    startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  void startTimer() {
    timer?.cancel();
    seconds = 60;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || seconds <= 1) {
        t.cancel();
        if (mounted) {
          setState(() => seconds = 0);
        }
        return;
      }
      setState(() => seconds--);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    code.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    if (code.text.length != codeLength) {
      setState(() => error = 'أدخل رمز التحقق المكون من $codeLength أرقام.');
      return;
    }
    final store = StoreScope.of(context);
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final ok = await store.verifySignupAndLogin(
        phone: widget.phone,
        code: code.text,
        password: widget.password,
      );
      if (!mounted) {
        return;
      }
      if (ok) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        setState(() => error = store.lastError ?? 'تعذر تسجيل الدخول.');
      }
    } on Object catch (e) {
      setState(() => error = 'رمز التحقق غير صحيح. ${friendlyApiError(e)}');
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(22, 92, 22, 32),
              children: [
                Center(
                  child: Container(
                    width: 67,
                    height: 67,
                    decoration: BoxDecoration(
                      color: Eps.blueSoft,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFFF4F8FF), spreadRadius: 10),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Eps.blue,
                      size: 29,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'تحقق من رقمك',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 23, color: Eps.ink, height: 1.5),
                ),
                const SizedBox(height: 3),
                const Text(
                  'أرسلنا رمزاً من $codeLength أرقام إلى',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: Eps.muted, height: 1.8),
                ),
                Text(
                  '+222 ${widget.phone}',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Eps.muted,
                  ),
                ),
                const SizedBox(height: 35),
                GestureDetector(
                  onTap: () => focus.requestFocus(),
                  child: Stack(
                    children: [
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < codeLength; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Container(
                                width: 47,
                                height: 60,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: hasError
                                      ? const Color(0xFFFFF5F6)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    width: 1.5,
                                    color: hasError
                                        ? Eps.red
                                        : i == code.text.length &&
                                              focus.hasFocus
                                        ? Eps.blue
                                        : const Color(0xFFDCE2EB),
                                  ),
                                ),
                                child: Text(
                                  i < code.text.length ? code.text[i] : '',
                                  style: const TextStyle(
                                    fontFamily: Eps.fontNum,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Eps.blue,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            controller: code,
                            focusNode: focus,
                            keyboardType: TextInputType.number,
                            maxLength: codeLength,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onSubmitted: (_) => verify(),
                            decoration: const InputDecoration(counterText: ''),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (error != null) AuthErrorText(error!),
                const SizedBox(height: 26),
                EpsPrimaryButton(
                  label: 'تحقق من الرمز',
                  loading: sending,
                  onPressed: verify,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'لم يصلك الرمز؟ ',
                      style: TextStyle(fontSize: 9, color: Eps.muted),
                    ),
                    if (seconds > 0)
                      Text(
                        'إعادة الإرسال خلال 00:${seconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF8992A3),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () async {
                          await StoreScope.of(
                            context,
                          ).resendSignupCode(widget.phone);
                          startTimer();
                        },
                        child: const Text(
                          'إعادة الإرسال الآن',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Eps.blue,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 17,
              left: 18,
              child: AuthBackButton(
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
