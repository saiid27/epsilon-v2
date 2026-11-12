part of '../main.dart';

/// Profile tab (Figma: profile).
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _changeAvatar(BuildContext context) async {
    final learn = LearnScope.read(context);
    final picked = await NativeFilePicker.pickImage();
    if (picked == null) {
      return;
    }
    final uri = await paymentProofDataUri(picked.path, picked.name);
    await learn.saveProfile({'avatar_url': uri});
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final learn = LearnScope.of(context);
    final user = store.currentUser!;
    final profile = learn.profile;
    final xpLevel = profile?.xpLevel ?? 1;
    final subs = learn.subscriptions.take(3).toList();
    final unread = learn.unreadNotices;
    final badges = studentBadges(learn);
    Widget stat(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFD78500), size: 16),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontFamily: Eps.fontNum,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Eps.ink,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 7, color: Eps.muted)),
        ],
      ),
    );
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: learn.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
          children: [
            Stack(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: EpsIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'الإعدادات',
                    onTap: () =>
                        pushPage(context, const StudentSettingsScreen()),
                  ),
                ),
                Center(
                  child: GestureDetector(
                    onTap: () => _changeAvatar(context),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF2C27C), Color(0xFFBD782A)],
                            ),
                          ),
                          child:
                              profile != null &&
                                  profile.avatarUrl.isNotEmpty &&
                                  imageBytesFromDataUri(profile.avatarUrl) !=
                                      null
                              ? Image.memory(
                                  imageBytesFromDataUri(profile.avatarUrl)!,
                                  fit: BoxFit.cover,
                                  width: 66,
                                  height: 66,
                                )
                              : Text(
                                  firstLetter(user.name),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        Positioned(
                          left: -4,
                          bottom: -4,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: Eps.line),
                            ),
                            child: const Icon(
                              Icons.photo_camera_outlined,
                              size: 12,
                              color: Eps.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              user.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Eps.ink,
              ),
            ),
            Text(
              [
                if (profile?.level.isNotEmpty ?? false) profile!.level,
                if (profile?.faculty.isNotEmpty ?? false) profile!.faculty,
                if (profile?.university.isNotEmpty ?? false)
                  profile!.university,
              ].join(' • '),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 8, color: Eps.muted),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EpsBadge(learn.isSubscribed ? 'مشترك' : 'الخطة المجانية'),
                if (!learn.isSubscribed) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => pushPage(context, const UpgradeScreen()),
                    child: const EpsBadge(
                      'ترقية الخطة',
                      tone: EpsTone.gray,
                      icon: Icons.star_outline_rounded,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Eps.line),
              ),
              child: Row(
                children: [
                  stat(Icons.bolt_rounded, formatMru(learn.totalXp), 'نقاط XP'),
                  stat(
                    Icons.local_fire_department_outlined,
                    '${profile?.activeStreak ?? 0}',
                    'سلسلة أيام',
                  ),
                  stat(
                    Icons.emoji_events_outlined,
                    '${learn.correctAnswers}',
                    'إجابة صحيحة',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Eps.blue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_outlined,
                        color: Colors.white,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المستوى $xpLevel',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${profile?.xpToNextLevel ?? 250} XP للمستوى التالي',
                              style: const TextStyle(
                                fontSize: 7,
                                color: Color(0xFFD6E0F7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  EpsProgress(
                    value: profile?.levelProgress ?? 0,
                    height: 5,
                    color: Eps.orange,
                    track: const Color(0x30FFFFFF),
                  ),
                ],
              ),
            ),
            HomeSectionTitle(
              'حالة الدفع',
              link: 'عرض الكل',
              onTap: () => pushPage(context, const PaymentsStatusPage()),
            ),
            for (final s in subs)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _PaymentLine(subscription: s),
              ),
            const SizedBox(height: 6),
            _MenuRow(
              icon: Icons.menu_book_outlined,
              title: 'اشتراكاتي',
              subtitle: '${learn.activeSubjects.length} مواد نشطة',
              onTap: () => StudentShellState.of(context)?.goTab(1),
            ),
            _MenuRow(
              icon: Icons.credit_card_outlined,
              title: 'سجل المدفوعات',
              subtitle: 'الإيصالات وحالة الدفع',
              onTap: () => pushPage(context, const PaymentsStatusPage()),
            ),
            _MenuRow(
              icon: Icons.notifications_none_rounded,
              title: 'الإشعارات',
              subtitle: '$unread إشعارات جديدة',
              onTap: () => pushPage(context, const StudentNotificationsPage()),
            ),
            _MenuRow(
              icon: Icons.emoji_events_outlined,
              title: 'الشارات والإنجازات',
              subtitle: '${badges.where((b) => b.$3).length} شارات مكتسبة',
              onTap: () => pushPage(context, const BadgesPage()),
            ),
            _MenuRow(
              icon: Icons.settings_outlined,
              title: 'الإعدادات والدعم',
              subtitle: 'اللغة، الخصوصية والمساعدة',
              onTap: () => pushPage(context, const StudentSettingsScreen()),
            ),
            const SizedBox(height: 8),
            const LogoutButton(),
          ],
        ),
      ),
    );
  }
}

