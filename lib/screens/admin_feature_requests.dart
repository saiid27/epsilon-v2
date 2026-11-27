part of '../main.dart';

/// Section package payments: the admin accepts or rejects each one after
/// checking the receipt.
class AdminFeatureRequests extends StatefulWidget {
  const AdminFeatureRequests({super.key});

  @override
  State<AdminFeatureRequests> createState() => _AdminFeatureRequestsState();
}

class _AdminFeatureRequestsState extends State<AdminFeatureRequests> {
  List<EpsSectionFeatureSub> subs = [];
  Map<String, EpsStudentInfo> people = {};
  bool loading = true;
  String error = '';

  static const _includes = {
    'pkg_groups': 'PDF المواد، البث المباشر والحصص، المجموعات',
    'pkg_videos': 'الفيديوهات المسجلة، PDF المواد',
    'videos': 'الفيديوهات المسجلة',
    'live': 'البث المباشر',
    'assistant': 'مساعد Epsilon AI',
  };

  static const _names = {
    'pkg_groups': 'باقة المجموعات',
    'pkg_videos': 'باقة الاشتراك',
    'videos': 'الفيديوهات المسجلة',
    'live': 'البث المباشر',
    'assistant': 'مساعد Epsilon AI',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final learn = LearnScope.read(context);
    setState(() => loading = true);
    try {
      final list = await learn.repo.sectionFeatureSubscriptions();
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

  Future<void> review(EpsSectionFeatureSub sub, bool approve) async {
    final learn = LearnScope.read(context);
    try {
      await learn.repo.reviewSectionFeature(
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

  void showReceipt(EpsSectionFeatureSub sub) {
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
    String courseTitle(String id) => learn.sectionById(id)?.title ?? 'قسم';
    final pending = subs.where((s) => s.isPending).toList();
    final done = subs.where((s) => !s.isPending).toList();
    return EpsPage(
      title: 'طلبات الباقات',
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
                    '${_names[s.feature] ?? s.feature} · ${courseTitle(s.courseId)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'يشمل: ${_includes[s.feature] ?? ''}',
                    style: const TextStyle(fontSize: 10, color: Eps.blue),
                  ),
                  const SizedBox(height: 8),
                  StudentLine(info: people[s.studentId]),
                  const SizedBox(height: 4),
                  Text(
                    '${formatMru(s.amount)} MRU · ${s.ref}',
                    style: const TextStyle(fontSize: 10, color: Eps.muted),
                  ),
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
                '${_names[s.feature] ?? s.feature} · ${people[s.studentId]?.name ?? 'طالب'} · ${s.isActive
                    ? 'مفعّلة'
                    : s.status == 'rejected'
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
