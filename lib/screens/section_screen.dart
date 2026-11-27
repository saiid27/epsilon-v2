part of '../main.dart';

/// What a student orders for a section package.
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

/// One section: its two packages, and the groups of its subjects. A group
/// the student has not paid for is locked; tapping it opens its payment.
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
    final groups =
        [
          for (final g in learn.chatGroups)
            if (subjects.any((s) => s.id == g.subjectId)) g,
        ]..sort((a, b) {
          final ao = learn.canOpenGroup(a) ? 0 : 1;
          final bo = learn.canOpenGroup(b) ? 0 : 1;
          return ao.compareTo(bo);
        });
    return EpsPage(
      title: title,
      children: [
        if ((section?.description ?? '').isNotEmpty)
          Text(
            section!.description,
            style: const TextStyle(fontSize: 11, color: Eps.muted),
          ),
        const SizedBox(height: 12),
        _SectionPackageCard(
          courseId: courseId,
          sectionTitle: title,
          feature: 'pkg_groups',
          name: 'المجموعات',
          items: const [
            'PDF المواد',
            'البث المباشر والحصص المجدولة',
            'مجموعات المواد مع الأساتذة',
          ],
          icon: Icons.groups_rounded,
          tint: const Color(0xFFEAF0FD),
          price: prices['pkg_groups'] ?? 0,
          extra: _GroupsList(groups: groups, subjects: subjects),
        ),
        const SizedBox(height: 10),
        _SectionPackageCard(
          courseId: courseId,
          sectionTitle: title,
          feature: 'pkg_videos',
          name: 'الاشتراك',
          items: const ['الفيديوهات المسجلة', 'PDF المواد'],
          icon: Icons.play_circle_rounded,
          tint: const Color(0xFFFFF1E6),
          price: prices['pkg_videos'] ?? 0,
        ),
        const SizedBox(height: 10),
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

/// A section package: what it includes, its price, and its state.
class _SectionPackageCard extends StatelessWidget {
  const _SectionPackageCard({
    required this.courseId,
    required this.sectionTitle,
    required this.feature,
    required this.name,
    required this.items,
    required this.icon,
    required this.tint,
    required this.price,
    this.extra,
  });

  final String courseId;
  final String sectionTitle;
  final String feature;
  final String name;
  final List<String> items;
  final IconData icon;
  final Color tint;
  final int price;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
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
    final available = price > 0;

    final String status;
    final Color statusColor;
    if (!available) {
      status = 'لم تفعل بعد لهذا القسم';
      statusColor = Eps.orangeInk;
    } else if (active != null) {
      status = '✓ مفعّلة';
      statusColor = Eps.green;
    } else if (pending != null) {
      status = 'قيد المراجعة';
      statusColor = Eps.orangeInk;
    } else {
      status = '${formatMru(price)} MRU / شهر';
      statusColor = Eps.blue;
    }
    final showButton = available && active == null && pending == null;

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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Eps.blue, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Eps.ink,
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Icon(
                    active != null
                        ? Icons.check_circle_rounded
                        : Icons.check_rounded,
                    size: 15,
                    color: Eps.green,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 11, color: Eps.ink),
                    ),
                  ),
                ],
              ),
            ),
          if (extra != null) ...[const SizedBox(height: 8), extra!],
          if (showButton) ...[
            const SizedBox(height: 10),
            EpsPrimaryButton(
              label: 'اشترك · ${formatMru(price)} MRU / شهر',
              icon: Icons.shopping_bag_outlined,
              color: Eps.navy,
              onPressed: () => pushPage(
                context,
                SectionFeatureCheckoutScreen(
                  courseId: courseId,
                  sectionTitle: sectionTitle,
                  feature: feature,
                  name: name,
                  description: items.join(' · '),
                  price: price,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The section's groups: an open group opens, a locked one opens its payment.
class _GroupsList extends StatelessWidget {
  const _GroupsList({required this.groups, required this.subjects});

  final List<EpsChatGroup> groups;
  final List<EpsSubject> subjects;

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    if (groups.isEmpty) {
      return const Text(
        'لا توجد مجموعات في هذا القسم بعد.',
        style: TextStyle(fontSize: 10, color: Eps.muted),
      );
    }
    return Column(
      children: [
        for (final g in groups)
          Builder(
            builder: (context) {
              final subject = subjects
                  .where((s) => s.id == g.subjectId)
                  .firstOrNull;
              final open = learn.canOpenGroup(g);
              final name = g.name.isNotEmpty
                  ? g.name
                  : (subject?.displayName ?? 'مجموعة');
              final String note;
              if (open) {
                note = 'مفتوحة';
              } else if (g.price > 0) {
                note = '${formatMru(g.price)} MRU / شهر';
              } else {
                note = 'غير متاحة بعد';
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (open) {
                      pushPage(
                        context,
                        GroupChatScreen(
                          group: g,
                          subjectName: subject?.displayName ?? '',
                        ),
                      );
                    } else if (g.price > 0) {
                      pushPage(context, GroupCheckoutScreen(group: g));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: open ? Eps.greenSoft : const Color(0xFFF4F6FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          open
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                          size: 16,
                          color: open ? Eps.green : Eps.muted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Eps.ink,
                                ),
                              ),
                              Text(
                                subject?.displayName ?? '',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Eps.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          note,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: open ? Eps.green : Eps.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
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
