part of '../main.dart';

/// Admin: how much of the Claude balance is used, what is left, and whether
/// the assistant is about to stop. The Claude balance is entered by hand from
/// the Claude console, because the app cannot read it.
class AdminAiOps extends StatefulWidget {
  const AdminAiOps({super.key});

  @override
  State<AdminAiOps> createState() => _AdminAiOpsState();
}

class _AdminAiOpsState extends State<AdminAiOps> {
  static const _mruPerUsd = 40.0;

  bool loading = true;
  String error = '';
  double balanceUsd = 0;
  DateTime setAt = DateTime.now().toUtc();
  // (created_at, cost_usd, model) of the assistant calls in the window.
  List<({DateTime at, double usd, String model})> costs = [];
  List<({DateTime at, int status, String message})> errors = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  LearnRepository get repo => LearnScope.read(context).repo;

  Future<void> load() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final client = repo.client;
      final balance = await repo.setting('anthropicBalanceUsd', fallback: '0');
      final since = await repo.setting(
        'anthropicBalanceSetAt',
        fallback: DateTime.now().toUtc().toIso8601String(),
      );
      balanceUsd = double.tryParse(balance) ?? 0;
      setAt = DateTime.tryParse(since)?.toUtc() ?? DateTime.now().toUtc();

      // Enough history for the balance (since it was set) and for 7 days.
      final windowStart = [
        setAt,
        DateTime.now().toUtc().subtract(const Duration(days: 30)),
      ].reduce((a, b) => a.isBefore(b) ? a : b);
      final cost = await client
          .from('assistant_costs')
          .select('created_at, cost_usd, model')
          .gte('created_at', windowStart.toIso8601String())
          .order('created_at', ascending: false)
          .limit(20000);
      costs = [
        for (final r in cost as List)
          (
            at: DateTime.parse('${r['created_at']}').toUtc(),
            usd: (r['cost_usd'] as num?)?.toDouble() ?? 0,
            model: '${r['model']}',
          ),
      ];

