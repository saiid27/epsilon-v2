part of '../main.dart';

/// Profile tab (Figma: profile).
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _changeAvatar(BuildContext context) async {
    final learn = LearnScope.read(context);
    final hasPhoto = learn.avatarUrl.isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'صورة الحساب',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: Eps.blue,
                ),
                title: Text(hasPhoto ? 'تغيير الصورة' : 'إضافة صورة'),
                onTap: () => Navigator.of(sheet).pop('pick'),
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Eps.red,
                  ),
                  title: const Text(
                    'حذف الصورة',
                    style: TextStyle(color: Eps.red),
                  ),
                  onTap: () => Navigator.of(sheet).pop('remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (action == 'remove') {
        await learn.setAvatar('');
        messenger.showSnackBar(const SnackBar(content: Text('تم حذف الصورة')));
        return;
      }
      final picked = await NativeFilePicker.pickImage();
      if (picked == null) {
        return;
      }
      final bytes =
          NativeFilePicker.webFiles[picked.path] ??
          await File(picked.path).readAsBytes();
      await learn.setAvatar(await avatarDataUri(bytes));
      messenger.showSnackBar(
        const SnackBar(content: Text('تم تحديث صورة الحساب')),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر حفظ الصورة، حاول مرة أخرى')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final learn = LearnScope.of(context);
    final user = store.currentUser!;
    final profile = learn.profile;
    final xpLevel = profile?.xpLevel ?? 1;
    final waiting = [
      ...learn.withStatus(SubscriptionStatus.pending),
      ...learn.withStatus(SubscriptionStatus.rejected),
    ];
    final settled = learn.subscriptions
        .where(
          (s) =>
              s.status != SubscriptionStatus.pending &&
              s.status != SubscriptionStatus.rejected,
        )
        .take(3)
        .toList();
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
                          child: imageBytesFromDataUri(learn.avatarUrl) != null
                              ? Image.memory(
                                  imageBytesFromDataUri(learn.avatarUrl)!,
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
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Eps.blue,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.photo_camera_outlined,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: GestureDetector(
                onTap: () => _changeAvatar(context),
                child: Text(
                  learn.avatarUrl.isEmpty ? 'إضافة صورة' : 'تعديل الصورة',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Eps.blue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
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
              'اشتراكاتي ووضعيتها',
              link: 'عرض الكل',
              onTap: () => pushPage(context, const PaymentsStatusPage()),
            ),
            if (waiting.isEmpty && settled.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 7),
                child: Text(
                  'لا توجد اشتراكات بعد. أضف مادة من تبويب موادي.',
                  style: TextStyle(fontSize: 9, color: Eps.muted),
                ),
              ),
            for (final s in waiting)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: SubscriptionStateRow(subscription: s),
              ),
            for (final s in settled)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _PaymentLine(subscription: s),
              ),
            const SizedBox(height: 6),
            _MenuRow(
              icon: Icons.menu_book_outlined,
              title: 'موادي النشطة',
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
              icon: Icons.fact_check_outlined,
              title: 'نتائجي الجامعية',
              subtitle: 'موقع نتائج جامعة نواكشوط',
              onTap: () => pushPage(
                context,
                UniversityResultsPage(url: learn.universityResultsUrl),
              ),
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
            if (!learn.isSubscribed)
              GestureDetector(
                onTap: () => pushPage(context, const UpgradeScreen()),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF4FF),
                    border: Border(bottom: BorderSide(color: Eps.line)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Eps.orangeSoft,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFD78500),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'أنت على الخطة المجانية',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Eps.ink,
                              ),
                            ),
                            Text(
                              'رقِّ خطتك لتستفيد أكثر: كل الدروس والجلسات والاختبارات.',
                              style: TextStyle(fontSize: 7, color: Eps.muted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Eps.faint,
                        size: 17,
                      ),
                    ],
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
    final pdfs = learn.pdfs.where((p) => p.isFree).toList();
    // The free plan is live sessions and PDF files only.
    const tabs = ['البث المباشر', 'الملفات'];
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
                      'جلسات بث مباشر مجانية وملفات PDF مختارة بعناية.',
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
          _ => [
            for (final p in pdfs)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: PdfRow(pdf: p),
              ),
          ],
        },
        const SizedBox(height: 6),
        const FreeUpsell(),
      ],
    );
  }
}

