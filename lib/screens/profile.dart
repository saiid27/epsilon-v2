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
              icon: Icons.calendar_month_outlined,
              title: 'جدولي الجامعي',
              subtitle: 'حصص غداً تُرسل لك كل ليلة الساعة 9 مساءً',
              onTap: () => pushPage(context, const TimetableScreen()),
            ),
            _MenuRow(
              icon: Icons.card_giftcard_outlined,
              title: 'ادعُ صديقاً',
              subtitle: 'كودك: ${profile?.referralCode ?? ''}',
              onTap: () => pushPage(context, const ReferralScreen()),
            ),
            _MenuRow(
              icon: Icons.calculate_outlined,
              title: 'حاسبة المعدل',
              subtitle: 'احسب معدلك وما تحتاجه في الاستدراك',
              onTap: () => pushPage(context, const GpaScreen()),
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
      title: tr('الإعدادات', 'Paramètres'),
      children: [
        head(tr('التفضيلات', 'Préférences')),
        _MenuRow(
          icon: Icons.translate_rounded,
          title: tr('اللغة', 'Langue'),
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
        head(tr('المساعدة', 'Aide')),
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
  /// Share of today's and this month's allowance left (0 to 100).
  static const fullAllowance = 100;
  final input = TextEditingController();
  final messages = <({bool me, String text, Uint8List? image, String? file})>[];

  /// Credit left (daily allowance; unused credit carries over).
  int dailyLeft = fullAllowance;
  int monthlyLeft = fullAllowance;
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
    ('fiche', 'ورقة مراجعة', Icons.summarize_outlined),
    ('exam', 'امتحان تجريبي', Icons.timer_outlined),
    ('plan', 'خطة مراجعة', Icons.event_note_outlined),
    ('french', 'فرنسية أكاديمية', Icons.translate_rounded),
    ('pfe', 'مذكرة التخرج', Icons.school_outlined),
    ('code', 'البرمجة', Icons.code_rounded),
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
      setState(
        () => messages.add((
          me: false,
          text:
              'أحل وأشرح تمارينك${widget.lessonTitle == null ? '' : ' في درس «${widget.lessonTitle}»'}، وأشرح ملفات PDF، وأكتب سيرتك الذاتية ورسائلك وتقاريرك.\nاكتب، أو صوّر، أو أرفق ملفاً، أو تكلم.',
          image: null,
          file: null,
        )),
      );
      if (learn.enabled && learn.userId != null) {
        final balance = await learn.repo.assistantBalance(learn.userId!);
        if (balance != null && mounted) {
          setState(() {
            dailyLeft = balance.dailyLeftPct;
            monthlyLeft = balance.monthlyLeftPct;
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

  /// Attach menu: a photo of an exercise or a PDF file.
  void attachSheet() => showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: Eps.blue),
            title: const Text('صوّر التمرين'),
            onTap: () {
              Navigator.of(sheet).pop();
              pickPhoto();
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined, color: Eps.blue),
            title: const Text('أرفق ملف PDF'),
            onTap: () {
              Navigator.of(sheet).pop();
              pickPdf();
            },
          ),
        ],
      ),
    ),
  );

  /// Mode menu: full solution, hint, explanation, and the other modes.
  void chooseMode() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'رجوع',
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () => Navigator.of(sheet).pop(),
                ),
                const Expanded(
                  child: Text(
                    'اختر وضع المساعد',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final (code, label, icon) in modes)
                  ListTile(
                    leading: Icon(icon, color: Eps.blue),
                    title: Text(label),
                    trailing: code == mode
                        ? const Icon(Icons.check_rounded, color: Eps.blue)
                        : null,
                    onTap: () {
                      Navigator.of(sheet).pop();
                      setState(() => mode = code);
                      if (code == 'pdf' && pdf == null) {
                        pickPdf();
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  void say(String text) => setState(
    () => messages.add((me: false, text: text, image: null, file: null)),
  );

  Future<void> pickPdf() async {
    if (dailyLeft <= 0 || monthlyLeft <= 0) {
      say('نفد رصيدك من الاستعمال. يتجدد الرصيد اليومي غداً.');
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
    if (dailyLeft <= 0 || monthlyLeft <= 0) {
      say('نفد رصيدك من الاستعمال. يتجدد الرصيد اليومي غداً.');
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
        'fiche' => 'حضّر ورقة مراجعة لهذا الملف',
        'explain' => 'اشرح المفهوم المستعمل في هذا التمرين',
        'practice' => 'أعطني تمارين مشابهة لهذا التمرين',
        _ => 'حل هذا التمرين خطوة بخطوة',
      };
    }
    if (q.isEmpty || thinking) {
      return;
    }
    if (dailyLeft <= 0 || monthlyLeft <= 0) {
      say('نفد رصيدك من الاستعمال. يتجدد الرصيد اليومي غداً.');
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
        dailyLeft = answer.dailyLeftPct ?? dailyLeft;
        monthlyLeft = answer.monthlyLeftPct ?? monthlyLeft;
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
    final assistantName = firstName(
      StoreScope.of(context).currentUser?.name ?? '',
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
            if (!learn.isSubscribed)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                  decoration: BoxDecoration(
                    color: Eps.blueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'الخطة المجانية: بقي لك $dailyLeft% من رصيد اليوم',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Eps.blue,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            pushPage(context, const AssistantPlansScreen()),
                        child: const Text(
                          'ترقية',
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
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
                          style: TextStyle(fontSize: 7, color: Eps.blue),
                        ),
                      ],
                    ),
                  ),
                  EpsBadge('اليوم $dailyLeft% • الشهر $monthlyLeft%'),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                    children: [
                      for (final m
                          in messages.length <= 1 && !thinking
                              ? messages.take(0)
                              : messages)
                        Align(
                          alignment: m.me
                              ? AlignmentDirectional.centerStart
                              : AlignmentDirectional.centerEnd,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: m.me ? 290 : 340,
                            ),
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
                  if (messages.length <= 1 && !thinking)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              assistantName.isEmpty
                                  ? 'مرحباً بعودتك'
                                  : 'مرحباً بعودتك يا $assistantName',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Eps.ink,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              messages.isEmpty ? '' : messages.first.text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                height: 1.9,
                                color: Eps.muted,
                              ),
                            ),
                          ],
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
                      tone: EpsTone.blue,
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
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Eps.blue.withAlpha(60)),
                boxShadow: Eps.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (listening)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        french ? 'Parlez maintenant…' : 'تكلم الآن…',
                        style: const TextStyle(fontSize: 9, color: Eps.blue),
                      ),
                    ),
                  TextField(
                    controller: input,
                    onSubmitted: ask,
                    minLines: 1,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 10, color: Eps.ink),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'اسأل مساعد إبسيلون...',
                      hintStyle: TextStyle(fontSize: 10, color: Eps.faint),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SoftIconButton(
                        icon: Icons.add_rounded,
                        tooltip: 'إضافة صورة أو ملف',
                        onTap: thinking ? null : attachSheet,
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: thinking ? null : chooseMode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Eps.blueSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                modes.firstWhere((m) => m.$1 == mode).$2,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Eps.blue,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.expand_more_rounded,
                                size: 16,
                                color: Eps.blue,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      SoftIconButton(
                        icon: listening
                            ? Icons.stop_rounded
                            : Icons.mic_none_rounded,
                        tooltip: 'اسأل بصوتك',
                        active: listening,
                        onTap: thinking ? null : toggleVoice,
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: thinking ? null : () => ask(input.text),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: thinking ? Eps.line : Eps.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
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

/// Invite a friend: the inviter gets 5 questions and 1 file for the
/// assistant once the friend's first subject subscription is active.
class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final code = learn.profile?.referralCode ?? '';
    return EpsPage(
      title: 'ادعُ صديقاً',
      children: [
        FlatCard(
          gradient: Eps.heroGradient,
          border: Colors.transparent,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 6),
              const Text(
                'شارك كودك مع صديقك',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                code.isEmpty ? 'سيظهر كودك قريباً' : code,
                style: const TextStyle(
                  fontFamily: Eps.fontNum,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const FlatCard(
          child: Text(
            'عندما يسجّل صديقك بكودك ويشترك في أي مادة لأول مرة، تحصل أنت على 5 أسئلة و1 ملف إضافي لمساعد إبسيلون، ويُضاف ذلك إلى رصيدك اليومي.',
            style: TextStyle(fontSize: 10, color: Eps.ink, height: 1.8),
          ),
        ),
        const SizedBox(height: 14),
        EpsPrimaryButton(
          label: 'شارك الكود',
          icon: Icons.share_outlined,
          onPressed: code.isEmpty
              ? null
              : () => share.SharePlus.instance.share(
                  share.ShareParams(
                    text:
                        'انضم إلى Epsilon Education واستعمل كودي $code عند التسجيل.',
                  ),
                ),
        ),
      ],
    );
  }
}

/// Academic average (LMD): weighted by each module's coefficient, validated
/// at 10/20. The official compensation rules are the university's.
class GpaScreen extends StatefulWidget {
  const GpaScreen({super.key});

  @override
  State<GpaScreen> createState() => _GpaScreenState();
}

class _GpaScreenState extends State<GpaScreen> {
  final rows =
      <
        ({
          TextEditingController name,
          TextEditingController note,
          TextEditingController coef,
        })
      >[];
  final remainingCoef = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 4; i++) {
      addRow();
    }
  }

  @override
  void dispose() {
    for (final r in rows) {
      r.name.dispose();
      r.note.dispose();
      r.coef.dispose();
    }
    remainingCoef.dispose();
    super.dispose();
  }

  void addRow() => setState(() {
    rows.add((
      name: TextEditingController(),
      note: TextEditingController(),
      coef: TextEditingController(text: '1'),
    ));
  });

  double? parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    var points = 0.0;
    var coef = 0.0;
    for (final r in rows) {
      final n = parse(r.note.text);
      final c = parse(r.coef.text);
      if (n != null && c != null && c > 0 && n >= 0 && n <= 20) {
        points += n * c;
        coef += c;
      }
    }
    final average = coef == 0 ? null : points / coef;
    final rem = parse(remainingCoef.text) ?? 0;
    // Average needed on the remaining modules to reach 10 overall.
    final needed = rem > 0 ? (10 * (coef + rem) - points) / rem : null;
    return EpsPage(
      title: 'حاسبة المعدل',
      children: [
        FlatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أدخل علامة كل مادة (من 20) ومعاملها. المعدل = مجموع (العلامة × المعامل) ÷ مجموع المعاملات.',
                style: TextStyle(fontSize: 9, color: Eps.muted, height: 1.7),
              ),
              const SizedBox(height: 10),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: r.name,
                          style: const TextStyle(fontSize: 10),
                          decoration: const InputDecoration(hintText: 'المادة'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: r.note,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(hintText: "من 20"),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: r.coef,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(hintText: "معامل"),
                        ),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: addRow,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('مادة أخرى'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FlatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                average == null
                    ? 'أدخل العلامات لترى معدلك'
                    : 'المعدل العام: ${average.toStringAsFixed(2)} / 20',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Eps.ink,
                ),
              ),
              if (average != null) ...[
                const SizedBox(height: 6),
                EpsBadge(
                  average >= 10
                      ? 'فوق 10: مؤشر نجاح (تأكد من قواعد جامعتك)'
                      : 'أقل من 10: تحتاج الدورة الاستدراكية',
                  tone: average >= 10 ? EpsTone.green : EpsTone.red,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        FlatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ما الذي تحتاجه في المواد المتبقية؟',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: remainingCoef,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'مجموع معاملات المواد المتبقية',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                needed == null
                    ? 'اكتب مجموع المعاملات المتبقية'
                    : needed <= 0
                    ? 'تكفيك أي علامة للوصول إلى 10'
                    : needed > 20
                    ? 'لا يمكن الوصول إلى 10 بهذه المعاملات'
                    : 'تحتاج معدلاً ${needed.toStringAsFixed(2)} على الأقل في المواد المتبقية',
                style: const TextStyle(
                  fontSize: 10,
                  color: Eps.blue,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One monthly or yearly assistant package. Prices are in MRU (the current
/// ouguiya) and are set here, in one place.
class AssistantPackage {
  const AssistantPackage({
    required this.name,
    required this.tagline,
    required this.monthly,
    required this.yearly,
    required this.questions,
    required this.files,
    required this.perks,
    this.highlight = false,
  });

  final String name;
  final String tagline;
  final int monthly;
  final int yearly;
  final int questions;
  final int files;
  final List<String> perks;
  final bool highlight;
}

const assistantPackages = [
  AssistantPackage(
    name: 'المبتدئ',
    tagline: 'للتعرّف على المساعد',
    monthly: 150,
    yearly: 1500,
    questions: 3,
    files: 1,
    perks: ['كل أوضاع المساعد', 'الصور وملفات PDF', 'حفظ الإجابات كملف PDF'],
  ),
  AssistantPackage(
    name: 'المتميز',
    tagline: 'الأكثر طلباً من الطلاب',
    monthly: 300,
    yearly: 3000,
    questions: 5,
    files: 2,
    perks: [
      'كل ما في المبتدئ',
      'السيرة الذاتية والرسائل والتقارير',
      'السؤال بالصوت بالعربية والفرنسية',
      'رصيد يتراكم حتى 7 أيام',
    ],
    highlight: true,
  ),
  AssistantPackage(
    name: 'الاحترافي',
    tagline: 'للطلاب في الماستر والمشاريع',
    monthly: 450,
    yearly: 4500,
    questions: 8,
    files: 3,
    perks: [
      'كل ما في المتميز',
      'مذكرة التخرج والبرمجة',
      'ضعف الرصيد اليومي',
      'أولوية في الرد',
    ],
  ),
];

/// Assistant packages (shown to students without an assistant package).
class AssistantPlansScreen extends StatefulWidget {
  const AssistantPlansScreen({super.key});

  @override
  State<AssistantPlansScreen> createState() => _AssistantPlansScreenState();
}

class _AssistantPlansScreenState extends State<AssistantPlansScreen> {
  bool yearly = false;

  @override
  Widget build(BuildContext context) {
    return EpsPage(
      title: 'مساعد إبسيلون',
      children: [
        FlatCard(
          shadow: false,
          border: Eps.blue,
          child: const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Eps.green, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'المجانية: حوالي 3 أسئلة يومياً أو صورة أو ملف صغير، بدون دفع.',
                  style: TextStyle(fontSize: 9, color: Eps.ink, height: 1.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: Eps.heroGradient,
          ),
          child: const Column(
            children: [
              SizedBox(height: 6),
              Text(
                'مساعدك الدراسي الذكي',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'يحل تمارينك ويشرح الدروس وملفات PDF، ويكتب سيرتك الذاتية ورسائلك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFFD6E2FF),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('شهري')),
              ButtonSegment(value: true, label: Text('سنوي (شهران مجاناً)')),
            ],
            selected: {yearly},
            onSelectionChanged: (v) => setState(() => yearly = v.first),
          ),
        ),
        const SizedBox(height: 12),
        for (final p in assistantPackages)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PackageCard(package: p, yearly: yearly),
          ),
        const SizedBox(height: 4),
        const Text(
          'الأسعار بالأوقية الجديدة (MRU). الرصيد يتجدد يومياً، وما لا تستعمله يُضاف للغد حتى 7 أيام.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, color: Eps.muted, height: 1.6),
        ),
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package, required this.yearly});

  final AssistantPackage package;
  final bool yearly;

  @override
  Widget build(BuildContext context) {
    final p = package;
    final price = yearly ? p.yearly : p.monthly;
    final accent = p.highlight ? Eps.blue : Eps.ink;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: p.highlight ? Eps.blue : Eps.line,
          width: p.highlight ? 2 : 1,
        ),
        boxShadow: p.highlight ? Eps.cardShadow : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              if (p.highlight)
                const EpsBadge('الأكثر طلباً', tone: EpsTone.orange),
            ],
          ),
          Text(
            p.tagline,
            style: const TextStyle(fontSize: 9, color: Eps.muted),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$price',
                style: const TextStyle(
                  fontFamily: Eps.fontNum,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Eps.blue,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  yearly ? 'MRU / سنة' : 'MRU / شهر',
                  style: const TextStyle(fontSize: 9, color: Eps.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Eps.blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'رصيد استعمال شهري: ${(p.monthly * 2 / 3).round()} أوقية',
              style: const TextStyle(
                fontSize: 10,
                color: Eps.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final perk in p.perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: Eps.green,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      perk,
                      style: const TextStyle(fontSize: 10, color: Eps.ink),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          EpsPrimaryButton(
            label: 'اختر ${p.name}',
            color: p.highlight ? Eps.blue : Eps.ink,
            onPressed: () => pushPage(
              context,
              AssistantCheckoutScreen(package: p, yearly: yearly),
            ),
          ),
        ],
      ),
    );
  }
}

/// Files shared by students of the same specialty, plus the student's own
/// uploads and their review status.
class StudentFilesScreen extends StatefulWidget {
  const StudentFilesScreen({super.key});

  @override
  State<StudentFilesScreen> createState() => _StudentFilesScreenState();
}

class _StudentFilesScreenState extends State<StudentFilesScreen> {
  List<EpsStudentFile> shared = [];
  List<EpsStudentFile> mine = [];
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  /// Faculty names in the order of the list, and their labels.
  List<String> facultyOrder = [];
  Map<String, String> facultyLabels = {};
  String? faculty;
  String? track;

  Future<void> load() async {
    final learn = LearnScope.read(context);
    final userId = learn.userId;
    if (!learn.enabled || userId == null) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final everything = await learn.repo.studentFiles();
      final mineList = await learn.repo.myStudentFiles(userId);
      final faculties = await learn.repo.approvedFaculties();
      if (mounted) {
        setState(() {
          shared = everything;
          mine = mineList;
          facultyOrder = [for (final f in faculties) f.name];
          facultyLabels = {for (final f in faculties) f.name: f.label};
          loading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  /// Files grouped by faculty first, then, inside the chosen faculty, by
  /// track. The student's own faculty opens first.
  /// The archive as a library: faculties first, then the track, then files.
  List<Widget> _sharedByFacultyThenTrack() {
    final learn = LearnScope.read(context);
    final profileFaculty = learn.profile?.faculty ?? '';
    // Known faculties first; the offline list keeps the grid from being empty.
    final labels = facultyLabels.isNotEmpty
        ? facultyLabels
        : const {
            'FST': 'كلية العلوم والتقنيات',
            'LAW': 'كلية القانون',
            'ECO': 'كلية الاقتصاد',
            'FLSH': 'كلية الآداب والعلوم الإنسانية',
            'MED': 'كلية الطب',
          };
    final codes = <String>{
      ...facultyOrder,
      ...labels.keys,
      for (final f in shared)
        if (f.faculty.isNotEmpty) f.faculty,
    }.toList();
    int countFor(String code) => shared.where((f) => f.faculty == code).length;

    // Step 1: the faculty grid (shown even when a faculty has no files yet).
    if (faculty == null) {
      return [
        const Text(
          'اختر كليتك لتتصفح ملفاتها',
          style: TextStyle(fontSize: 10, color: Eps.muted),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.25,
          children: [
            for (final code in codes)
              _LibraryCard(
                title: labels[code] ?? code,
                subtitle: '${countFor(code)} ملف',
                highlighted: code == profileFaculty,
                onTap: () => setState(() {
                  faculty = code;
                  track = null;
                }),
              ),
          ],
        ),
      ];
    }

    final chosen = faculty!;
    final chosenName = labels[chosen] ?? chosen;
    final tracks = <String>{
      if (chosen == 'MED') ..._StudentFileUploadScreenState.medicineTracks,
      for (final f in shared)
        if (f.faculty == chosen && f.track.isNotEmpty) f.track,
    }.toList();
    final back = Row(
      children: [
        IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_forward_rounded, color: Eps.blue),
          onPressed: () => setState(() {
            if (track != null) {
              track = null;
            } else {
              faculty = null;
            }
          }),
        ),
        Expanded(
          child: Text(
            track == null ? chosenName : '$chosenName • $track',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );

    // Step 2: the tracks of the chosen faculty.
    if (track == null) {
      return [
        back,
        const SizedBox(height: 6),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _LibraryCard(
              title: 'كل التخصصات',
              subtitle:
                  '${shared.where((f) => f.faculty == chosen).length} ملف',
              highlighted: false,
              onTap: () => setState(() => track = '*'),
            ),
            for (final t in tracks)
              _LibraryCard(
                title: t,
                subtitle:
                    '${shared.where((f) => f.faculty == chosen && f.track == t).length} ملف',
                highlighted: false,
                onTap: () => setState(() => track = t),
              ),
          ],
        ),
      ];
    }

    // Step 3: the files of the chosen faculty and track.
    final files = [
      for (final f in shared)
        if (f.faculty == chosen && (track == '*' || f.track == track)) f,
    ];
    return [
      back,
      const SizedBox(height: 8),
      if (files.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'لا توجد ملفات في هذا القسم بعد.',
            style: TextStyle(fontSize: 10, color: Eps.muted),
          ),
        ),
      for (final f in files) _StudentFileTile(file: f),
    ];
  }

  Future<void> upload() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const StudentFileUploadScreen()),
    );
    if (sent == true) {
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final profile = learn.profile;
    final specialty = [
      if (profile?.faculty.isNotEmpty ?? false) profile!.faculty,
      if (profile?.track.isNotEmpty ?? false) profile!.track,
      if (profile?.level.isNotEmpty ?? false) profile!.level,
    ].join(' • ');
    return EpsPage(
      title: 'الأرشيف',
      action: EpsIconButton(
        icon: Icons.refresh_rounded,
        tooltip: 'تحديث',
        onTap: load,
      ),
      children: [
        FlatCard(
          child: Text(
            specialty.isEmpty
                ? 'شارك ملاحظاتك وملفات مراجعتك مع زملائك. تُعرض الملفات بعد مراجعة الإدارة، سيتم زيادة رصيد المساعد لديك فقط عند القبول.'
                : 'ملفات زملائك في $specialty. شارك ملفاتك سيتم زيادة رصيد المساعد لديك فقط عند قبولها.',
            style: const TextStyle(fontSize: 10, color: Eps.ink, height: 1.7),
          ),
        ),
        const SizedBox(height: 10),
        EpsPrimaryButton(
          label: 'ارفع ملفاً',
          icon: Icons.upload_file_rounded,
          onPressed: upload,
        ),
        const SizedBox(height: 14),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Eps.red, fontSize: 10))
        else ...[
          const HomeSectionTitle('الملفات المشتركة'),
          // The library always shows the faculties; empty ones say so inside.
          ..._sharedByFacultyThenTrack(),
          const SizedBox(height: 10),
          const HomeSectionTitle('ملفاتي'),
          if (mine.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'لم ترفع ملفات بعد.',
                style: TextStyle(fontSize: 10, color: Eps.muted),
              ),
            ),
          for (final f in mine) _StudentFileTile(file: f, mine: true),
        ],
      ],
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.title,
    required this.subtitle,
    required this.highlighted,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? Eps.blue : Eps.line,
              width: highlighted ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Eps.ink,
                  height: 1.4,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  color: highlighted ? Eps.blue : Eps.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentFileTile extends StatelessWidget {
  const _StudentFileTile({required this.file, this.mine = false});

  final EpsStudentFile file;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (file.status) {
      'approved' => ('مقبول', EpsTone.green),
      'rejected' => ('مرفوض', EpsTone.red),
      _ => ('قيد المراجعة', EpsTone.orange),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FlatCard(
        onTap: file.url.isEmpty || (mine && file.status != 'approved')
            ? null
            : () => launchUrl(
                Uri.parse(file.url),
                mode: LaunchMode.externalApplication,
              ),
        child: Row(
          children: [
            EpsMark(
              icon: file.isPdf
                  ? Icons.picture_as_pdf_rounded
                  : Icons.image_outlined,
              tone: file.isPdf ? EpsTone.red : EpsTone.blue,
              size: 40,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Eps.ink,
                    ),
                  ),
                  if (file.subjectName.isNotEmpty ||
                      file.description.isNotEmpty)
                    Text(
                      [
                        file.subjectName,
                        file.description,
                      ].where((x) => x.isNotEmpty).join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 8, color: Eps.muted),
                    ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      EpsBadge(label, tone: tone),
                      if (!mine) ...[
                        const SizedBox(width: 6),
                        Text(
                          'تحميلات ${file.downloads}',
                          style: const TextStyle(fontSize: 8, color: Eps.muted),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!mine || file.status == 'approved')
              const Icon(Icons.open_in_new_rounded, color: Eps.ink, size: 16),
          ],
        ),
      ),
    );
  }
}

/// Value of a dropdown that opens a text field to type a missing choice.
const addNewChoice = '__add_new__';

/// Upload a file. The student picks the faculty, the track and the subject
/// (or types one that is missing); the administration checks them before the
/// file is published, and the student confirms they own the rights to share it.
class StudentFileUploadScreen extends StatefulWidget {
  const StudentFileUploadScreen({super.key});

  @override
  State<StudentFileUploadScreen> createState() =>
      _StudentFileUploadScreenState();
}

class _StudentFileUploadScreenState extends State<StudentFileUploadScreen> {
  static const medicineTracks = ['الطب العام', 'الصيدلة', 'طب الأسنان'];
  static const defaultTracks = [
    'MPI',
    'PC',
    'MPIC',
    'SNV',
    'الإعلاميات',
    'الاقتصاد',
    'القانون',
  ];
  static const maxBytes = 7 * 1024 * 1024;

  final title = TextEditingController();
  final description = TextEditingController();
  final newFaculty = TextEditingController();
  final newTrack = TextEditingController();
  final newSubject = TextEditingController();
  String? faculty;
  String? track;
  String? subjectId;
  List<EpsFaculty> faculties = [];
  PickedNativeFile? picked;
  Uint8List? bytes;
  bool rights = false;
  bool sending = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final learn = LearnScope.read(context);
      if (!learn.enabled) {
        // Offline: the known faculties, so the list is never empty.
        setState(
          () => faculties = [
            for (final (name, label) in const [
              ('FST', 'كلية العلوم والتقنيات'),
              ('LAW', 'كلية القانون'),
              ('ECO', 'كلية الاقتصاد'),
              ('FLSH', 'كلية الآداب والعلوم الإنسانية'),
              ('MED', 'كلية الطب'),
            ])
              EpsFaculty.fromRow({
                'name': name,
                'label': label,
                'status': 'approved',
              }),
          ],
        );
        return;
      }
      try {
        final list = await learn.repo.approvedFaculties();
        if (mounted) {
          setState(() => faculties = list);
        }
      } on Object {
        // The student can still add a faculty.
      }
    });
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    newFaculty.dispose();
    newTrack.dispose();
    newSubject.dispose();
    super.dispose();
  }

  /// Choices offered: the defaults plus those already used in the catalog.
  List<String> optionsWith(List<String> defaults, Iterable<String> extra) {
    final seen = <String>{};
    return [
      for (final v in [...defaults, ...extra])
        if (v.trim().isNotEmpty && seen.add(v.trim())) v.trim(),
    ];
  }

  Future<void> pick({required bool pdf}) async {
    final file = pdf
        ? await NativeFilePicker.pickPdf()
        : await NativeFilePicker.pickImage();
    if (file == null) {
      return;
    }
    final data =
        NativeFilePicker.webFiles[file.path] ??
        await File(file.path).readAsBytes();
    if (data.length > maxBytes) {
      setState(() => error = 'الملف كبير جداً (الحد 7 ميغابايت).');
      return;
    }
    setState(() {
      picked = file;
      bytes = data;
      error = '';
    });
  }

  String get facultyValue =>
      faculty == addNewChoice ? newFaculty.text.trim() : (faculty ?? '');
  String get trackValue =>
      track == addNewChoice ? newTrack.text.trim() : (track ?? '');
  String get subjectName {
    if (subjectId == addNewChoice) {
      return newSubject.text.trim();
    }
    final learn = LearnScope.read(context);
    return learn.subjects.where((s) => s.id == subjectId).firstOrNull?.name ??
        '';
  }

  Future<void> send() async {
    final learn = LearnScope.read(context);
    final userId = learn.userId;
    final file = picked;
    final data = bytes;
    final chosenSubject = subjectId ?? '';
    if (title.text.trim().isEmpty) {
      setState(() => error = 'اكتب عنواناً للملف.');
      return;
    }
    if (facultyValue.isEmpty) {
      setState(() => error = 'اختر الكلية أو اكتب اسمها.');
      return;
    }
    if (faculty == addNewChoice && learn.enabled) {
      // A new faculty waits for the administration's approval.
      try {
        await learn.repo.suggestFaculty(facultyValue, userId ?? '');
      } on Object {
        // The file is still uploaded with the faculty typed.
      }
    }
    if (trackValue.isEmpty) {
      setState(() => error = 'اختر التخصص أو اكتب اسمه.');
      return;
    }
    if (subjectName.isEmpty) {
      setState(() => error = 'اختر المادة أو اكتب اسمها.');
      return;
    }
    if (file == null || data == null || userId == null) {
      setState(() => error = 'اختر ملفاً أولاً.');
      return;
    }
    if (!rights) {
      setState(() => error = 'أكّد أنك تملك حق مشاركة هذا الملف.');
      return;
    }
    setState(() {
      sending = true;
      error = '';
    });
    try {
      await learn.repo.uploadStudentFile(
        userId: userId,
        title: title.text,
        description: description.text,
        subjectId: chosenSubject == addNewChoice ? '' : chosenSubject,
        subjectName: subjectName,
        faculty: facultyValue,
        track: trackValue,
        level: '',
        bytes: data,
        fileName: file.name,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          sending = false;
          error = e is StateError ? e.message : 'تعذر الرفع: $e';
        });
      }
    }
  }

  DropdownMenuItem<String> addItem(String label) => DropdownMenuItem(
    value: addNewChoice,
    child: Text(label, style: const TextStyle(color: Eps.blue)),
  );

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    // Medicine is one faculty with its programmes as tracks.
    final trackOptions = facultyValue == 'MED' ? medicineTracks : defaultTracks;
    return EpsPage(
      title: 'رفع ملف',
      children: [
        const AuthLabel('عنوان الملف'),
        TextField(
          controller: title,
          decoration: const InputDecoration(
            hintText: 'مثال: ملخص الفصل الثالث',
          ),
        ),
        const AuthLabel('الكلية', top: 10),
        DropdownButtonFormField<String>(
          initialValue: faculty,
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'اختر الكلية'),
          items: [
            for (final f in faculties)
              DropdownMenuItem(value: f.name, child: Text(f.label)),
            addItem('+ كلية غير موجودة'),
          ],
          onChanged: (v) => setState(() {
            faculty = v;
            track = null;
          }),
        ),
        if (faculty == addNewChoice)
          TextField(
            controller: newFaculty,
            decoration: const InputDecoration(hintText: 'اكتب اسم الكلية'),
          ),
        const AuthLabel('التخصص', top: 10),
        DropdownButtonFormField<String>(
          initialValue: track,
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'اختر التخصص'),
          items: [
            for (final t in trackOptions)
              DropdownMenuItem(value: t, child: Text(t)),
            addItem('+ تخصص غير موجود'),
          ],
          onChanged: (v) => setState(() => track = v),
        ),
        if (track == addNewChoice)
          TextField(
            controller: newTrack,
            decoration: const InputDecoration(hintText: 'اكتب اسم التخصص'),
          ),
        const AuthLabel('المادة', top: 10),
        DropdownButtonFormField<String>(
          initialValue: subjectId,
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'اختر المادة'),
          items: [
            for (final sub in learn.subjects)
              DropdownMenuItem(value: sub.id, child: Text(sub.name)),
            addItem('+ مادة غير موجودة'),
          ],
          onChanged: (v) => setState(() => subjectId = v),
        ),
        if (subjectId == addNewChoice)
          TextField(
            controller: newSubject,
            decoration: const InputDecoration(hintText: 'اكتب اسم المادة'),
          ),
        const AuthLabel('وصف مختصر (اختياري)', top: 10),
        TextField(
          controller: description,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'ما الذي يحتويه الملف؟'),
        ),
        const AuthLabel('الملف', top: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => pick(pdf: true),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => pick(pdf: false),
                icon: const Icon(Icons.image_outlined),
                label: const Text('صورة'),
              ),
            ),
          ],
        ),
        if (picked != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              picked!.name,
              style: const TextStyle(fontSize: 9, color: Eps.muted),
            ),
          ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: rights,
          onChanged: (v) => setState(() => rights = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'أؤكد أن هذا الملف من إنتاجي أو أملك حق مشاركته، وأنه لا يخالف حقوق الأساتذة والجامعة.',
            style: TextStyle(fontSize: 9, height: 1.6),
          ),
        ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              error,
              style: const TextStyle(color: Eps.red, fontSize: 10),
            ),
          ),
        EpsPrimaryButton(
          label: 'سيتأكد الإدارة منه ويتم الرفع',
          loading: sending,
          onPressed: sending ? null : send,
        ),
        const SizedBox(height: 8),
        const Text(
          'تراجع الإدارة الكلية والتخصص والمادة قبل نشر الملف، وتصحح الاسم إن كان مكتوباً بشكل مختلف.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 8, color: Eps.muted, height: 1.6),
        ),
      ],
    );
  }
}

/// Round icon button of the assistant's input bar: soft blue, or solid blue
/// while active.
class SoftIconButton extends StatelessWidget {
  const SoftIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.tooltip = '',
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active ? Eps.blue : Eps.blueSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: active ? Colors.white : Eps.blue),
        ),
      ),
    );
  }
}
