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

  Future<void> openSheet({EpsTimetableItem? existing}) async {
    final id = userId;
    if (id == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) =>
          _ClassSheet(userId: id, initialDay: day, existing: existing),
    );
    if (saved == true) {
      await load();
    }
  }

  Future<void> addClass() => openSheet();

  Future<void> editClass(EpsTimetableItem item) => openSheet(existing: item);

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
                onTap: () => editClass(item),
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

class _ClassSheet extends StatefulWidget {
  const _ClassSheet({
    required this.userId,
    required this.initialDay,
    this.existing,
  });

  final String userId;
  final int initialDay;
  final EpsTimetableItem? existing;

  @override
  State<_ClassSheet> createState() => _ClassSheetState();
}

class _ClassSheetState extends State<_ClassSheet> {
  static const _other = 'مادة أخرى';

  final otherName = TextEditingController();
  final room = TextEditingController();
  String? subject;
  late int day = widget.existing?.weekday ?? widget.initialDay;
  TimeOfDay? start;
  bool saving = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      room.text = e.room;
      final parts = e.startsAt.split(':');
      if (parts.length == 2) {
        start = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    otherName.dispose();
    room.dispose();
    super.dispose();
  }

  /// The subjects the student has access to, plus the one already saved.
  List<String> subjectOptions(LearnStore learn) {
    final names = <String>{
      for (final s in learn.activeSubjects) s.name,
      if (widget.existing != null) widget.existing!.subjectName,
    }.toList()..sort();
    return names;
  }

  String? currentSubjectName() {
    if (subject == null) return null;
    return subject == _other ? otherName.text.trim() : subject;
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
    final name = currentSubjectName() ?? '';
    if (name.isEmpty) {
      setState(() => error = 'اختر المادة، أو اكتب اسمها.');
      return;
    }
    if (start == null) {
      setState(() => error = 'حدّد وقت بداية الحصة.');
      return;
    }
    final t = start!;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() {
      saving = true;
      error = '';
    });
    final learn = LearnScope.of(context);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await learn.repo.addTimetableItem(
          userId: widget.userId,
          weekday: day,
          startsAt: time,
          subjectName: name,
          room: room.text,
        );
      } else {
        await learn.repo.updateTimetableItem(
          id: existing.id,
          weekday: day,
          startsAt: time,
          subjectName: name,
          room: room.text,
        );
      }
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
    final learn = LearnScope.of(context);
    final options = subjectOptions(learn);
    // Preselect the saved subject when editing.
    subject ??= widget.existing == null
        ? null
        : (options.contains(widget.existing!.subjectName)
              ? widget.existing!.subjectName
              : _other);
    if (subject == _other &&
        widget.existing != null &&
        otherName.text.isEmpty) {
      otherName.text = widget.existing!.subjectName;
    }
    final time = start == null
        ? 'اختر وقت البداية'
        : '${start!.hour.toString().padLeft(2, '0')}:${start!.minute.toString().padLeft(2, '0')}';
    final editing = widget.existing != null;
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
            Text(
              editing ? 'تعديل الحصة' : 'حصة جديدة',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: subject,
              decoration: const InputDecoration(labelText: 'المادة'),
              items: [
                for (final name in options)
                  DropdownMenuItem(value: name, child: Text(name)),
                const DropdownMenuItem(value: _other, child: Text(_other)),
              ],
              onChanged: (v) => setState(() => subject = v),
            ),
            if (subject == _other) ...[
              const SizedBox(height: 10),
              TextField(
                controller: otherName,
                decoration: const InputDecoration(labelText: 'اسم المادة'),
              ),
            ],
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
              label: editing ? 'حفظ التعديل' : 'حفظ الحصة',
              loading: saving,
              onPressed: saving ? null : save,
            ),
          ],
        ),
      ),
    );
  }
}
