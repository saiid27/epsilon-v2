part of '../main.dart';

/// The group payments: the admin accepts or rejects each one after checking
/// the receipt.
class AdminGroupRequests extends StatefulWidget {
  const AdminGroupRequests({super.key});

  @override
  State<AdminGroupRequests> createState() => _AdminGroupRequestsState();
}

class _AdminGroupRequestsState extends State<AdminGroupRequests> {
  List<EpsGroupSub> subs = [];
  Map<String, EpsStudentInfo> people = {};
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final learn = LearnScope.read(context);
    setState(() => loading = true);
    try {
      final list = await learn.repo.groupSubscriptions();
      final who = await learn.repo.studentInfo([
        for (final s in list) s.studentId,
      ]);
      if (mounted) {
        setState(() {
          subs = list;
          people = who;
          loading = false;
          error = '';
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = friendlyApiError(e);
        });
      }
    }
  }

  Future<void> review(EpsGroupSub sub, bool approve) async {
    final learn = LearnScope.read(context);
    try {
      await learn.repo.reviewGroupSubscription(
        sub: sub,
        approve: approve,
        reason: approve ? '' : 'لم يتم التحقق من الدفع',
      );
      await load();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyApiError(e))));
      }
    }
  }

  void showReceipt(EpsGroupSub sub) {
    final data = sub.receiptUrl;
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        content: data.startsWith('data:')
            ? Image.memory(base64Decode(data.split(',').last))
            : Text(data.isEmpty ? 'لا يوجد وصل' : data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    String groupName(String id) {
      final g = learn.chatGroups.where((g) => g.id == id).firstOrNull;
      if (g == null) return 'مجموعة';
      return g.name.isNotEmpty
          ? g.name
          : (learn.subjectById(g.subjectId)?.displayName ?? 'مجموعة');
    }

    final pending = subs.where((s) => s.isPending).toList();
    final done = subs.where((s) => !s.isPending).toList();
    return EpsPage(
      title: 'طلبات المجموعات',
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Eps.red, fontSize: 10))
        else ...[
          Text(
            'بانتظار المراجعة (${pending.length})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            const Text(
              'لا توجد طلبات جديدة.',
              style: TextStyle(fontSize: 10, color: Eps.muted),
            ),
          for (final s in pending)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Eps.radius),
                boxShadow: Eps.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupName(s.groupId),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${people[s.studentId]?.name ?? 'طالب'} · ${formatMru(s.amount)} MRU · ${s.ref}',
                    style: const TextStyle(fontSize: 10, color: Eps.muted),
                  ),
                  if (s.transactionRef.isNotEmpty)
                    Text(
                      'مرجع الدفع: ${s.transactionRef}',
                      style: const TextStyle(fontSize: 10, color: Eps.muted),
                    ),
                  const SizedBox(height: 6),
                  const Text(
                    'نوع الاشتراك: مجموعة · يشمل: محادثة المجموعة، الصور والصوت والاستطلاعات',
                    style: TextStyle(fontSize: 10, color: Eps.blue),
                  ),
                  const SizedBox(height: 8),
                  StudentLine(info: people[s.studentId]),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => showReceipt(s),
                        child: const Text('عرض الوصل'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => review(s, false),
                        child: const Text(
                          'رفض',
                          style: TextStyle(color: Eps.red),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => review(s, true),
                        child: const Text('قبول'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'السابقة',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          for (final s in done)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${groupName(s.groupId)} · ${people[s.studentId]?.name ?? 'طالب'} · ${s.isActive
                    ? 'مفعّلة'
                    : s.rawStatus == SubscriptionStatus.rejected
                    ? 'مرفوضة'
                    : 'منتهية'}',
                style: const TextStyle(fontSize: 10, color: Eps.muted),
              ),
            ),
        ],
      ],
    );
  }
}
