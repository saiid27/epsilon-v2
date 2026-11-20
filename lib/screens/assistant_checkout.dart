part of '../main.dart';

/// What a receipt pays for when it is an assistant package.
class AssistantOrder {
  const AssistantOrder({
    required this.tier,
    required this.period,
    required this.amount,
    required this.title,
  });

  final String tier; // basic, standard or pro
  final String period; // monthly or yearly
  final int amount;
  final String title;
}

/// Maps the package names shown in the app to the tiers in the function.
String assistantTierCode(String packageName) => switch (packageName) {
  'المبتدئ' => 'basic',
  'المتميز' => 'standard',
  _ => 'pro',
};

/// Choose the payment method for an assistant package, then send the receipt.
class AssistantCheckoutScreen extends StatefulWidget {
  const AssistantCheckoutScreen({
    required this.package,
    required this.yearly,
    super.key,
  });

  final AssistantPackage package;
  final bool yearly;

  @override
  State<AssistantCheckoutScreen> createState() =>
      _AssistantCheckoutScreenState();
}

class _AssistantCheckoutScreenState extends State<AssistantCheckoutScreen> {
  String? methodId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = widget.package;
    final amount = widget.yearly ? p.yearly : p.monthly;
    final period = widget.yearly ? 'yearly' : 'monthly';
    final methods = store.paymentMethods;
    methodId ??= methods.firstOrNull?.id;
    final method = methods.where((m) => m.id == methodId).firstOrNull;
    final order = AssistantOrder(
      tier: assistantTierCode(p.name),
      period: period,
      amount: amount,
      title:
          'مساعد Epsilon AI • ${p.name} • '
          '${widget.yearly ? 'سنوي' : 'شهري'}',
    );
    return EpsPage(
      title: 'اشتراك المساعد',
      bottom: EpsPrimaryButton(
        label: 'تم التحويل، رفع الوصل',
        icon: Icons.upload_rounded,
        onPressed: method == null
            ? null
            : () => pushPage(
                context,
                ReceiptUploadScreen(paymentMethodId: method.id, order: order),
              ),
      ),
      children: [
        FlatCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      widget.yearly ? 'اشتراك سنوي' : 'اشتراك شهري',
                      style: const TextStyle(fontSize: 9, color: Eps.muted),
                    ),
                  ],
                ),
              ),
              Text(
                '${formatMru(amount)} MRU',
                style: const TextStyle(
                  fontFamily: Eps.fontNum,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Eps.blue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const HomeSectionTitle('طريقة الدفع'),
        if (methods.isEmpty)
          const Text(
            'لا توجد طرق دفع متاحة الآن.',
            style: TextStyle(fontSize: 10, color: Eps.muted),
          )
        else
          for (final m in methods)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PaymentMethodTile(
                method: m,
                selected: m.id == methodId,
                onTap: () => setState(() => methodId = m.id),
              ),
            ),
        const SizedBox(height: 8),
        Text(
          'بعد التحويل ارفع صورة الوصل. ستُفعَّل الباقة بعد مراجعة الإدارة، ثم تُضاف إلى رصيد المساعد لديك.',
          style: const TextStyle(fontSize: 9, color: Eps.muted, height: 1.6),
        ),
      ],
    );
  }
}

/// Admin: approve or reject the assistant package requests with their receipts.
class AssistantRequestsAdmin extends StatefulWidget {
  const AssistantRequestsAdmin({super.key});

  @override
  State<AssistantRequestsAdmin> createState() => _AssistantRequestsAdminState();
}

class _AssistantRequestsAdminState extends State<AssistantRequestsAdmin> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final repo = LearnScope.read(context).repo;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final list = await repo.assistantRequests();
      if (mounted) {
        setState(() {
          rows = list;
          loading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'تعذر التحميل: $e';
        });
      }
    }
  }

  Future<void> review(String id, bool approve) async {
    final repo = LearnScope.read(context).repo;
    String reason = '';
    if (!approve) {
      reason =
          await showDialog<String>(
            context: context,
            builder: (c) {
              final ctrl = TextEditingController();
              return AlertDialog(
                title: const Text('سبب الرفض'),
                content: TextField(controller: ctrl),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(c, ctrl.text.trim()),
                    child: const Text('رفض'),
                  ),
                ],
              );
            },
          ) ??
          '';
      if (reason.isEmpty) return;
    }
    try {
      await repo.reviewAssistantRequest(
        id: id,
        approve: approve,
        reason: reason,
      );
      await load();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error.isNotEmpty) {
      return Text(error, style: const TextStyle(color: Eps.red, fontSize: 10));
    }
    if (rows.isEmpty) {
      return const Text(
        'لا توجد طلبات لباقات المساعد بعد.',
        style: TextStyle(fontSize: 10, color: Eps.muted),
      );
    }
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FlatCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(r['student'] as Map?)?['name'] ?? 'طالب'} • '
                    '${(r['student'] as Map?)?['phone'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${r['tier']} • ${r['period']} • ${r['amount']} MRU • '
                    '${r['status']}',
                    style: const TextStyle(fontSize: 9, color: Eps.muted),
                  ),
                  if ((r['rejection_reason'] as String? ?? '').isNotEmpty)
                    Text(
                      'سبب الرفض: ${r['rejection_reason']}',
                      style: const TextStyle(fontSize: 9, color: Eps.red),
                    ),
                  Row(
                    children: [
                      if ((r['receipt_url'] as String? ?? '').isNotEmpty)
                        TextButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (c) => Dialog(
                              child: InteractiveViewer(
                                child:
                                    imageBytesFromDataUri(
                                          r['receipt_url'] as String,
                                        ) !=
                                        null
                                    ? Image.memory(
                                        imageBytesFromDataUri(
                                          r['receipt_url'] as String,
                                        )!,
                                      )
                                    : Image.network(r['receipt_url'] as String),
                              ),
                            ),
                          ),
                          child: const Text('الوصل'),
                        ),
                      if (r['status'] == 'pending') ...[
                        TextButton(
                          onPressed: () => review(r['id'] as String, true),
                          child: const Text(
                            'قبول',
                            style: TextStyle(color: Eps.green),
                          ),
                        ),
                        TextButton(
                          onPressed: () => review(r['id'] as String, false),
                          child: const Text(
                            'رفض',
                            style: TextStyle(color: Eps.red),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