/// Shown to free accounts on features outside the free plan (the free plan
/// is live sessions and PDF files only).
class SubscribersOnlyPage extends StatelessWidget {
  const SubscribersOnlyPage({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EpsPage(
      title: title,
      children: [
        const SizedBox(height: 60),
        const Center(
          child: EpsMark(icon: Icons.lock_outline_rounded, size: 64),
        ),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Eps.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'الخطة المجانية تشمل البث المباشر وملفات PDF.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Eps.muted),
        ),
        const SizedBox(height: 20),
        EpsPrimaryButton(
          label: 'اشترك في مادة',
          icon: Icons.add_rounded,
          onPressed: () => pushPage(context, const SectionsScreen()),
        ),
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
      ('الدروس والشروحات', 'غير متاح', 'كل دروس المادة'),
      ('التمارين مع الحلول', 'غير متاح', 'بنك التمارين الكامل'),
      ('الاختبارات والمسابقات', 'غير متاح', 'اختبارات كل وحدة'),
      ('مساعد AI', 'غير متاح', 'متاح يومياً'),
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
        onPressed: () => pushPage(context, const SectionsScreen()),
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
  static const dailyQuestions = 10;
  static const dailyFiles = 6;
  final input = TextEditingController();
  final messages = <({bool me, String text, Uint8List? image, String? file})>[];

  /// Credit left (daily allowance; unused credit carries over).
  int questionsLeft = dailyQuestions;
  int filesLeft = dailyFiles;
  bool thinking = false;

  /// Photo of an exercise waiting to be sent with the next question.
  ({Uint8List bytes, String dataUri})? photo;
  bool preparingPhoto = false;

  /// PDF file (course, exam...) waiting to be sent with the next question.
  ({String name, String dataUri})? pdf;

  /// Largest PDF accepted, in bytes.
  static const maxPdfBytes = 7 * 1024 * 1024;

  /// How the assistant answers: full solution, hint, explanation, check of
  /// the student's own work, or practice exercises.
  static const modes = [
    ('solve', 'حل كامل', Icons.calculate_outlined),
    ('hint', 'تلميح فقط', Icons.lightbulb_outline_rounded),
    ('explain', 'اشرح المفهوم', Icons.menu_book_outlined),
    ('check', 'صحّح حلي', Icons.fact_check_outlined),
    ('practice', 'تمارين مشابهة', Icons.repeat_rounded),
    ('pdf', 'اشرح ملف PDF', Icons.picture_as_pdf_outlined),
    ('cv', 'سيرتي الذاتية CV', Icons.badge_outlined),
    ('write', 'رسالة أو تقرير', Icons.edit_note_rounded),
  ];
  String mode = 'solve';

  /// Voice questions: speech is turned into text on the phone.
  final speech = stt.SpeechToText();
  bool listening = false;
  bool french = false;

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
              'مرحباً $name! أنا مساعد إبسيلون. أحل وأشرح تمارينك${widget.lessonTitle == null ? '' : ' في درس «${widget.lessonTitle}»'}، وأشرح ملفات PDF، وأكتب سيرتك الذاتية ورسائلك وتقاريرك. اكتب، أو صوّر، أو أرفق ملفاً، أو تكلم.',
          image: null,
          file: null,
        )),
      );
      if (learn.enabled && learn.userId != null) {
        final balance = await learn.repo.assistantBalance(learn.userId!);
        if (balance != null && mounted) {
          setState(() {
            questionsLeft = balance.questions;
            filesLeft = balance.files;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    speech.cancel();
    input.dispose();
    super.dispose();
  }

  void say(String text) => setState(
    () => messages.add((me: false, text: text, image: null, file: null)),
  );

  Future<void> pickPdf() async {
    if (filesLeft <= 0) {
      say('نفد رصيد الصور والملفات. يتجدد غداً.');
      return;
    }
    final picked = await NativeFilePicker.pickPdf();
    if (picked == null) {
      return;
    }
    try {
      final bytes =
          NativeFilePicker.webFiles[picked.path] ??
          await File(picked.path).readAsBytes();
      if (bytes.length > maxPdfBytes) {
        say('الملف كبير جداً (الحد 7 ميغابايت). أرسل جزءاً منه.');
        return;
      }
      if (mounted) {
        setState(() {
          photo = null;
          pdf = (
            name: picked.name,
            dataUri: 'data:application/pdf;base64,${base64Encode(bytes)}',
          );
        });
      }
    } on Object {
      say('تعذر قراءة الملف، جرّب ملفاً آخر.');
    }
  }

  /// Saves an answer (a CV, a letter, a solution...) as a PDF file.
  Future<void> savePdf(String text) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final cv = mode == 'cv';
      final bytes = await answerPdfBytes(
        text,
        title: cv ? null : 'مساعد إبسيلون',
      );
      final name = cv
          ? 'CV.pdf'
          : 'epsilon-${DateTime.now().millisecondsSinceEpoch}.pdf';
      if (kIsWeb) {
        downloadWebFile(bytes, name, 'application/pdf');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      await share.SharePlus.instance.share(
        share.ShareParams(
          files: [
            share.XFile(file.path, mimeType: 'application/pdf', name: name),
          ],
          fileNameOverrides: [name],
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('تعذر إنشاء PDF: $e')));
    }
  }

  Future<void> pickPhoto() async {
    if (filesLeft <= 0) {
      say('نفد رصيد الصور والملفات. يتجدد غداً.');
      return;
    }
    final picked = await NativeFilePicker.pickImage();
    if (picked == null) {
      return;
    }
    setState(() => preparingPhoto = true);
    try {
      final bytes =
          NativeFilePicker.webFiles[picked.path] ??
          await File(picked.path).readAsBytes();
      final dataUri = await shrinkImageDataUri(bytes, width: 1100);
      if (mounted) {
        setState(() {
          pdf = null;
          photo = (bytes: bytes, dataUri: dataUri);
        });
      }
    } on Object {
      say('تعذر قراءة الصورة، جرّب صورة أخرى.');
    } finally {
      if (mounted) {
        setState(() => preparingPhoto = false);
      }
    }
  }

  Future<void> toggleVoice() async {
    if (listening) {
      await speech.stop();
      setState(() => listening = false);
      return;
    }
    final ready = await speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => listening = false);
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => listening = false);
        }
      },
    );
    if (!ready) {
      say(
        'لا يمكن استعمال الميكروفون هنا. اسمح للتطبيق بالميكروفون، أو استعمل متصفح Chrome.',
      );
      return;
    }
    setState(() => listening = true);
    await speech.listen(
      onResult: (result) {
        input.text = result.recognizedWords;
        input.selection = TextSelection.collapsed(offset: input.text.length);
        if (result.finalResult && mounted) {
          setState(() => listening = false);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: french ? 'fr_FR' : 'ar_SA',
        partialResults: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> ask(String text) async {
    final sending = photo;
    final sendingPdf = pdf;
    var q = text.trim();
    if (q.isEmpty && sendingPdf != null) {
      q = 'اشرح هذا الملف وعلّق عليه';
    }
    if (q.isEmpty && sending != null) {
      q = switch (mode) {
        'hint' => 'أعطني تلميحاً لحل هذا التمرين',
        'check' => 'صحّح حلي في الصورة',
        'explain' => 'اشرح المفهوم المستعمل في هذا التمرين',
        'practice' => 'أعطني تمارين مشابهة لهذا التمرين',
        _ => 'حل هذا التمرين خطوة بخطوة',
      };
    }
    if (q.isEmpty || thinking) {
      return;
    }
    final hasFile = sending != null || sendingPdf != null;
    if (!hasFile && questionsLeft <= 0) {
      say('نفد رصيد الأسئلة. يتجدد غداً، وما لا تستعمله يُضاف لرصيدك.');
      return;
    }
    if (listening) {
      await speech.stop();
    }
    if (!mounted) {
      return;
    }
    final learn = LearnScope.read(context);
    input.clear();
    setState(() {
      messages.add((
        me: true,
        text: q,
        image: sending?.bytes,
        file: sendingPdf?.name,
      ));
      photo = null;
      pdf = null;
      listening = false;
      thinking = true;
    });
    try {
      if (!learn.enabled) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        say(
          '### المعطيات\n'
          r'نريد حساب $I = \int_0^1 x e^{x}\,dx$.'
          '\n### الطريقة\n'
          'نستعمل l\'intégration par parties.\n'
          '### الحل\n'
          r'1. نضع $u = x$ و $dv = e^{x}dx$، إذن $du = dx$ و $v = e^{x}$.'
          '\n'
          r'2. $I = [x e^{x}]_0^1 - \int_0^1 e^{x}\,dx = e - (e - 1)$.'
          '\n### النتيجة\n'
          r'$$I = 1$$'
          '\n### التحقق\n'
          r"المشتقة $(x e^{x} - e^{x})' = x e^{x}$ ✓ (وضع المعاينة)",
        );
        return;
      }
      final lesson = widget.lessonTitle == null
          ? null
          : learn.lessons
                .where((l) => l.title == widget.lessonTitle)
                .firstOrNull;
      final profile = learn.profile;
      final answer = await learn.repo.askAssistant(
        userId: learn.userId ?? '',
        lessonTitle: widget.lessonTitle,
        subjectName: widget.subjectName,
        image: sending?.dataUri,
        document: sendingPdf?.dataUri,
        documentName: sendingPdf?.name,
        studentName: StoreScope.of(context).currentUser?.name,
        mode: mode,
        studentLevel: profile == null
            ? null
            : [
                profile.level,
                profile.track,
                profile.faculty,
                profile.university,
              ].where((x) => x.isNotEmpty).join(' • '),
        lessonSummary: lesson == null
            ? null
            : [
                if (lesson.description.isNotEmpty) lesson.description,
                if (lesson.keyIdea.isNotEmpty) 'الفكرة: ${lesson.keyIdea}',
                if (lesson.example.isNotEmpty) 'مثال: ${lesson.example}',
              ].join('\n'),
        messages: [
          for (final m in messages.skip(1))
            {
              'role': m.me ? 'user' : 'assistant',
              'content': m.file != null
                  ? '[ملف PDF: ${m.file}] ${m.text}'
                  : m.image != null
                  ? '[صورة] ${m.text}'
                  : m.text,
            },
        ],
      );
      setState(() {
        messages.add((me: false, text: answer.reply, image: null, file: null));
        questionsLeft =
            answer.questionsLeft ??
            (hasFile ? questionsLeft : questionsLeft - 1);
        filesLeft = answer.filesLeft ?? (hasFile ? filesLeft - 1 : filesLeft);
      });
    } on Object catch (e) {
      say(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => thinking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    if (!learn.isSubscribed) {
      return const SubscribersOnlyPage(
        title: 'مساعد إبسيلون',
        message: 'مساعد الذكاء الاصطناعي متاح للمشتركين فقط.',
      );
    }
    Widget roundButton(
      IconData icon,
      VoidCallback? onTap, {
      Color color = Eps.blueSoft,
      Color ink = Eps.blue,
      String? tooltip,
    }) => Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: ink, size: 17),
        ),
      ),
    );
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
                  EpsBadge('رصيدك: $questionsLeft سؤال • $filesLeft ملف'),
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
                        constraints: BoxConstraints(maxWidth: m.me ? 290 : 340),
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: m.me ? Eps.blue : const Color(0xFFE9EEF9),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (m.image != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: Image.memory(
                                    m.image!,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            if (m.file != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        m.file!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (m.me)
                              SelectableText(
                                m.text,
                                style: const TextStyle(
                                  fontSize: 9,
                                  height: 1.7,
                                  color: Colors.white,
                                ),
                              )
                            else ...[
                              MathAnswer(text: m.text),
                              if (m != messages.first)
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton.icon(
                                    onPressed: () => savePdf(m.text),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.picture_as_pdf_outlined,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      'حفظ PDF',
                                      style: TextStyle(fontSize: 9),
                                    ),
                                  ),
                                ),
                            ],
                          ],
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
            if (pdf != null)
              Container(
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Eps.line),
                ),
                child: Row(
                  children: [
                    const EpsMark(
                      icon: Icons.picture_as_pdf_rounded,
                      tone: EpsTone.red,
                      size: 44,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${pdf!.name}\nاكتب سؤالك عن الملف أو اضغط إرسال مباشرة.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 8, color: Eps.muted),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إزالة الملف',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => pdf = null),
                    ),
                  ],
                ),
              ),
            if (photo != null || preparingPhoto)
              Container(
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Eps.line),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: photo == null
                          ? const SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : Image.memory(
                              photo!.bytes,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'صورة التمرين جاهزة. اكتب سؤالك أو اضغط إرسال مباشرة.',
                        style: TextStyle(fontSize: 8, color: Eps.muted),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إزالة الصورة',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => photo = null),
                    ),
                  ],
                ),
              ),
            if (listening)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  french
                      ? '● Parlez maintenant… (اضغط الميكروفون للإيقاف)'
                      : '● تكلم الآن… (اضغط الميكروفون للإيقاف)',
                  style: const TextStyle(fontSize: 9, color: Eps.red),
                ),
              ),
            SizedBox(
              height: 32,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (code, label, icon) in modes)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => mode = code);
                          if (code == 'pdf' && pdf == null) {
                            pickPdf();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: mode == code ? Eps.blue : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: mode == code ? Eps.blue : Eps.line,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                size: 13,
                                color: mode == code ? Colors.white : Eps.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: mode == code ? Colors.white : Eps.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: listening ? Eps.red : Eps.line),
              ),
              child: Row(
                children: [
                  roundButton(
                    Icons.photo_camera_outlined,
                    thinking ? null : pickPhoto,
                    tooltip: 'صوّر التمرين',
                  ),
                  const SizedBox(width: 5),
                  roundButton(
                    Icons.attach_file_rounded,
                    thinking ? null : pickPdf,
                    tooltip: 'أرفق ملف PDF',
                  ),
                  const SizedBox(width: 5),
                  roundButton(
                    listening ? Icons.stop_rounded : Icons.mic_none_rounded,
                    thinking ? null : toggleVoice,
                    color: listening ? Eps.red : Eps.blueSoft,
                    ink: listening ? Colors.white : Eps.blue,
                    tooltip: 'اسأل بصوتك',
                  ),
                  GestureDetector(
                    onTap: listening
                        ? null
                        : () => setState(() => french = !french),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        french ? 'FR' : 'ع',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Eps.muted,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: input,
                      onSubmitted: ask,
                      minLines: 1,
                      maxLines: 4,
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
                  roundButton(
                    Icons.send_rounded,
                    thinking ? null : () => ask(input.text),
                    color: Eps.blue,
                    ink: Colors.white,
                    tooltip: 'إرسال',
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

/// LaTeX written as plain text for the PDF export (\frac{a}{b} → (a)/(b)...).
String plainMaths(String text) {
  var t = text.replaceAll(r'$$', '').replaceAll(r'$', '');
  final frac = RegExp(r'\\[dt]?frac\{([^{}]*)\}\{([^{}]*)\}');
  for (var i = 0; i < 3 && frac.hasMatch(t); i++) {
    t = t.replaceAllMapped(frac, (m) => '(${m[1]})/(${m[2]})');
  }
  const symbols = {
    r'\sqrt': '√',
    r'\int': '∫',
    r'\sum': 'Σ',
    r'\prod': 'Π',
    r'\infty': '∞',
    r'\leq': '≤',
    r'\geq': '≥',
    r'\le': '≤',
    r'\ge': '≥',
    r'\neq': '≠',
    r'\approx': '≈',
    r'\times': '×',
    r'\cdot': '·',
    r'\pm': '±',
    r'\to': '→',
    r'\Rightarrow': '⇒',
    r'\iff': '⇔',
    r'\in': ' dans ',
    r'\forall': 'pour tout ',
    r'\exists': 'il existe ',
    r'\partial': '∂',
    r'\alpha': 'α',
    r'\beta': 'β',
    r'\gamma': 'γ',
    r'\delta': 'δ',
    r'\Delta': 'Δ',
    r'\varepsilon': 'ε',
    r'\epsilon': 'ε',
    r'\lambda': 'λ',
    r'\mu': 'μ',
    r'\pi': 'π',
    r'\sigma': 'σ',
    r'\theta': 'θ',
    r'\omega': 'ω',
    r'\left': '',
    r'\right': '',
    r'\,': ' ',
    r'\;': ' ',
    r'\quad': '  ',
  };
  final keys = symbols.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final k in keys) {
    t = t.replaceAll(k, symbols[k]!);
  }
  return t
      .replaceAll(RegExp(r'\\[a-zA-Z]+'), '')
      .replaceAll('{', '')
      .replaceAll('}', '')
      .replaceAll(RegExp('[✓✔✅]'), '');
}

/// Builds a printable PDF from an assistant answer (### titles, lists,
/// paragraphs; Arabic lines right-to-left, French lines left-to-right).
Future<Uint8List> answerPdfBytes(String text, {String? title}) async {
  final arabic = pw.Font.ttf(
    await rootBundle.load('assets/fonts/SFArabic.ttf'),
  );
  // Inter covers French accents and the maths symbols used above.
  final latin = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
  );
  final latinBold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-SemiBold.ttf'),
  );
  final doc = pw.Document();
  final arabicChar = RegExp(r'[\u0600-\u06FF]');
  // Arabic is only joined in right-to-left runs: any Arabic word makes the
  // line right-to-left.
  pw.TextDirection dirOf(String line) =>
      arabicChar.hasMatch(line) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  pw.TextStyle style(bool heading) => pw.TextStyle(
    fontSize: heading ? 13 : 11,
    fontWeight: heading ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: heading ? PdfColor.fromInt(0xFF2F5BD3) : PdfColors.black,
    lineSpacing: 3,
  );

  // The PDF library reverses French and maths inside right-to-left text, so
  // a mixed line is laid out as runs: consecutive Arabic words in one
  // right-to-left run, consecutive other words in one left-to-right run.
  List<({String text, bool rtl})> scriptRuns(String line) {
    final runs = <({String text, bool rtl})>[];
    final latinLetter = RegExp(r'[A-Za-zÀ-ÿ]');
    // Arabic letters only: a word ending in an Arabic comma stays French.
    final arabicLetter = RegExp(r'[\u0621-\u064A\u0671-\u06D3]');
    var words = <String>[];
    bool? rtl;
    for (final word in line.split(' ')) {
      if (word.isEmpty) {
        continue;
      }
      final kind = arabicLetter.hasMatch(word)
          ? true
          : latinLetter.hasMatch(word)
          ? false
          : rtl ?? false;
      if (rtl != null && kind != rtl && words.isNotEmpty) {
        runs.add((text: words.join(' '), rtl: rtl));
        words = [];
      }
      rtl = kind;
      words.add(word);
    }
    if (words.isNotEmpty) {
      runs.add((text: words.join(' '), rtl: rtl ?? true));
    }
    return runs;
  }

  final heading = RegExp(r'^\s*#{1,6}\s+');
  final bullet = RegExp(r'^\s*[-*•]\s+');
  final widgets = <pw.Widget>[];
  if (title != null) {
    widgets
      ..add(
        pw.Text(
          title,
          textDirection: pw.TextDirection.rtl,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      )
      ..add(pw.SizedBox(height: 8));
  }
  for (final raw in plainMaths(text).split('\n')) {
    final line = raw.trimRight().replaceAll('**', '');
    if (line.trim().isEmpty) {
      widgets.add(pw.SizedBox(height: 5));
      continue;
    }
    final h = heading.firstMatch(line);
    final b = bullet.firstMatch(line);
    final body = h != null
        ? line.substring(h.end)
        : b != null
        ? '•  ${line.substring(b.end)}'
        : line;
    final dir = dirOf(body);
    widgets.add(
      pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.only(top: h != null ? 10 : 2, bottom: 2),
        decoration: h != null
            ? const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.blue200, width: 0.6),
                ),
              )
            : null,
        child: dir == pw.TextDirection.ltr
            ? pw.Text(body, style: style(h != null))
            : pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (final run in scriptRuns(body))
                      pw.Text(
                        run.text,
                        textDirection: run.rtl
                            ? pw.TextDirection.rtl
                            : pw.TextDirection.ltr,
                        style: style(h != null),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      theme: pw.ThemeData.withFont(
        base: arabic,
        bold: arabic,
        fontFallback: [latin, latinBold],
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          'Epsilon Education  -  ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      ),
      build: (context) => widgets,
    ),
  );
  return doc.save();
}

/// An assistant answer: short Markdown (### titles, numbered and bulleted
/// lines, **bold**) with LaTeX maths in $...$ and $$...$$.
class MathAnswer extends StatelessWidget {
  const MathAnswer({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontSize: 10, height: 1.7, color: Eps.ink);
    final source = text
        .replaceAll(r'\[', r'$$')
        .replaceAll(r'\]', r'$$')
        .replaceAll(r'\(', r'$')
        .replaceAll(r'\)', r'$');
    // Keep $$...$$ blocks whole, even when they span several lines.
    final blocks = <String>[];
    final buffer = StringBuffer();
    var inDisplay = false;
    for (final line in source.split('\n')) {
      final marks = r'$$'.allMatches(line).length;
      if (inDisplay) {
        buffer.write('\n$line');
        if (marks.isOdd) {
          blocks.add(buffer.toString());
          buffer.clear();
          inDisplay = false;
        }
      } else if (marks.isOdd) {
        buffer.write(line);
        inDisplay = true;
      } else {
        blocks.add(line);
      }
    }
    if (buffer.isNotEmpty) {
      blocks.add(buffer.toString());
    }
    final heading = RegExp(r'^\s*#{1,6}\s+');
    final bullet = RegExp(r'^\s*[-*•]\s+');
    final boldLine = RegExp(r'^\s*\*\*[^*]+\*\*\s*:?\s*$');
    final children = <Widget>[];
    for (final raw in blocks) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 4));
        continue;
      }
      final h = heading.firstMatch(line);
      if (h != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: MathText(
              line.substring(h.end).replaceAll('**', ''),
              // Whole formulas, so right-to-left text never reorders
              // their parts.
              wrap: false,
              style: base.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Eps.blue,
              ),
            ),
          ),
        );
        continue;
      }
      final b = bullet.firstMatch(line);
      final body = b == null ? line : '•  ${line.substring(b.end)}';
      children.add(
        MathText(
          body.replaceAll('**', ''),
          wrap: false,
          style: boldLine.hasMatch(body)
              ? base.copyWith(fontWeight: FontWeight.w800)
              : base,
        ),
      );
    }
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// First-run study profile (Figma: setup).
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const universities = [
    'جامعة نواكشوط',
    'جامعة العلوم والتكنولوجيا والطب',
    'الجامعة الإسلامية بلعيون',
    'المدرسة العليا متعددة التقنيات',
    'أخرى',
  ];
  static const faculties = ['FST', 'الاقتصاد', 'أخرى'];
  static const tracks = ['MPI', 'PC', 'MPIC'];

  String? university;
  String faculty = 'FST';
  String track = 'MPI';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final p = LearnScope.read(context).profile;
    if (universities.contains(p?.university)) {
      university = p!.university;
    }
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await LearnScope.read(context).saveProfile({
        'university': university ?? '',
        'faculty': faculty,
        'track': track,
        'profile_completed': true,
      });
      widget.onDone();
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget choices(
    List<String> items,
    String value,
    ValueChanged<String> onPick, {
    double height = 43,
  }) => Row(
    children: [
      for (final item in items) ...[
        Expanded(
          child: GestureDetector(
            onTap: () => onPick(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item == value ? Eps.blueSoft : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: item == value ? Eps.blue2 : const Color(0xFFDFE4ED),
                  width: item == value ? 1.5 : 1,
                ),
              ),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: item == value ? Eps.blue : Eps.ink,
                ),
              ),
            ),
          ),
        ),
        if (item != items.last) const SizedBox(width: 7),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
          children: [
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Eps.blue, Color(0xFF5B83E6)],
                  ),
                  boxShadow: Eps.buttonShadow,
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: EpsBadge('الخطوة الأخيرة', tone: EpsTone.orange),
            ),
            const SizedBox(height: 8),
            const Text(
              'أخبرنا عن دراستك',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, color: Eps.ink),
            ),
            const Text(
              'سنخصص المحتوى والمواد المقترحة بناءً على اختياراتك.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, color: Eps.muted),
            ),
            const AuthLabel('الجامعة', top: 24),
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFDFE4ED)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: university,
                  isExpanded: true,
                  hint: const Text(
                    'اختر الجامعة',
                    style: TextStyle(fontSize: 10),
                  ),
                  style: const TextStyle(
                    fontFamily: Eps.font,
                    fontSize: 10,
                    color: Eps.ink,
                  ),
                  items: [
                    for (final u in universities)
                      DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: (v) => setState(() => university = v),
                ),
              ),
            ),
            const AuthLabel('الكلية', top: 14),
            choices(faculties, faculty, (v) => setState(() => faculty = v)),
            const AuthLabel('المسار', top: 14),
            choices(tracks, track, (v) => setState(() => track = v)),
            const SizedBox(height: 22),
            EpsPrimaryButton(
              label: 'إنهاء الإعداد',
              icon: Icons.check_rounded,
              loading: saving,
              onPressed: university == null ? null : save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Free account ready (Figma: welcome).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({required this.onStart, super.key});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final name = StoreScope.of(context).currentUser?.name ?? '';
    const features = [
      (Icons.sensors_rounded, 'البث المباشر المجاني'),
      (Icons.description_outlined, 'ملفات PDF مختارة'),
    ];
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 70, 22, 32),
          children: [
            Center(
              child: Container(
                width: 128,
                height: 128,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE8EFFC),
                ),
                child: const Center(child: EpsLogo(size: 92)),
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: EpsBadge('الخطة المجانية', tone: EpsTone.green),
            ),
            const SizedBox(height: 10),
            Text(
              'مرحباً $name! 🎉',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, color: Eps.ink),
            ),
            const Text(
              'حسابك المجاني جاهز',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Eps.blue),
            ),
            const Text(
              'يمكنك الآن البدء بالتعلم والوصول إلى المحتوى المجاني في جميع المواد.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, color: Eps.muted),
            ),
            const SizedBox(height: 18),
            for (final (icon, label) in features)
              Container(
                height: 50,
                margin: const EdgeInsets.only(bottom: 8),
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
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Eps.ink,
                        ),
                      ),
                    ),
                    const Icon(Icons.check_rounded, color: Eps.green, size: 17),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            EpsPrimaryButton(
              label: 'اختر موادي',
              icon: Icons.chevron_right_rounded,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shrinks a picked photo to a 256px square-ish PNG so it stays small.
Future<String> avatarDataUri(Uint8List bytes) =>
    shrinkImageDataUri(bytes, width: 256);

/// Re-encodes a photo at most [width] pixels wide, as a PNG data URI.
Future<String> shrinkImageDataUri(Uint8List bytes, {required int width}) async {
  final probe = await ui.instantiateImageCodec(bytes);
  final first = await probe.getNextFrame();
  final original = first.image.width;
  first.image.dispose();
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: original > width ? width : null,
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  final png = data!.buffer.asUint8List();
  return 'data:image/png;base64,${base64Encode(png)}';
}