/// Achievements derived from the student's real activity.
List<(IconData, String, bool)> studentBadges(LearnStore learn) => [
  (
    Icons.play_circle_outline,
    'أول درس مكتمل',
    learn.completedLessonIds.isNotEmpty,
  ),
  (
    Icons.local_fire_department_outlined,
    'سلسلة 7 أيام',
    (learn.profile?.streakDays ?? 0) >= 7,
  ),
  (Icons.bolt_rounded, '1000 نقطة XP', learn.totalXp >= 1000),
  (Icons.emoji_events_outlined, '10 اختبارات', learn.attempts.length >= 10),
  (
    Icons.verified_outlined,
    'إجابات كاملة',
    learn.attempts.any((a) => a.total > 0 && a.correctCount == a.total),
  ),
  (Icons.school_outlined, 'مشترك في مادة', learn.isSubscribed),
];

class BadgesPage extends StatelessWidget {
  const BadgesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final badges = studentBadges(LearnScope.of(context));
    return EpsPage(
      title: 'الشارات والإنجازات',
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (final (icon, label, earned) in badges)
              Container(
                decoration: BoxDecoration(
                  color: earned ? Eps.orangeSoft : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: earned ? const Color(0xFFF8DDA3) : Eps.line,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 26,
                      color: earned ? const Color(0xFFD78500) : Eps.line,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: earned ? Eps.ink : Eps.faint,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PaymentLine extends StatelessWidget {
  const _PaymentLine({required this.subscription});

  final EpsSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final badge = subscriptionBadge(subscription)!;
    final rejected = subscription.status == SubscriptionStatus.rejected;
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Eps.line),
      ),
      child: Row(
        children: [
          EpsBadge(badge.$1, tone: badge.$2),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  learn.subjectById(subscription.subjectId)?.name ?? '',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Eps.ink,
                  ),
                ),
                if (rejected && subscription.rejectionReason.isNotEmpty)
                  Text(
                    'السبب: ${subscription.rejectionReason}',
                    style: const TextStyle(fontSize: 6, color: Eps.red),
                  ),
              ],
            ),
          ),
          Text(
            'MRU ${formatMru(subscription.amount)}',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontFamily: Eps.fontNum,
              fontSize: 7,
              fontWeight: FontWeight.w700,
              color: Eps.blue,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 14, color: Eps.ink),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Eps.line),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Eps.blueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Eps.blue, size: 17),
              ),
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
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 7, color: Eps.muted),
                    ),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Eps.faint,
                    size: 17,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        LearnScope.read(context).clear();
        Navigator.of(context).popUntil((r) => r.isFirst);
        StoreScope.of(context).logout();
      },
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6F7),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFF6CDD2)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'تسجيل الخروج',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Eps.red,
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.logout_rounded, color: Eps.red, size: 16),
          ],
        ),
      ),
    );
  }
}

