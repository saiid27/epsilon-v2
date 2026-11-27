part of '../main.dart';

/// What a student orders for a section's feature.
class SectionFeatureOrder {
  const SectionFeatureOrder({
    required this.courseId,
    required this.feature,
    required this.amount,
  });

  final String courseId;
  final String feature;
  final int amount;
}

/// The features of a section, in the order the screen shows them:
/// key, name, short description, icon and tint.
const _sectionFeatures = [
  (
    'groups',
    'مجموعات المواد',
    'محادثة كل مادة مع أستاذها، تختار مادة أو أكثر',
    Icons.groups_rounded,
    Color(0xFFEAF0FD),
  ),
  (
    'videos',
    'الفيديوهات المسجلة',
    'شروحات مسجلة للمواد',
    Icons.play_circle_rounded,
    Color(0xFFFFF1E6),
  ),
  (
    'live',
    'البث المباشر',
    'حصص مباشرة مع الأساتذة',
    Icons.sensors_rounded,
    Color(0xFFFDE8EE),
  ),
  (
    'assistant',
    'مساعد Epsilon AI',
    'مساعد ذكي للدراسة في هذا القسم',
    Icons.auto_awesome_rounded,
    Color(0xFFE6F6EE),
  ),
];

const _notActivated = 'لم تفعل بعد لهذا القسم';

/// A subject has the content of a feature: a recorded video or a live session.
bool _subjectHasFeature(LearnStore learn, String feature, String subjectId) {
  if (feature == 'videos') {
    return learn.lessonsFor(subjectId).any((l) => l.url.isNotEmpty);
  }
  if (feature == 'live') {
    return learn.liveFor(subjectId).isNotEmpty;
  }
  return false;
}

/// One section: its features with their own prices and subscriptions.
class SectionScreen extends StatelessWidget {
  const SectionScreen({required this.courseId, required this.title, super.key});

  final String courseId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final section = learn.sectionById(courseId);
    final prices = section?.featurePrices ?? const <String, int>{};
    final subjects = learn.subjects
        .where((s) => s.courseId == courseId)
        .toList();
    return EpsPage(
      title: title,
      children: [
        if ((section?.description ?? '').isNotEmpty)
          Text(
            section!.description,
            style: const TextStyle(fontSize: 11, color: Eps.muted),
          ),
        const SizedBox(height: 12),
        for (final (key, name, desc, icon, tint) in _sectionFeatures)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FeatureCard(
              courseId: courseId,
              sectionTitle: title,
              feature: key,
              name: name,
              description: desc,
              icon: icon,
              tint: tint,
              price: prices[key] ?? 0,
              subjects: subjects,
            ),
          ),
        FlatCard(
          onTap: () => pushPage(
            context,
            CatalogScreen(courseId: courseId, title: title),
          ),
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              const Icon(Icons.library_books_rounded, color: Eps.blue),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'المواد والاشتراك الكامل',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Eps.ink,
                  ),
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: Eps.muted),
            ],
          ),
        ),
      ],
    );
  }
}

