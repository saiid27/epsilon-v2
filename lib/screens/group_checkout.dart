part of '../main.dart';

/// Buying the group of one subject alone: its own price, what it includes,
/// and the payment. The lessons and files are not part of it.
class GroupCheckoutScreen extends StatefulWidget {
  const GroupCheckoutScreen({required this.subject, super.key});

  final EpsSubject subject;

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
    final s = widget.subject;
    final methods = store.paymentMethods;
    methodId ??= methods.firstOrNull?.id;
    final method = methods.where((m) => m.id == methodId).firstOrNull;
    final price = s.groupPrice;
    final available = price > 0;

    return EpsPage(
      title: 'مجموعة المادة',
      bottom: EpsPrimaryButton(
        label: available ? 'تم التحويل، رفع الوصل' : 'الاشتراك غير متوفر',
        icon: Icons.upload_rounded,
        onPressed: method == null || !available
            ? null
            : () => pushPage(
                context,
                ReceiptUploadScreen(
                  paymentMethodId: method.id,
                  groupSubject: s,
                ),
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
              _GroupLogo(name: s.displayName, color: s.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Eps.ink,
                      ),
                    ),
                    if (s.nameFr.isNotEmpty)
                      Text(
                        s.name,
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
                  'سعر المجموعة',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Eps.ink,
                  ),
                ),
              ),
              Text(
                available ? '${formatMru(price)} MRU / شهر' : 'غير متوفر',
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
