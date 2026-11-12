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

    const subStyle = TextStyle(fontSize: 9, color: Eps.muted, height: 1.8);
    final (IconData icon, String title, Widget subtitle) = switch (step) {
      0 => (
        Icons.lock_outline_rounded,
        'نسيت كلمة المرور؟',
        const Text(
          'أدخل رقم هاتفك وسنرسل إليك رمزاً لاستعادة حسابك.',
          textAlign: TextAlign.center,
          style: subStyle,
        ),
      ),
      1 => (
        Icons.chat_bubble_outline_rounded,
        'تحقق من رقمك',
        Column(
          children: [
            const Text(
              'أرسلنا رمزاً من $codeLength أرقام إلى',
              textAlign: TextAlign.center,
              style: subStyle,
            ),
            Text(
              '+222 ${phoneController.text.trim()}',
              textDirection: TextDirection.ltr,
              style: subStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      _ => (
        Icons.check_rounded,
        'أنشئ كلمة مرور جديدة',
        const Text(
          'اختر كلمة مرور قوية ومختلفة عن كلمات المرور السابقة.',
          textAlign: TextAlign.center,
          style: subStyle,
        ),
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
                          BoxShadow(
                            color: Color(0xFFF4F8FF),
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Eps.blue, size: 28),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w400,
                      color: Eps.ink,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  subtitle,
                  KeyedSubtree(
                    key: ValueKey(step),
                    child: switch (step) {
                      0 => phoneStep(store),
                      1 => codeStep(store),
                      _ => passwordStep(store),
                    },
                  ),
                  if (message != null)
                    success
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              message!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Eps.greenInk,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : AuthErrorText(message!),
                ],
              ),
              if (step < 2)
                Positioned(
                  top: 17,
                  left: 18,
                  child: AuthBackButton(onTap: back),
                ),
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
        const AuthLabel('رقم الهاتف', top: 35),
        EpsPhoneField(
          controller: phoneController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => sendCode(store),
        ),
        const SizedBox(height: 20),
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
    final hasError = message != null && !success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 35),
        GestureDetector(
          onTap: () => codeFocus.requestFocus(),
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
                                : i == code.length && codeFocus.hasFocus
                                ? Eps.blue
                                : const Color(0xFFDCE2EB),
                          ),
                          boxShadow: !hasError &&
                                  i == code.length &&
                                  codeFocus.hasFocus
                              ? const [
                                  BoxShadow(
                                    color: Eps.blueSoft,
                                    spreadRadius: 3,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          i < code.length ? code[i] : '',
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
        const SizedBox(height: 26),
        EpsPrimaryButton(label: 'تحقق من الرمز', onPressed: confirmCode),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'لم يصلك الرمز؟ ',
              style: TextStyle(fontSize: 9, color: Eps.muted),
            ),
            if (resendLeft > 0) ...[
              const Text(
                'إعادة الإرسال خلال ',
                style: TextStyle(fontSize: 9, color: Color(0xFF8992A3)),
              ),
              Text(
                '00:${resendLeft.toString().padLeft(2, '0')}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8992A3),
                ),
              ),
            ] else
              GestureDetector(
                onTap: sending ? null : () => sendCode(store),
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
    );
  }

  Widget passwordStep(SchoolStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthLabel('كلمة المرور الجديدة', top: 35),
        EpsPasswordField(
          controller: passwordController,
          hint: '6 أحرف على الأقل',
          textInputAction: TextInputAction.next,
        ),
        const AuthLabel('تأكيد كلمة المرور'),
        EpsPasswordField(
          controller: confirmPasswordController,
          hint: 'أعد كتابة كلمة المرور',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => resetPassword(store),
        ),
        const SizedBox(height: 20),
        EpsPrimaryButton(
          label: 'حفظ كلمة المرور',
          loading: sending,
          onPressed: () => resetPassword(store),
        ),
      ],
    );
  }
}
