part of '../main.dart';

/// Every price in one place: the sections and their features, the subjects
/// and their groups, and the assistant packages. The admin changes any of them.
class AdminAllPrices extends StatefulWidget {
  const AdminAllPrices({super.key});

  @override
  State<AdminAllPrices> createState() => _AdminAllPricesState();
}

class _AdminAllPricesState extends State<AdminAllPrices> {
  bool busy = false;

  static const _featureColumns = {
    'videos': 'feature_videos_price',
    'live': 'feature_live_price',
    'assistant': 'feature_assistant_price',
  };
  static const _featureNames = {
    'videos': 'الفيديوهات المسجلة',
    'live': 'البث المباشر',
    'assistant': 'مساعد Epsilon AI',
  };

  Future<void> _save(
    String table,
    String column,
    String key,
    Map<String, dynamic> values,
  ) async {
    final learn = LearnScope.read(context);
    setState(() => busy = true);
    try {
      await learn.repo.updateRowBy(
        table: table,
        column: column,
        key: key,
        values: values,
      );
      final uid = learn.userId;
      if (uid != null) await learn.load(uid);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحفظ: ${friendlyApiError(e)}')),
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _edit(
    String title,
    int current,
    Future<void> Function(int value) onSave,
  ) async {
    final ctl = TextEditingController(text: '$current');
    final value = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'السعر (MRU)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(c, int.tryParse(ctl.text.trim()) ?? 0),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (value != null) await onSave(value);
  }

  Widget _priceRow(String label, int price, VoidCallback onTap) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 12)),
      trailing: Text(
        '${formatMru(price)} MRU',
        style: const TextStyle(fontWeight: FontWeight.w900, color: Eps.blue),
      ),
      onTap: busy ? null : onTap,
    );
  }

  Widget _group(String title, List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Eps.ink,
            ),
          ),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    final packages = learn.packageRows;

    final sectionCards = <Widget>[
      for (final c in learn.sections)
        _group(c.title, [
          _priceRow(
            'سعر القسم كاملاً',
            c.bundlePrice,
            () => _edit('سعر القسم كاملاً', c.bundlePrice, (v) async {
              await _save('courses', 'id', c.id, {'bundle_price': v});
            }),
          ),
          for (final f in _featureNames.keys)
            _priceRow(
              _featureNames[f]!,
              c.featurePrices[f] ?? 0,
              () => _edit(_featureNames[f]!, c.featurePrices[f] ?? 0, (
                v,
              ) async {
                await _save('courses', 'id', c.id, {_featureColumns[f]!: v});
              }),
            ),
        ]),
    ];

    final subjectCards = <Widget>[
      for (final s in learn.subjects)
        _group(s.displayName, [
          _priceRow(
            'الاشتراك الكامل / شهر',
            s.monthlyPrice,
            () => _edit('الاشتراك الكامل', s.monthlyPrice, (v) async {
              await _save('subjects', 'id', s.id, {'monthly_price': v});
            }),
          ),
          for (final g in learn.chatGroups.where((g) => g.subjectId == s.id))
            _priceRow(
              'مجموعة: ${g.name.isNotEmpty ? g.name : s.displayName} / شهر',
              g.price,
              () => _edit('سعر المجموعة', g.price, (v) async {
                await _save('chat_groups', 'id', g.id, {'price': v});
              }),
            ),
        ]),
    ];

    final packageCards = <Widget>[
      for (final r in packages)
        _group('${r['name']}', [
          _priceRow(
            'شهري',
            (r['monthly'] as num?)?.toInt() ?? 0,
            () => _edit(
              'سعر ${r['name']} شهرياً',
              (r['monthly'] as num?)?.toInt() ?? 0,
              (v) async {
                await _save('assistant_packages', 'code', '${r['code']}', {
                  'monthly': v,
                });
              },
            ),
          ),
          _priceRow(
            'سنوي',
            (r['yearly'] as num?)?.toInt() ?? 0,
            () => _edit(
              'سعر ${r['name']} سنوياً',
              (r['yearly'] as num?)?.toInt() ?? 0,
              (v) async {
                await _save('assistant_packages', 'code', '${r['code']}', {
                  'yearly': v,
                });
              },
            ),
          ),
        ]),
    ];

    return EpsPage(
      title: 'كل الأسعار',
      children: [
        const Text(
          'اضغط على أي سعر لتغييره. التغيير يظهر للطلاب فور حفظه.',
          style: TextStyle(fontSize: 10, color: Eps.muted),
        ),
        const SizedBox(height: 12),
        const Text(
          'الأقسام وخصائصها',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        ...sectionCards,
        const Text(
          'المواد ومجموعاتها',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        ...subjectCards,
        const Text(
          'باقات المساعد',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        ...packageCards,
        if (packages.isEmpty)
          const Text(
            'لا توجد باقات محفوظة بعد. شغّل migration 20261214 لتظهر هنا.',
            style: TextStyle(fontSize: 10, color: Eps.orangeInk),
          ),
      ],
    );
  }
}
