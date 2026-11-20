part of '../main.dart';

const _weekdayNames = [
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];

/// The student's university timetable. Tomorrow's classes are sent as a
/// notification every night at 21:00.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  // Dart: Monday = 1 ... Sunday = 7. Postgres: Sunday = 0 ... Saturday = 6.
  int day = DateTime.now().weekday % 7;
  List<EpsTimetableItem> items = [];
  bool loading = true;
  String error = '';

  String? get userId => LearnScope.of(context).userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final learn = LearnScope.of(context);
    final id = learn.userId;
    if (id == null) {
      setState(() {
        loading = false;
        error = 'سجّل دخولك لعرض جدولك.';
      });
      return;
    }
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final rows = await learn.repo.myTimetable(id);
      if (mounted) {
        setState(() {
          items = rows;
          loading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'تعذر تحميل الجدول: $e';
        });
      }
    }
  }

  Future<void> remove(EpsTimetableItem item) async {
    final learn = LearnScope.of(context);
    try {
      await learn.repo.deleteTimetableItem(item.id);
      await load();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر الحذف: $e')));
      }
    }
  }

  Future<void> addClass() async {
    final id = userId;
    if (id == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _AddClassSheet(userId: id, initialDay: day),
    );
    if (saved == true) {
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayItems = items.where((i) => i.weekday == day).toList();
    return EpsPage(
      title: 'جدولي الجامعي',
      children: [
        const Text(
          'أدخل حصصك، وسيصلك كل مساء الساعة 9 تذكير بحصص الغد.',
          style: TextStyle(fontSize: 9, color: Eps.muted, height: 1.6),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var d = 0; d < _weekdayNames.length; d++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(_weekdayNames[d]),
                    selected: day == d,
                    showCheckmark: false,
                    selectedColor: Eps.blue,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: day == d ? Colors.white : Eps.ink,
                    ),
                    onSelected: (_) => setState(() => day = d),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Eps.red, fontSize: 10))
        else if (dayItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'لا توجد حصص لهذا اليوم بعد.',
              style: TextStyle(fontSize: 10, color: Eps.muted),
            ),
          )
        else
          for (final item in dayItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FlatCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Eps.blueSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.startsAt,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Eps.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.subjectName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Eps.ink,
                            ),
                          ),
                          if (item.room.isNotEmpty)
                            Text(
                              'القاعة: ${item.room}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Eps.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline, color: Eps.red),
                      onPressed: () => remove(item),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 14),
        EpsPrimaryButton(
          label: 'إضافة حصة',
          icon: Icons.add_rounded,
          onPressed: addClass,
        ),
      ],
    );
  }
}

class _AddClassSheet extends StatefulWidget {
  const _AddClassSheet({required this.userId, required this.initialDay});

  final String userId;
  final int initialDay;

  @override
  State<_AddClassSheet> createState() => _AddClassSheetState();
}

class _AddClassSheetState extends State<_AddClassSheet> {
  final subject = TextEditingController();
  final room = TextEditingController();
  late int day = widget.initialDay;
  TimeOfDay? start;
  bool saving = false;
  String error = '';

  @override
  void dispose() {
    subject.dispose();
    room.dispose();
    super.dispose();
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      setState(() => start = picked);
    }
  }

  Future<void> save() async {
    if (subject.text.trim().isEmpty) {
      setState(() => error = 'اكتب اسم المادة.');
      return;
    }
    if (start == null) {
      setState(() => error = 'اختر وقت بداية الحصة.');
      return;
    }
    final t = start!;
    setState(() {
      saving = true;
      error = '';
    });
    try {
      await LearnScope.of(context).repo.addTimetableItem(
        userId: widget.userId,
        weekday: day,
        startsAt:
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
        subjectName: subject.text,
        room: room.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'تعذر الحفظ: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = start == null
        ? 'اختر وقت البداية'
        : '${start!.hour.toString().padLeft(2, '0')}:${start!.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'حصة جديدة',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subject,
              decoration: const InputDecoration(labelText: 'اسم المادة'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: room,
              decoration: const InputDecoration(labelText: 'القاعة (اختياري)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: pickTime,
              icon: const Icon(Icons.schedule_rounded),
              label: Text(time),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: day,
              decoration: const InputDecoration(labelText: 'اليوم'),
              items: [
                for (var d = 0; d < _weekdayNames.length; d++)
                  DropdownMenuItem(value: d, child: Text(_weekdayNames[d])),
              ],
              onChanged: (v) => setState(() => day = v ?? day),
            ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(error, style: const TextStyle(color: Eps.red, fontSize: 10)),
            ],
            const SizedBox(height: 14),
            EpsPrimaryButton(
              label: 'حفظ الحصة',
              loading: saving,
              onPressed: saving ? null : save,
            ),
          ],
        ),
      ),
    );
  }
}
