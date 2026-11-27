part of '../main.dart';

/// Buying one group: its price (set by the admin), what it includes, and payment.
class GroupCheckoutScreen extends StatefulWidget {
  const GroupCheckoutScreen({required this.group, super.key});

  final EpsChatGroup group;

  @override
  State<GroupCheckoutScreen> createState() => _GroupCheckoutScreenState();
}

class _GroupCheckoutScreenState extends State<GroupCheckoutScreen> {
  String? methodId;

  static const _included = [
    'محادثة المجموعة مع الأستاذ',
    'الأسئلة والأجوبة والاستطلاعات',
    'الصور والرسائل الصوتية والفيديو من الأستاذ',
  ];
  static const _excluded = [
    'الدروس والشروحات',
    'الملفات والمرفقات',
    'الاختبارات والمكالمات المباشرة',
  ];

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final learn = LearnScope.of(context);
    final g = widget.group;
    final subject = learn.subjectById(g.subjectId);
    final name = g.name.isNotEmpty ? g.name : (subject?.displayName ?? '');
    final methods = store.paymentMethods;
    methodId ??= methods.firstOrNull?.id;
    final method = methods.where((m) => m.id == methodId).firstOrNull;
    final available = g.price > 0;

    return EpsPage(
      title: 'مجموعة',
      bottom: EpsPrimaryButton(
        label: available ? 'تم التحويل، رفع الوصل' : 'الاشتراك غير متوفر',
        icon: Icons.upload_rounded,
        onPressed: method == null || !available
            ? null
            : () => pushPage(
                context,
                ReceiptUploadScreen(paymentMethodId: method.id, groupOrder: g),
              ),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Eps.radius),
            boxShadow: Eps.cardShadow,
          ),
          child: Row(
            children: [
              _GroupLogo(name: name, color: subject?.color ?? Eps.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Eps.ink,
                      ),
                    ),
                    if (subject != null)
                      Text(
                        subject.displayName,
                        style: const TextStyle(fontSize: 11, color: Eps.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Eps.blueSoft,
            borderRadius: BorderRadius.circular(Eps.radius),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'سعر الاشتراك',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Eps.ink,
                  ),
                ),
              ),
              Text(
                available ? '${formatMru(g.price)} MRU / شهر' : 'غير متوفر',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Eps.blue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'ما تشمله',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Eps.ink,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in _included)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Eps.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 12, color: Eps.ink),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'لا تشمله',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Eps.ink,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in _excluded)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 16,
                  color: Eps.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 12, color: Eps.muted),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        const Text(
          'طريقة الدفع',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Eps.ink,
          ),
        ),
        const SizedBox(height: 8),
        for (final m in methods)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PaymentMethodTile(
              method: m,
              selected: m.id == methodId,
              onTap: () => setState(() => methodId = m.id),
            ),
          ),
      ],
    );
  }
}

/// The groups of the sections: each subject's groups, with the price of each.
/// Opened from a section, it shows that section's groups only.
class GroupsCatalogScreen extends StatelessWidget {
  const GroupsCatalogScreen({this.courseId, super.key});

  final String? courseId;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final subjects = learn.subjects
        .where((s) => courseId == null || s.courseId == courseId)
        .toList();
    return EpsPage(
      title: 'المجموعات',
      children: [
        const Text(
          'اختر المجموعة التي تريدها، واشترك في كل مجموعة على حدة.',
          style: TextStyle(fontSize: 10, color: Eps.muted),
        ),
        const SizedBox(height: 12),
        for (final s in subjects) ...[
          if (learn.chatGroups.any((g) => g.subjectId == s.id)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                s.displayName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Eps.ink,
                ),
              ),
            ),
            for (final g in learn.chatGroups.where((g) => g.subjectId == s.id))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GroupRow(group: g, subject: s),
              ),
          ],
        ],
      ],
    );
  }
}

/// One group: its price and whether the student has paid for it.
class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.subject});

  final EpsChatGroup group;
  final EpsSubject subject;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final g = group;
    final name = g.name.isNotEmpty ? g.name : subject.displayName;
    final has = learn.canOpenGroup(g);
    final available = g.price > 0;
    final String note;
    final Color noteColor;
    if (has) {
      note = 'مشترك في هذه المجموعة';
      noteColor = Eps.green;
    } else if (!available) {
      note = 'لم تفعل بعد لهذا القسم';
      noteColor = Eps.orangeInk;
    } else {
      note = '${formatMru(g.price)} MRU / شهر';
      noteColor = Eps.muted;
    }
    return FlatCard(
      padding: const EdgeInsets.all(12),
      onTap: has || !available
          ? null
          : () => pushPage(context, GroupCheckoutScreen(group: g)),
      child: Row(
        children: [
          _GroupLogo(name: name, color: subject.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Eps.ink,
                  ),
                ),
                Text(note, style: TextStyle(fontSize: 11, color: noteColor)),
              ],
            ),
          ),
          if (has)
            const Icon(Icons.check_circle_rounded, color: Eps.green)
          else if (available)
            const Icon(Icons.chevron_left_rounded, color: Eps.blue),
        ],
      ),
    );
  }
}