/// Settings (Figma: settings).
class StudentSettingsScreen extends StatefulWidget {
  const StudentSettingsScreen({super.key});

  @override
  State<StudentSettingsScreen> createState() => _StudentSettingsScreenState();
}

class _StudentSettingsScreenState extends State<StudentSettingsScreen> {
  static const _notifyKey = 'epsilon_notifications_enabled';
  bool notify = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() => notify = p.getBool(_notifyKey) ?? true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    Widget head(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Eps.ink,
        ),
      ),
    );
    return EpsPage(
      title: 'الإعدادات',
      children: [
        head('التفضيلات'),
        _MenuRow(
          icon: Icons.translate_rounded,
          title: 'اللغة',
          subtitle: store.languageCode == 'fr' ? 'Français' : 'العربية',
          onTap: null,
          trailing: Container(
            height: 24,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Eps.gray,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                for (final (code, label) in [('ar', 'ع'), ('fr', 'FR')])
                  GestureDetector(
                    onTap: () => store.setLanguageCode(code),
                    child: Container(
                      width: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: store.languageCode == code
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 8, color: Eps.muted),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        _MenuRow(
          icon: Icons.notifications_none_rounded,
          title: 'الإشعارات',
          subtitle: 'الجلسات، الاختبارات والدفع',
          onTap: null,
          trailing: Switch(
            value: notify,
            onChanged: (v) async {
              setState(() => notify = v);
              final p = await SharedPreferences.getInstance();
              await p.setBool(_notifyKey, v);
            },
          ),
        ),
        head('المساعدة'),
        _MenuRow(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'تواصل عبر WhatsApp',
          subtitle: 'نحن هنا للرد على أسئلتك',
          onTap: () => pushPage(context, const ContactUsPage()),
        ),
        _MenuRow(
          icon: Icons.headset_mic_outlined,
          title: 'مركز المساعدة',
          subtitle: 'الأسئلة الشائعة والدعم',
          onTap: () => pushPage(context, const AssistantScreen()),
        ),
        _MenuRow(
          icon: Icons.help_outline_rounded,
          title: 'عن أبسيلون',
          subtitle: 'سياسة الخصوصية والإصدار',
          onTap: () => pushPage(context, const AboutPage()),
        ),
        _MenuRow(
          icon: Icons.privacy_tip_outlined,
          title: 'سياسة الخصوصية',
          subtitle: 'كيف نحمي بياناتك',
          onTap: () => pushPage(context, const PrivacyPolicyPage()),
        ),
        const SizedBox(height: 6),
        const LogoutButton(),
      ],
    );
  }
}

/// Notifications (Figma: notifications).
class StudentNotificationsPage extends StatelessWidget {
  const StudentNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    (IconData, Color, Color) style(String kind) => switch (kind) {
      'subscription_active' => (Icons.check_rounded, Eps.green, Eps.greenSoft),
      'subscription_rejected' => (Icons.close_rounded, Eps.red, Eps.redSoft),
      'live' => (Icons.sensors_rounded, Eps.blue, Eps.blueSoft),
      'quiz' => (
        Icons.sports_esports_outlined,
        Color(0xFFD78500),
        Eps.orangeSoft,
      ),
      'expiry' => (Icons.schedule_rounded, Eps.red, Eps.redSoft),
      _ => (Icons.notifications_none_rounded, Eps.blue, Eps.blueSoft),
    };
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: EpsPageHeader(
                title: 'الإشعارات',
                action: GestureDetector(
                  onTap: learn.markAllRead,
                  child: const Center(
                    child: Text(
                      'قراءة الكل',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        color: Eps.blue,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: learn.notices.isEmpty
                  ? const Center(child: EpsLogoLoader(label: 'لا توجد إشعارات'))
                  : ListView(
                      children: [
                        for (final n in learn.notices)
                          Builder(
                            builder: (context) {
                              final (icon, fg, bg) = style(n.kind);
                              return Container(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  14,
                                  18,
                                  14,
                                ),
                                decoration: BoxDecoration(
                                  color: n.read
                                      ? Colors.transparent
                                      : const Color(0xFFEFF4FF),
                                  border: const Border(
                                    bottom: BorderSide(color: Eps.line),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: bg,
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Icon(icon, color: fg, size: 17),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n.title,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: Eps.ink,
                                            ),
                                          ),
                                          Text(
                                            n.body,
                                            style: const TextStyle(
                                              fontSize: 7,
                                              color: Eps.muted,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            timeAgo(n.createdAt),
                                            style: const TextStyle(
                                              fontSize: 6,
                                              color: Eps.faint,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!n.read)
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(top: 4),
                                        decoration: const BoxDecoration(
                                          color: Eps.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
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

/// Payment history (Figma: payments).
class PaymentsStatusPage extends StatelessWidget {
  const PaymentsStatusPage({super.key});

  String _d(DateTime? d) => d == null
      ? ''
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final total = learn.subscriptions
        .where((s) => s.status != SubscriptionStatus.rejected)
        .fold(0, (sum, s) => sum + s.amount);
    return EpsPage(
      title: 'حالة الدفع',
      children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: Eps.blue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إجمالي المدفوعات',
                      style: TextStyle(fontSize: 7, color: Color(0xFFD6E0F7)),
                    ),
                    Text(
                      'MRU ${formatMru(total)}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontFamily: Eps.fontNum,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final s in learn.subscriptions)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: s.status == SubscriptionStatus.rejected
                    ? const Color(0xFFEFC0C5)
                    : Eps.line,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EpsBadge(
                        subscriptionBadge(s)!.$1,
                        tone: subscriptionBadge(s)!.$2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        learn.subjectById(s.subjectId)?.name ?? '',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Eps.ink,
                        ),
                      ),
                      Text(
                        s.startsAt == null
                            ? 'طلب ${s.ref} • ${_d(s.createdAt)}'
                            : '${_d(s.startsAt)} — ${_d(s.expiresAt)}',
                        style: const TextStyle(fontSize: 7, color: Eps.muted),
                      ),
                      if (s.status == SubscriptionStatus.rejected) ...[
                        Text(
                          s.rejectionReason,
                          style: const TextStyle(fontSize: 7, color: Eps.red),
                        ),
                        GestureDetector(
                          onTap: () {
                            learn.cart
                              ..clear()
                              ..add(s.subjectId);
                            learn.selectPlan(s.planCode);
                            pushPage(context, const ReceiptUploadScreen());
                          },
                          child: const Text(
                            'إعادة رفع الإيصال',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: Eps.red,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  'MRU ${formatMru(s.amount)}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontFamily: Eps.fontNum,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Eps.blue,
                  ),
                ),
              ],
            ),
          ),
        if (learn.subscriptions.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EpsLogoLoader(label: 'لا توجد مدفوعات بعد'),
          ),
      ],
    );
  }
}

/// Free plan hub (Figma: freePlan).
class FreePlanScreen extends StatefulWidget {
  const FreePlanScreen({super.key});

  @override
  State<FreePlanScreen> createState() => _FreePlanScreenState();
}

class _FreePlanScreenState extends State<FreePlanScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final live = learn.liveSessions
        .where((s) => s.isFree && s.state != LiveState.past)
        .toList();
    final lessons = learn.freeLessons;
    final exercises = learn.exercises.where((e) => e.isFree).toList();
    final pdfs = learn.pdfs.where((p) => p.isFree).toList();
    final quizzes = learn.quizzes.where((q) => q.isFree).toList();
    const tabs = [
      'البث المباشر',
      'شروحات',
      'تمارين مع الحلول',
      'الملفات',
      'المسابقة',
    ];
    return EpsPage(
      title: 'الخطة المجانية',
      action: const Center(child: EpsBadge('مجاناً', tone: EpsTone.green)),
      children: [
        if (!learn.isSubscribed)
          UpgradeBanner(
            collapsed: false,
            onToggle: () {},
            onUpgrade: () => pushPage(context, const UpgradeScreen()),
          ),
        Container(
          height: 136,
          padding: const EdgeInsets.all(14),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF203F98), Eps.blue],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    EpsBadge('ابدأ دون اشتراك', tone: EpsTone.green),
                    SizedBox(height: 6),
                    Text(
                      'تعلّم كل يوم، مجاناً',
                      style: TextStyle(fontSize: 17, color: Colors.white),
                    ),
                    Text(
                      'دروس قصيرة وتمارين محلولة وملخصات PDF مختارة بعناية.',
                      style: TextStyle(fontSize: 7, color: Color(0xFFD6E0F7)),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: Color(0xFFF1B91C),
                  size: 26,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < tabs.length; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 5),
                  child: GestureDetector(
                    onTap: () => setState(() => tab = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == tab
                            ? Colors.white
                            : const Color(0xFFECEFF5),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        tabs[i],
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: i == tab
                              ? FontWeight.w800
                              : FontWeight.w400,
                          color: i == tab ? Eps.blue : Eps.muted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...switch (tab) {
          0 => [
            for (final s in live)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LiveSessionRow(session: s),
              ),
          ],
          1 => [
            for (final l in lessons)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: LessonRow(lesson: l),
              ),
          ],
          2 => [
            for (final e in exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: ExerciseCard(exercise: e),
              ),
          ],
          3 => [
            for (final p in pdfs)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: PdfRow(pdf: p),
              ),
          ],
          _ => [
            for (final q in quizzes)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: QuizRow(quiz: q),
              ),
          ],
        },
        const SizedBox(height: 6),
        const FreeUpsell(),
      ],
    );
  }
}

/// Free vs subscribed comparison (Figma: upgrade).
class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('البث المباشر', 'جلسات مختارة', 'جميع الجلسات'),
      ('ملفات PDF', 'ملفات مختارة', 'كل ملفات المادة'),
      ('التمارين', 'تمارين محددة', 'بنك التمارين الكامل'),
      ('التسجيلات', 'غير متاح', 'كل التسجيلات'),
      ('الاختبارات', 'المسابقات العامة', 'اختبارات كل وحدة'),
      ('مساعد AI', '5 أسئلة يومياً', 'أسئلة أكثر يومياً'),
      ('المسابقات', 'متاح', 'متاح + نقاط إضافية'),
    ];
    const head = TextStyle(
      fontSize: 7,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    return EpsPage(
      title: 'المجانية مقابل المشترك',
      bottom: EpsPrimaryButton(
        label: 'اختر المواد للترقية',
        icon: Icons.chevron_right_rounded,
        onPressed: () => pushPage(context, const CatalogScreen()),
      ),
      children: [
        Container(
          height: 118,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF203F98), Eps.blue],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star_rounded, color: Color(0xFFF9CE42)),
              ),
              const SizedBox(height: 8),
              const Text(
                'افتح تجربة التعلم الكاملة',
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
              const Text(
                'اختر المواد التي تحتاجها فقط، وادفع اشتراك كل مادة بشكل مستقل.',
                style: TextStyle(fontSize: 7, color: Color(0xFFD6E0F7)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Eps.line),
          ),
          child: Column(
            children: [
              Container(
                height: 34,
                color: Eps.blue,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: const Row(
                  children: [
                    Expanded(child: Text('الميزة', style: head)),
                    Expanded(
                      child: Text(
                        'المجانية',
                        style: head,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'المشترك',
                        style: head,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              for (final (f, free, paid) in rows)
                Container(
                  height: 33,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Eps.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                            color: Eps.ink,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          free,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 6, color: Eps.muted),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_rounded,
                              size: 10,
                              color: Eps.green,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                paid,
                                style: const TextStyle(
                                  fontSize: 6,
                                  fontWeight: FontWeight.w700,
                                  color: Eps.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Assistant chat (Figma: assistant). Answers come from the `assistant`
/// Supabase Edge Function.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({this.lessonTitle, this.subjectName, super.key});

  final String? lessonTitle;
  final String? subjectName;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  static const dailyLimit = 5;
  final input = TextEditingController();
  final messages = <({bool me, String text})>[];
  int used = 0;
  bool thinking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final learn = LearnScope.read(context);
      final name = firstName(StoreScope.of(context).currentUser?.name ?? '');
      setState(
        () => messages.add((
          me: false,
          text:
              'مرحباً $name! أنا مساعد إبسيلون. كيف يمكنني مساعدتك${widget.lessonTitle == null ? '' : ' في درس «${widget.lessonTitle}»'}؟',
        )),
      );
      if (learn.enabled && learn.userId != null) {
        try {
          final n = await learn.repo.assistantQuestionsToday(learn.userId!);
          if (mounted) {
            setState(() => used = n);
          }
        } on Object {
          // Counter is informative only.
        }
      }
    });
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  bool get limited => !LearnScope.read(context).isSubscribed;

  Future<void> ask(String text) async {
    final q = text.trim();
    if (q.isEmpty || thinking) {
      return;
    }
    if (limited && used >= dailyLimit) {
      setState(
        () => messages.add((
          me: false,
          text:
              'وصلت إلى الحد اليومي للأسئلة في الخطة المجانية. رقِّ اشتراكك لمزيد من الأسئلة.',
        )),
      );
      return;
    }
    final learn = LearnScope.read(context);
    input.clear();
    setState(() {
      messages.add((me: true, text: q));
      thinking = true;
    });
    try {
      final reply = await learn.repo.askAssistant(
        userId: learn.userId ?? '',
        lessonTitle: widget.lessonTitle,
        subjectName: widget.subjectName,
        messages: [
          for (final m in messages.skip(1))
            {'role': m.me ? 'user' : 'assistant', 'content': m.text},
        ],
      );
      setState(() {
        messages.add((me: false, text: reply));
        used++;
      });
    } on Object catch (e) {
      setState(
        () =>
            messages.add((me: false, text: 'تعذر الوصول إلى المساعد الآن. $e')),
      );
    } finally {
      if (mounted) {
        setState(() => thinking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final left = (dailyLimit - used).clamp(0, dailyLimit);
    const chips = [
      'اشرح لي هذا الدرس',
      'حل هذا التمرين خطوة بخطوة',
      'أعطني مثالاً',
      'كيف أشترك؟',
      'كيف أرفع الوصل؟',
    ];
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: EpsPageHeader(title: 'مساعد إبسيلون'),
            ),
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Eps.line),
              ),
              child: Row(
                children: [
                  const EpsLogo(size: 34, shadow: null),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مساعد إبسيلون',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Eps.ink,
                          ),
                        ),
                        Text(
                          '● متصل',
                          style: TextStyle(fontSize: 7, color: Eps.green),
                        ),
                      ],
                    ),
                  ),
                  if (!learn.isSubscribed)
                    EpsBadge('متبقي لك $left أسئلة اليوم'),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                children: [
                  for (final m in messages)
                    Align(
                      alignment: m.me
                          ? AlignmentDirectional.centerStart
                          : AlignmentDirectional.centerEnd,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 280),
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: m.me ? Eps.blue : const Color(0xFFE9EEF9),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          m.text,
                          style: TextStyle(
                            fontSize: 9,
                            height: 1.7,
                            color: m.me ? Colors.white : Eps.ink,
                          ),
                        ),
                      ),
                    ),
                  if (thinking)
                    const Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 30,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in chips)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: GestureDetector(
                        onTap: () => ask(c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Eps.line),
                          ),
                          child: Text(
                            c,
                            style: const TextStyle(fontSize: 7, color: Eps.ink),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              height: 46,
              margin: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Eps.line),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: input,
                      onSubmitted: ask,
                      style: const TextStyle(fontSize: 9),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'اكتب سؤالك هنا...',
                        hintStyle: TextStyle(fontSize: 9, color: Eps.faint),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ask(input.text),
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
          ],
        ),
      ),
    );
  }
}