/// A feature's card: its state, price, the subjects that have it, and the
/// subscribe button.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.courseId,
    required this.sectionTitle,
    required this.feature,
    required this.name,
    required this.description,
    required this.icon,
    required this.tint,
    required this.price,
    required this.subjects,
  });

  final String courseId;
  final String sectionTitle;
  final String feature;
  final String name;
  final String description;
  final IconData icon;
  final Color tint;
  final int price;
  final List<EpsSubject> subjects;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final groupsOn = subjects.any((s) => s.groupPrice > 0);
    // Groups are priced per subject; the other features per section.
    final available = feature == 'groups' ? groupsOn : price > 0;
    final active = learn.featureSubs
        .where(
          (f) => f.courseId == courseId && f.feature == feature && f.isActive,
        )
        .firstOrNull;
    final pending = learn.featureSubs
        .where(
          (f) => f.courseId == courseId && f.feature == feature && f.isPending,
        )
        .firstOrNull;
    final bought = feature == 'groups'
        ? subjects.where((s) => learn.hasGroupAccess(s.id)).length
        : 0;

    final String status;
    final Color statusColor;
    if (!available) {
      status = _notActivated;
      statusColor = Eps.orangeInk;
    } else if (feature == 'groups' && bought > 0) {
      status = '✓ اشتركت في $bought من ${subjects.length} مواد';
      statusColor = Eps.green;
    } else if (active != null) {
      status = '✓ مفعّلة';
      statusColor = Eps.green;
    } else if (pending != null) {
      status = 'قيد المراجعة';
      statusColor = Eps.orangeInk;
    } else if (feature == 'groups') {
      status = 'تختار مجموعة كل مادة بسعرها';
      statusColor = Eps.muted;
    } else {
      status = '${formatMru(price)} MRU / شهر';
      statusColor = Eps.blue;
    }

    final showButton = available && active == null && pending == null;
    final perSubject = feature == 'videos' || feature == 'live';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Eps.radius),
        boxShadow: Eps.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Eps.blue, size: 20),
              ),
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
                    Text(
                      description,
                      style: const TextStyle(fontSize: 10.5, color: Eps.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: statusColor,
            ),
          ),
          if (perSubject && available) ...[
            const SizedBox(height: 8),
            for (final s in subjects)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.displayName,
                        style: const TextStyle(fontSize: 12, color: Eps.ink),
                      ),
                    ),
                    _subjectHasFeature(learn, feature, s.id)
                        ? const Text(
                            '✓ متوفر',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Eps.green,
                            ),
                          )
                        : const Text(
                            _notActivated,
                            style: TextStyle(
                              fontSize: 10,
                              color: Eps.orangeInk,
                            ),
                          ),
                  ],
                ),
              ),
          ],
          if (perSubject && !available) ...[
            const SizedBox(height: 4),
            const Text(
              _notActivated,
              style: TextStyle(fontSize: 10, color: Eps.orangeInk),
            ),
          ],
          if (showButton) ...[
            const SizedBox(height: 10),
            EpsPrimaryButton(
              label: feature == 'groups'
                  ? 'اختر المجموعات'
                  : 'اشترك · ${formatMru(price)} MRU / شهر',
              icon: feature == 'groups'
                  ? Icons.chevron_left_rounded
                  : Icons.shopping_bag_outlined,
              color: Eps.navy,
              onPressed: () {
                if (feature == 'groups') {
                  pushPage(context, GroupsCatalogScreen(courseId: courseId));
                  return;
                }
                pushPage(
                  context,
                  SectionFeatureCheckoutScreen(
                    courseId: courseId,
                    sectionTitle: sectionTitle,
                    feature: feature,
                    name: name,
                    description: description,
                    price: price,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Buying one feature of a section: its price, what it includes, and payment.
class SectionFeatureCheckoutScreen extends StatefulWidget {
  const SectionFeatureCheckoutScreen({
    required this.courseId,
    required this.sectionTitle,
    required this.feature,
    required this.name,
    required this.description,
    required this.price,
    super.key,
  });

  final String courseId;
  final String sectionTitle;
  final String feature;
  final String name;
  final String description;
  final int price;

  @override
  State<SectionFeatureCheckoutScreen> createState() =>
      _SectionFeatureCheckoutScreenState();
}

class _SectionFeatureCheckoutScreenState
    extends State<SectionFeatureCheckoutScreen> {
  String? methodId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final methods = store.paymentMethods;
    methodId ??= methods.firstOrNull?.id;
    final method = methods.where((m) => m.id == methodId).firstOrNull;

    return EpsPage(
      title: widget.name,
      bottom: EpsPrimaryButton(
        label: 'تم التحويل، رفع الوصل',
        icon: Icons.upload_rounded,
        onPressed: method == null
            ? null
            : () => pushPage(
                context,
                ReceiptUploadScreen(
                  paymentMethodId: method.id,
                  featureOrder: SectionFeatureOrder(
                    courseId: widget.courseId,
                    feature: widget.feature,
                    amount: widget.price,
                  ),
                ),
              ),
      ),
      children: [
        Text(
          widget.sectionTitle,
          style: const TextStyle(fontSize: 11, color: Eps.muted),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Eps.blueSoft,
            borderRadius: BorderRadius.circular(Eps.radius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.description,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Eps.ink,
                  ),
                ),
              ),
              Text(
                '${formatMru(widget.price)} MRU / شهر',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Eps.blue,
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