      final err = await client
          .from('assistant_errors')
          .select('created_at, status, message')
          .gte(
            'created_at',
            DateTime.now()
                .toUtc()
                .subtract(const Duration(days: 7))
                .toIso8601String(),
          )
          .order('created_at', ascending: false)
          .limit(50);
      errors = [
        for (final r in err as List)
          (
            at: DateTime.parse('${r['created_at']}').toUtc(),
            status: (r['status'] as num?)?.toInt() ?? 0,
            message: '${r['message']}',
          ),
      ];
      if (mounted) setState(() => loading = false);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'تعذر التحميل: ${friendlyApiError(e)}';
        });
      }
    }
  }

  double sumSince(DateTime from) => costs
      .where((c) => !c.at.isBefore(from))
      .fold<double>(0, (sum, c) => sum + c.usd);

  Future<void> editBalance() async {
    final ctrl = TextEditingController(text: balanceUsd.toStringAsFixed(2));
    final value = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('رصيد Claude الحالي (دولار)'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'الرصيد المتبقي في Console',
            helperText:
                'انسخه من Plans & Billing ثم اكتبه هنا. يُحسب الاستهلاك بعده تلقائياً.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              c,
              double.tryParse(ctrl.text.replaceAll(',', '.')),
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (value == null) return;
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await repo.saveSetting('anthropicBalanceUsd', value.toString());
      await repo.saveSetting('anthropicBalanceSetAt', now);
      await load();
    } on Object catch (e) {
      if (mounted) {
        setState(() => error = 'تعذر الحفظ: ${friendlyApiError(e)}');
      }
    }
  }

  Widget stat(String label, String value, {Color color = Eps.ink}) => Expanded(
    child: FlatCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Eps.muted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final now = DateTime.now().toUtc();
    final spentSinceSet = sumSince(setAt);
    final remaining = balanceUsd - spentSinceSet;
    final today = sumSince(DateTime.utc(now.year, now.month, now.day));
    final week = sumSince(now.subtract(const Duration(days: 7)));
    final daily = week / 7;
    final daysLeft = daily > 0 ? remaining / daily : double.infinity;
    final authErrors = errors
        .where((e) => e.status == 401 || e.status == 402 || e.status == 403)
        .where((e) => now.difference(e.at).inHours < 24)
        .toList();
    final recentErrors = errors
        .where((e) => now.difference(e.at).inHours < 24)
        .length;
    final sonnet = costs
        .where((c) => c.model.contains('sonnet'))
        .fold<double>(0, (s, c) => s + c.usd);
    final haiku = costs
        .where((c) => c.model.contains('haiku'))
        .fold<double>(0, (s, c) => s + c.usd);

    final alerts = <String>[
      if (authErrors.isNotEmpty)
        'مفتاح Claude مرفوض أو الرصيد نفد (${authErrors.first.status}). تحقق من المفتاح في الأسرار، ومن الرصيد في Console.',
      if (remaining <= 0)
        'الرصيد المسجّل انتهى. اشحن Claude وحدّث الرصيد أدناه، وإلا يتوقف المساعد.',
      if (remaining > 0 && daysLeft < 7)
        'الرصيد يكفي نحو ${daysLeft.floor()} يوماً فقط بمعدل الأسبوع الأخير. اشحن قبل أن ينفد.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in alerts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FlatCard(
              color: Eps.redSoft,
              padding: const EdgeInsets.all(10),
              child: Text(
                a,
                style: const TextStyle(
                  fontSize: 10,
                  color: Eps.red,
                  height: 1.6,
                ),
              ),
            ),
          ),
        Row(
          children: [
            stat(
              'المتبقي (دولار)',
              remaining.toStringAsFixed(2),
              color: remaining <= 0 ? Eps.red : Eps.green,
            ),
            const SizedBox(width: 8),
            stat('المستنزف منذ التحديث', spentSinceSet.toStringAsFixed(2)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            stat(
              'المتبقي بالأوقية',
              (remaining * _mruPerUsd).round().toString(),
            ),
            const SizedBox(width: 8),
            stat(
              'يكفي تقريباً (أيام)',
              daysLeft.isInfinite ? '—' : daysLeft.floor().toString(),
              color: daysLeft < 7 ? Eps.red : Eps.ink,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            stat('اليوم (دولار)', today.toStringAsFixed(3)),
            const SizedBox(width: 8),
            stat('متوسط اليوم (7 أيام)', daily.toStringAsFixed(3)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            stat('Sonnet (30 يوماً)', sonnet.toStringAsFixed(2)),
            const SizedBox(width: 8),
            stat('Haiku (30 يوماً)', haiku.toStringAsFixed(2)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            stat(
              'أخطاء آخر 24 ساعة',
              recentErrors.toString(),
              color: recentErrors > 0 ? Eps.red : Eps.green,
            ),
          ],
        ),
        const SizedBox(height: 10),
        EpsPrimaryButton(
          label: 'تحديث رصيد Claude من Console',
          icon: Icons.edit_outlined,
          onPressed: editBalance,
        ),
        if (error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(error, style: const TextStyle(color: Eps.red, fontSize: 10)),
        ],
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          const HomeSectionTitle('آخر الأخطاء (7 أيام)'),
          for (final e in errors.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${e.status} • ${e.at.toLocal().toString().substring(0, 16)} • ${e.message}',
                style: const TextStyle(
                  fontSize: 9,
                  color: Eps.muted,
                  height: 1.5,
                ),
              ),
            ),
        ],
        const SizedBox(height: 10),
        const Text(
          'الرصيد يُدخل يدوياً من Console، لأن التطبيق لا يستطيع قراءته. حدّثه بعد كل شحن.',
          style: TextStyle(fontSize: 9, color: Eps.muted, height: 1.6),
        ),
      ],
    );
  }
}
