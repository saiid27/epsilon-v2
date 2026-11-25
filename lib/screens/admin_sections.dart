part of '../main.dart';

/// Admin: the sections the new subscribers see, with what each offers and its
/// bundle price. Everything here is written by the admin.
class AdminSections extends StatefulWidget {
  const AdminSections({super.key});

  @override
  State<AdminSections> createState() => _AdminSectionsState();
}

class _AdminSectionsState extends State<AdminSections> {
  List<EpsSection> sections = [];
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final list = await LearnScope.read(context).repo.sections();
      if (mounted) {
        setState(() {
          sections = list;
          loading = false;
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

  Future<void> edit(EpsSection c) async {
    final repo = LearnScope.read(context).repo;
    final title = TextEditingController(text: c.title);
    final desc = TextEditingController(text: c.description);
    final features = TextEditingController(text: c.features.join('\n'));
    final price = TextEditingController(text: c.bundlePrice.toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('القسم'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'اسم القسم'),
              ),
              TextField(
                controller: desc,
                decoration: const InputDecoration(labelText: 'وصف قصير'),
              ),
              TextField(
                controller: features,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'ما يقدمه القسم (سطر لكل خاصية)',
                ),
              ),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'سعر القسم كاملاً في الشهر (MRU)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await repo.saveSection(
        id: c.id,
        title: title.text.isEmpty ? c.title : title.text,
        description: desc.text,
        features: [
          for (final l in features.text.split('\n'))
            if (l.trim().isNotEmpty) l.trim(),
        ],
        bundlePrice: int.tryParse(price.text.trim()) ?? 0,
      );
      await load();
    } on Object catch (e) {
      if (mounted) {
        setState(() => error = 'تعذر الحفظ: ${friendlyApiError(e)}');
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Eps.red, fontSize: 10)),
        for (final c in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FlatCard(
              onTap: () => edit(c),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title.isEmpty ? '(بدون اسم)' : c.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'سعر القسم: ${c.bundlePrice} MRU / شهر • ${c.features.length} خاصية',
                    style: const TextStyle(fontSize: 9, color: Eps.muted),
                  ),
                  for (final f in c.features.take(3))
                    Text(
                      '• $f',
                      style: const TextStyle(fontSize: 9, color: Eps.ink),
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'اضغط للتعديل',
                    style: TextStyle(fontSize: 9, color: Eps.blue),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
