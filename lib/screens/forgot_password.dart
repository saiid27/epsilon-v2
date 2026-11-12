part of '../main.dart';

/// Password recovery in three steps (Figma: forgot, forgotOtp, newPassword).
/// Uses the same store calls as before: sendPasswordResetEmail and
/// resetPasswordWithCode.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const codeLength = 6;
  static const resendSeconds = 60;

  final phoneController = TextEditingController();
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final codeFocus = FocusNode();
  int step = 0;
  String? message;
  bool success = false;
  bool sending = false;
  int resendLeft = 0;
  Timer? resendTimer;

  @override
  void initState() {
    super.initState();
    codeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    phoneController.dispose();
    codeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    codeFocus.dispose();
    super.dispose();
  }

  void startResendTimer() {
    resendTimer?.cancel();
    setState(() => resendLeft = resendSeconds);
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || resendLeft <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => resendLeft = 0);
        }
        return;
      }
      setState(() => resendLeft -= 1);
    });
  }

  void fail(String text) => setState(() {
    success = false;
    message = text;
  });

  Future<void> sendCode(SchoolStore store) async {
    final phone = phoneController.text.trim();
    if (phone.isEmpty) {
      fail('أدخل رقم الهاتف أولا.');
      return;
    }
    setState(() {
      sending = true;
      message = null;
    });
    try {
      await store.sendPasswordResetEmail(phone);
      if (!mounted) {
        return;
      }
      setState(() {
        step = 1;
        success = true;
        message = null;
      });
      startResendTimer();
      codeFocus.requestFocus();
    } on Object catch (error) {
      if (mounted) {
        fail('تعذر إرسال الرمز: ${friendlyApiError(error)}');
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  void confirmCode() {
    if (codeController.text.trim().length != codeLength) {
      fail('أدخل رمز التحقق المكون من $codeLength أرقام.');
      return;
    }
    setState(() {
      step = 2;
      message = null;
    });
  }

  Future<void> resetPassword(SchoolStore store) async {
    final password = passwordController.text;
    if (password.length < 6) {
      fail('كلمة المرور يجب أن تكون 6 أحرف أو أرقام على الأقل.');
      return;
    }
    if (password != confirmPasswordController.text) {
      fail('تأكيد كلمة المرور غير مطابق.');
      return;
    }
    setState(() {
      sending = true;
      message = null;
    });
    try {
      await store.resetPasswordWithCode(
        phone: phoneController.text.trim(),
        code: codeController.text.trim(),
        newPassword: password,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        success = true;
        message = 'تم تغيير كلمة المرور بنجاح. يمكنك تسجيل الدخول الآن.';
      });
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object catch (error) {
      if (mounted) {
        fail('تعذر تغيير كلمة المرور: ${friendlyApiError(error)}');
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  void back() {
    if (step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      step -= 1;
      message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.currentAdminIsDeveloper) {
      return const StatusScreen(
        title: 'غير مسموح',
        message: 'هذه الصفحة مخصصة لحساب الدفلوبر فقط.',
        icon: Icons.lock_rounded,
        color: Color(0xFFEF4444),
      );
    }

    final (IconData icon, String title, String subtitle) = switch (step) {
      0 => (
        Icons.lock_outline_rounded,
        'نسيت كلمة المرور؟',
        'أدخل رقم هاتفك وسنرسل إليك رمزاً لاستعادة حسابك.',
      ),
      1 => (
        Icons.chat_bubble_outline_rounded,
        'تحقق من رقمك',
        'أرسلنا رمزاً من $codeLength أرقام إلى\n+222 ${phoneController.text.trim()}',
      ),
      _ => (
        Icons.check_rounded,
        'أنشئ كلمة مرور جديدة',
        'اختر كلمة مرور قوية ومختلفة عن كلمات المرور السابقة.',
      ),
    };

    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          back();
        }
      },
      child: Scaffold(
        backgroundColor: Eps.bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: EpsIconButton(
                  icon: Icons.arrow_forward_rounded,
                  tooltip: 'رجوع',
                  onTap: back,
                ),
              ),
              const SizedBox(height: 36),
              Center(child: EpsMark(icon: icon, size: 68)),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Eps.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Eps.muted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 22),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: KeyedSubtree(
                  key: ValueKey(step),
                  child: switch (step) {
                    0 => phoneStep(store),
                    1 => codeStep(store),
                    _ => passwordStep(store),
                  },
                ),
              ),
              if (message != null)
                success
                    ? Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Eps.greenSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message!,
                          style: const TextStyle(
                            color: Eps.greenInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : AuthErrorText(message!),
            ],
          ),
        ),
      ),
    );
  }

  Widget phoneStep(SchoolStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EpsFieldLabel('رقم الهاتف'),
        EpsPhoneField(
          controller: phoneController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => sendCode(store),
        ),
        const SizedBox(height: 22),
        EpsPrimaryButton(
          label: 'إرسال رمز التحقق',
          loading: sending,
          onPressed: () => sendCode(store),
        ),
      ],
    );
  }

  Widget codeStep(SchoolStore store) {
    final code = codeController.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => codeFocus.requestFocus(),
          child: Stack(
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < codeLength; i++)
                      Container(
                        width: 46,
                        height: 56,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: i == code.length && codeFocus.hasFocus
                                ? Eps.blue2
                                : Eps.field,
                            width: i == code.length && codeFocus.hasFocus
                                ? 1.6
                                : 1,
                          ),
                        ),
                        child: Text(
                          i < code.length ? code[i] : '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Eps.ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: codeController,
                    focusNode: codeFocus,
                    keyboardType: TextInputType.number,
                    maxLength: codeLength,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => confirmCode(),
                    decoration: const InputDecoration(counterText: ''),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        EpsPrimaryButton(label: 'تحقق من الرمز', onPressed: confirmCode),
        const SizedBox(height: 14),
        Center(
          child: resendLeft > 0
              ? Text(
                  'لم يصلك الرمز؟ إعادة الإرسال خلال 00:${resendLeft.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12.5, color: Eps.muted),
                )
              : TextButton(
                  onPressed: sending ? null : () => sendCode(store),
                  child: const Text('إعادة إرسال الرمز'),
                ),
        ),
      ],
    );
  }

  Widget passwordStep(SchoolStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EpsFieldLabel('كلمة المرور الجديدة'),
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
          onSubmitted: (_) => resetPassword(store),
        ),
        const SizedBox(height: 22),
        EpsPrimaryButton(
          label: 'حفظ كلمة المرور',
          loading: sending,
          onPressed: () => resetPassword(store),
        ),
      ],
    );
  }
}
