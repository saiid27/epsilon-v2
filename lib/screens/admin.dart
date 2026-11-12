part of '../main.dart';

// Admin console (Figma: admin). Sidebar on wide screens, drawer on phones.

const _adminNavy = Color(0xFF14204D);

enum _FieldKind { text, multiline, number, toggle, choice, dateTime }

class _Field {
  const _Field(
    this.key,
    this.label, {
    this.kind = _FieldKind.text,
    this.options = const {},
    this.required = false,
  });

  final String key;
  final String label;
  final _FieldKind kind;

  /// value → label, for [_FieldKind.choice].
  final Map<String, String> options;
  final bool required;
}

/// Generic create/edit dialog driven by a list of fields.
Future<Map<String, dynamic>?> _editDialog(
  BuildContext context, {
  required String title,
  required List<_Field> fields,
  Map<String, dynamic> initial = const {},
}) {
  final values = Map<String, dynamic>.from(initial);
  final controllers = {
    for (final f in fields)
      if (f.kind == _FieldKind.text ||
          f.kind == _FieldKind.multiline ||
          f.kind == _FieldKind.number)
        f.key: TextEditingController(text: '${initial[f.key] ?? ''}'),
  };
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: switch (f.kind) {
                      _FieldKind.toggle => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          f.label,
                          style: const TextStyle(fontSize: 13),
                        ),
                        value: values[f.key] == true,
                        onChanged: (v) => setState(() => values[f.key] = v),
                      ),
                      _FieldKind.choice => DropdownButtonFormField<String>(
                        initialValue: f.options.containsKey(values[f.key])
                            ? values[f.key] as String
                            : null,
                        decoration: InputDecoration(labelText: f.label),
                        items: [
                          for (final e in f.options.entries)
                            DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                        ],
                        onChanged: (v) => values[f.key] = v,
                      ),
                      _FieldKind.dateTime => OutlinedButton.icon(
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          values[f.key] == null
                              ? f.label
                              : '${f.label}: ${DateTime.tryParse('${values[f.key]}')?.toLocal().toString().substring(0, 16) ?? ''}',
                        ),
                        onPressed: () async {
                          final now =
                              DateTime.tryParse(
                                '${values[f.key]}',
                              )?.toLocal() ??
                              DateTime.now();
                          final d = await showDatePicker(
                            context: context,
                            initialDate: now,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 2),
                          );
                          if (d == null || !context.mounted) {
                            return;
                          }
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(now),
                          );
                          if (t == null) {
                            return;
                          }
                          setState(
                            () => values[f.key] = DateTime(
                              d.year,
                              d.month,
                              d.day,
                              t.hour,
                              t.minute,
                            ).toUtc().toIso8601String(),
                          );
                        },
                      ),
                      _ => TextField(
                        controller: controllers[f.key],
                        maxLines: f.kind == _FieldKind.multiline ? 4 : 1,
                        keyboardType: f.kind == _FieldKind.number
                            ? TextInputType.number
                            : null,
                        decoration: InputDecoration(labelText: f.label),
                      ),
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              for (final f in fields) {
                final c = controllers[f.key];
                if (c != null) {
                  values[f.key] = f.kind == _FieldKind.number
                      ? int.tryParse(c.text.trim()) ?? 0
                      : c.text.trim();
                }
                if (f.required && '${values[f.key] ?? ''}'.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('${f.label} مطلوب')));
                  return;
                }
              }
              Navigator.pop(context, values);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}

class AdminConsole extends StatefulWidget {
  const AdminConsole({super.key});

  @override
  State<AdminConsole> createState() => _AdminConsoleState();
}

class _AdminConsoleState extends State<AdminConsole> {
  int section = 0;
  bool loading = true;
  String? error;
  final data = <String, List<Map<String, dynamic>>>{};

  static const sections = [
    ('نظرة عامة', Icons.dashboard_outlined),
    ('المواد', Icons.menu_book_outlined),
    ('الأساتذة', Icons.group_outlined),
    ('الدروس', Icons.videocam_outlined),
    ('البث المباشر', Icons.sensors_rounded),
    ('طلبات الدفع', Icons.credit_card_outlined),
    ('الطلاب', Icons.school_outlined),
    ('الاختبارات', Icons.sports_esports_outlined),
    ('الملفات', Icons.description_outlined),
    ('الإعلانات', Icons.campaign_outlined),
  ];

  LearnRepository get repo => LearnScope.read(context).repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    if (!LearnScope.read(context).enabled) {
      setState(() {
        loading = false;
        error = 'الخادم غير متصل';
      });
      return;
    }
    setState(() => loading = true);
    try {
      final c = repo.client;
      List<Map<String, dynamic>> list(Object? v) => v is List
          ? v.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
      final r = await Future.wait<Object?>([
        c.from('subjects').select().order('sort_order'),
        c.from('users').select().eq('role', 'teacher').order('created_at'),
        c.from('lessons').select().order('created_at', ascending: false),
        c.from('live_sessions').select().order('starts_at', ascending: false),
        c
            .from('subject_subscriptions')
            .select()
            .order('created_at', ascending: false),
        c
            .from('users')
            .select()
            .eq('role', 'student')
            .order('created_at', ascending: false),
        c
            .from('quizzes')
            .select('*, quiz_questions(id)')
            .order('created_at', ascending: false),
        c.from('pdf_resources').select().order('created_at', ascending: false),
        c.from('announcements').select().order('created_at', ascending: false),
        c.from('courses').select().order('created_at'),
      ]);
      setState(() {
        data
          ..['subjects'] = list(r[0])
          ..['teachers'] = list(r[1])
          ..['lessons'] = list(r[2])
          ..['live'] = list(r[3])
          ..['subs'] = list(r[4])
          ..['students'] = list(r[5])
          ..['quizzes'] = list(r[6])
          ..['pdfs'] = list(r[7])
          ..['announcements'] = list(r[8])
          ..['courses'] = list(r[9]);
        loading = false;
        error = null;
      });
    } on Object catch (e) {
      setState(() {
        loading = false;
        error = '$e';
      });
    }
  }

  List<Map<String, dynamic>> rows(String key) => data[key] ?? const [];

  Map<String, String> get subjectOptions => {
    for (final s in rows('subjects')) '${s['id']}': '${s['name']}',
  };

  Map<String, String> get teacherOptions => {
    for (final t in rows('teachers')) '${t['id']}': '${t['name']}',
  };

  String subjectName(Object? id) => subjectOptions['$id'] ?? '';

  Future<void> run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
      await load();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> confirmDelete(String table, Object? id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذا العنصر نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Eps.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await run(() => repo.delete(table, '$id'), 'تم الحذف');
    }
  }

  Future<void> edit(
    String table,
    String title,
    List<_Field> fields, {
    Map<String, dynamic>? row,
    Map<String, dynamic> defaults = const {},
  }) async {
    final values = await _editDialog(
      context,
      title: title,
      fields: fields,
      initial: row ?? defaults,
    );
    if (values == null) {
      return;
    }
    final payload = {for (final f in fields) f.key: values[f.key]};
    await run(
      () => row == null
          ? repo.insert(table, {...defaults, ...payload})
          : repo.update(table, '${row['id']}', payload),
      'تم الحفظ وتحديث تطبيق الطلاب',
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pending = rows('subs').where((s) => s['status'] == 'pending').length;
    final sidebar = _Sidebar(
      index: section,
      pending: pending,
      onSelect: (i) {
        setState(() => section = i);
        if (!wide) {
          Navigator.of(context).maybePop();
        }
      },
    );
    final user = StoreScope.of(context).currentUser!;
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              if (!wide)
                Builder(
                  builder: (c) => IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => Scaffold.of(c).openDrawer(),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'لوحة التحكم',
                      style: TextStyle(fontSize: 9, color: Eps.muted),
                    ),
                    Text(
                      sections[section].$1,
                      style: const TextStyle(fontSize: 21, color: Eps.ink),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'تحديث',
                onPressed: load,
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    user.phone,
                    style: const TextStyle(fontSize: 8, color: Eps.muted),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Eps.blue,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  firstLetter(user.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Divider(height: 1),
        ),
        Expanded(
          child: loading
              ? const Center(child: EpsLogoLoader())
              : error != null
              ? Center(
                  child: Text(error!, style: const TextStyle(color: Eps.red)),
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                    children: switch (section) {
                      0 => overview(wide),
                      1 => subjects(),
                      2 => teachers(),
                      3 => lessons(),
                      4 => live(),
                      5 => payments(),
                      6 => students(),
                      7 => quizzes(),
                      8 => pdfs(),
                      _ => announcements(),
                    },
                  ),
                ),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: Eps.bg,
      drawer: wide ? null : Drawer(backgroundColor: _adminNavy, child: sidebar),
      body: SafeArea(
        child: Row(
          children: [
            if (wide) SizedBox(width: 235, child: sidebar),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  // Sections -------------------------------------------------------------

  List<Widget> overview(bool wide) {
    final subs = rows('subs');
    final active = subs.where((s) => s['status'] == 'active').toList();
    final pending = subs.where((s) => s['status'] == 'pending').length;
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month);
    final revenue = active
        .where(
          (s) => (DateTime.tryParse('${s['reviewed_at']}') ?? DateTime(2000))
              .isAfter(monthStart),
        )
        .fold<int>(0, (sum, s) => sum + ((s['amount'] as num?)?.toInt() ?? 0));
    final newStudents = rows('students')
        .where(
          (s) => (DateTime.tryParse('${s['created_at']}') ?? DateTime(2000))
              .isAfter(monthStart),
        )
        .length;
    final bySubject = <String, int>{};
    for (final s in active) {
      bySubject['${s['subject_id']}'] =
          (bySubject['${s['subject_id']}'] ?? 0) +
          ((s['amount'] as num?)?.toInt() ?? 0);
    }
    final cards = [
      _StatCard(
        Icons.group_outlined,
        'الطلاب',
        '${rows('students').length}',
        '+$newStudents هذا الشهر',
      ),
      _StatCard(
        Icons.check_rounded,
        'الاشتراكات النشطة',
        '${active.length}',
        '${rows('subjects').length} مواد',
      ),
      _StatCard(
        Icons.receipt_long_outlined,
        'وصولات بانتظار المراجعة',
        '$pending',
        pending > 0 ? 'تحتاج إجراء' : 'لا شيء معلق',
      ),
      _StatCard(
        Icons.account_balance_wallet_outlined,
        'إيراد الشهر',
        'MRU ${formatMru(revenue)}',
        'الاشتراكات المقبولة',
      ),
    ];
    final maxValue = bySubject.values.fold<int>(1, max);
    return [
      wide
          ? Row(
              children: [
                for (final c in cards) ...[
                  Expanded(child: c),
                  if (c != cards.last) const SizedBox(width: 14),
                ],
              ],
            )
          : GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.3,
              children: cards,
            ),
      const SizedBox(height: 18),
      FlatCard(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإيراد حسب المادة',
                        style: TextStyle(fontSize: 14, color: Eps.ink),
                      ),
                      Text(
                        'مقارنة الاشتراكات النشطة',
                        style: TextStyle(fontSize: 8, color: Eps.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.bar_chart_rounded, color: Eps.ink),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final s in rows('subjects'))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 46,
                            height:
                                20 +
                                190 * (bySubject['${s['id']}'] ?? 0) / maxValue,
                            decoration: BoxDecoration(
                              color: EpsSubject.fromRow(s).color,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '${s['name']}',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 7,
                                color: Eps.ink,
                              ),
                            ),
                          ),
                          Text(
                            formatMru(bySubject['${s['id']}'] ?? 0),
                            style: const TextStyle(
                              fontFamily: Eps.fontNum,
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: Eps.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget addButton(String label, VoidCallback onTap) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(label),
      ),
    ),
  );

  Widget rowTile({
    required String title,
    String subtitle = '',
    Widget? leading,
    List<Widget> badges = const [],
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    List<Widget> extra = const [],
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: FlatCard(
      shadow: false,
      radius: 14,
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final b in badges) ...[const SizedBox(width: 6), b],
                  ],
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 8, color: Eps.muted),
                  ),
              ],
            ),
          ),
          ...extra,
          if (onEdit != null)
            IconButton(
              tooltip: 'تعديل',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 19),
            ),
          if (onDelete != null)
            IconButton(
              tooltip: 'حذف',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: Eps.red,
              ),
            ),
        ],
      ),
    ),
  );

  List<_Field> get subjectFields => [
    const _Field('name', 'اسم المادة', required: true),
    const _Field('icon', 'الرمز (مثل ∑ أو </>)'),
    const _Field('color', 'لون البطاقة (#DBEAFE)'),
    const _Field('faculty', 'الكلية'),
    const _Field('level', 'المستوى (L1، L2…)'),
    const _Field(
      'monthly_price',
      'السعر الشهري (MRU)',
      kind: _FieldKind.number,
    ),
    const _Field('discount', 'الخصم %', kind: _FieldKind.number),
    _Field(
      'teacher_id',
      'الأستاذ',
      kind: _FieldKind.choice,
      options: teacherOptions,
    ),
    _Field(
      'course_id',
      'القسم',
      kind: _FieldKind.choice,
      options: {for (final c in rows('courses')) '${c['id']}': '${c['title']}'},
    ),
    const _Field('description', 'الوصف', kind: _FieldKind.multiline),
    const _Field('sort_order', 'الترتيب', kind: _FieldKind.number),
    const _Field('is_active', 'مفعلة', kind: _FieldKind.toggle),
  ];

  List<Widget> subjects() => [
    addButton(
      'إضافة مادة',
      () => edit(
        'subjects',
        'مادة جديدة',
        subjectFields,
        defaults: {'is_active': true, 'icon': '∑', 'color': '#DBEAFE'},
      ),
    ),
    for (final s in rows('subjects'))
      rowTile(
        leading: SubjectMark(
          subject: EpsSubject.fromRow(s),
          size: 40,
          fontSize: 16,
        ),
        title: '${s['name']}',
        subtitle: [
          if ('${s['level']}'.isNotEmpty) '${s['level']}',
          if ('${s['faculty']}'.isNotEmpty) '${s['faculty']}',
          'MRU ${formatMru((s['monthly_price'] as num?)?.toInt() ?? 0)} / شهر',
          teacherOptions['${s['teacher_id']}'] ?? 'بدون أستاذ',
        ].join(' • '),
        badges: [
          if (s['is_active'] == false)
            const EpsBadge('معطلة', tone: EpsTone.gray),
        ],
        onEdit: () => edit('subjects', 'تعديل المادة', subjectFields, row: s),
        onDelete: () => confirmDelete('subjects', s['id']),
      ),
  ];

  List<Widget> teachers() {
    const fields = [
      _Field('name', 'الاسم', required: true),
      _Field('specialty', 'التخصص'),
      _Field('bio', 'نبذة', kind: _FieldKind.multiline),
      _Field('years_experience', 'سنوات الخبرة', kind: _FieldKind.number),
      _Field('rating', 'التقييم (0-5)'),
      _Field('avatar_url', 'رابط الصورة'),
    ];
    return [
      addButton('إضافة أستاذ', () async {
        final values = await _editDialog(
          context,
          title: 'أستاذ جديد',
          fields: const [
            _Field('name', 'الاسم', required: true),
            _Field('phone', 'رقم الهاتف', required: true),
            _Field('password', 'كلمة المرور', required: true),
            ...[
              _Field('specialty', 'التخصص'),
              _Field('bio', 'نبذة', kind: _FieldKind.multiline),
              _Field(
                'years_experience',
                'سنوات الخبرة',
                kind: _FieldKind.number,
              ),
            ],
          ],
        );
        if (values != null) {
          await run(
            () => repo.insert('users', {
              ...values,
              'role': 'teacher',
              'status': 'active',
            }),
            'تمت إضافة الأستاذ',
          );
        }
      }),
      for (final t in rows('teachers'))
        rowTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFF1C887),
            child: Text(
              firstLetter('${t['name']}'),
              style: const TextStyle(color: Eps.ink),
            ),
          ),
          title: '${t['name']}',
          subtitle: [
            if ('${t['specialty'] ?? ''}'.isNotEmpty) '${t['specialty']}',
            '${t['years_experience'] ?? 0} سنوات خبرة',
            '★ ${t['rating'] ?? 0}',
            '${t['phone']}',
          ].join(' • '),
          onEdit: () async {
            final values = await _editDialog(
              context,
              title: 'تعديل الأستاذ',
              fields: fields,
              initial: {...t, 'rating': '${t['rating'] ?? 0}'},
            );
            if (values != null) {
              await run(
                () => repo.update('users', '${t['id']}', {
                  for (final f in fields) f.key: values[f.key],
                  'rating': double.tryParse('${values['rating']}') ?? 0,
                }),
                'تم الحفظ',
              );
            }
          },
        ),
    ];
  }

  List<_Field> get lessonFields => [
    const _Field('title', 'عنوان الدرس', required: true),
    _Field(
      'subject_id',
      'المادة',
      kind: _FieldKind.choice,
      options: subjectOptions,
      required: true,
    ),
    const _Field('unit', 'الوحدة'),
    const _Field('url', 'رابط الفيديو'),
    const _Field('duration', 'المدة (08:12)'),
    const _Field('pdf_url', 'رابط ملخص PDF'),
    const _Field('description', 'الشرح', kind: _FieldKind.multiline),
    const _Field('key_idea', 'الفكرة الأساسية', kind: _FieldKind.multiline),
    const _Field('example', 'مثال تطبيقي (معادلة)'),
    const _Field('sort_order', 'الترتيب', kind: _FieldKind.number),
    const _Field('is_free', 'درس مجاني', kind: _FieldKind.toggle),
    const _Field('is_published', 'منشور', kind: _FieldKind.toggle),
  ];

  Map<String, dynamic> lessonDefaults(Map<String, dynamic> values) {
    final subject = rows(
      'subjects',
    ).where((s) => '${s['id']}' == '${values['subject_id']}').firstOrNull;
    return {
      'subject': subject?['name'] ?? '',
      'course_id': subject?['course_id'],
    };
  }

  List<Widget> lessons() => [
    addButton('إضافة درس', () async {
      final values = await _editDialog(
        context,
        title: 'درس جديد',
        fields: lessonFields,
        initial: {'is_published': true},
      );
      if (values != null) {
        await run(
          () => repo.insert('lessons', {...values, ...lessonDefaults(values)}),
          'تم نشر الدرس',
        );
      }
    }),
    for (final l in rows('lessons'))
      rowTile(
        title: '${l['title']}',
        subtitle: [
          subjectName(l['subject_id']).isEmpty
              ? '${l['subject'] ?? ''}'
              : subjectName(l['subject_id']),
          if ('${l['unit'] ?? ''}'.isNotEmpty) '${l['unit']}',
          if ('${l['duration'] ?? ''}'.isNotEmpty) '${l['duration']}',
        ].join(' • '),
        badges: [
          if (l['is_free'] == true)
            const EpsBadge('مجاني', tone: EpsTone.green),
          if (l['is_published'] == false)
            const EpsBadge('مسودة', tone: EpsTone.gray),
        ],
        extra: [
          IconButton(
            tooltip: 'التمارين',
            icon: const Icon(Icons.receipt_long_outlined, size: 19),
            onPressed: () => pushPage(context, _ExercisesAdmin(lesson: l)),
          ),
        ],
        onEdit: () async {
          final values = await _editDialog(
            context,
            title: 'تعديل الدرس',
            fields: lessonFields,
            initial: l,
          );
          if (values != null) {
            await run(
              () => repo.update('lessons', '${l['id']}', {
                for (final f in lessonFields) f.key: values[f.key],
                ...lessonDefaults(values),
              }),
              'تم الحفظ',
            );
          }
        },
        onDelete: () => confirmDelete('lessons', l['id']),
      ),
  ];

  List<_Field> get liveFields => [
    const _Field('title', 'عنوان الجلسة', required: true),
    _Field(
      'subject_id',
      'المادة',
      kind: _FieldKind.choice,
      options: subjectOptions,
      required: true,
    ),
    _Field(
      'teacher_id',
      'الأستاذ',
      kind: _FieldKind.choice,
      options: teacherOptions,
    ),
    const _Field(
      'starts_at',
      'موعد البدء',
      kind: _FieldKind.dateTime,
      required: true,
    ),
    const _Field('duration_minutes', 'المدة بالدقائق', kind: _FieldKind.number),
    const _Field('live_url', 'رابط البث (YouTube / Zoom / Meet)'),
    const _Field('recording_url', 'رابط التسجيل بعد الجلسة'),
    const _Field('attendees_count', 'عدد المشاهدين', kind: _FieldKind.number),
    const _Field('is_free', 'جلسة مجانية', kind: _FieldKind.toggle),
    const _Field('is_live', 'البث مباشر الآن', kind: _FieldKind.toggle),
  ];

  List<Widget> live() => [
    addButton(
      'جدولة جلسة',
      () => edit(
        'live_sessions',
        'جلسة جديدة',
        liveFields,
        defaults: {'duration_minutes': 60},
      ),
    ),
    for (final s in rows('live'))
      Builder(
        builder: (context) {
          final session = EpsLiveSession.fromRow(s);
          return rowTile(
            title: session.title,
            subtitle:
                '${subjectName(s['subject_id'])} • ${liveWhen(session.startsAt)} • ${session.durationMinutes} دقيقة',
            badges: [
              switch (session.state) {
                LiveState.live => const EpsBadge('مباشر', tone: EpsTone.red),
                LiveState.upcoming => const EpsBadge('قادمة'),
                LiveState.past => const EpsBadge('انتهت', tone: EpsTone.gray),
              },
              if (session.isFree) const EpsBadge('مجانية', tone: EpsTone.green),
            ],
            onEdit: () =>
                edit('live_sessions', 'تعديل الجلسة', liveFields, row: s),
            onDelete: () => confirmDelete('live_sessions', s['id']),
          );
        },
      ),
  ];

  List<Widget> payments() {
    final students = {for (final u in rows('students')) '${u['id']}': u};
    final subs = [...rows('subs')]
      ..sort(
        (a, b) => (a['status'] == 'pending' ? 0 : 1).compareTo(
          b['status'] == 'pending' ? 0 : 1,
        ),
      );
    return [
      for (final s in subs)
        Builder(
          builder: (context) {
            final sub = EpsSubscription.fromRow(s);
            final student = students[sub.studentId];
            final badge = subscriptionBadge(sub)!;
            return rowTile(
              title:
                  '${student?['name'] ?? 'طالب'} — ${subjectName(sub.subjectId)}',
              subtitle: [
                '#${sub.ref}',
                'MRU ${formatMru(sub.amount)}',
                '${student?['phone'] ?? ''}',
                if (sub.transactionRef.isNotEmpty)
                  'عملية ${sub.transactionRef}',
                if (sub.rejectionReason.isNotEmpty) sub.rejectionReason,
              ].join(' • '),
              badges: [EpsBadge(badge.$1, tone: badge.$2)],
              extra: [
                if (sub.receiptUrl.isNotEmpty)
                  IconButton(
                    tooltip: 'عرض الوصل',
                    icon: const Icon(Icons.image_outlined, size: 19),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (c) => Dialog(
                        child: InteractiveViewer(
                          child: imageBytesFromDataUri(sub.receiptUrl) != null
                              ? Image.memory(
                                  imageBytesFromDataUri(sub.receiptUrl)!,
                                )
                              : Image.network(sub.receiptUrl),
                        ),
                      ),
                    ),
                  ),
                if (sub.status == SubscriptionStatus.pending) ...[
                  IconButton(
                    tooltip: 'قبول',
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Eps.green,
                    ),
                    onPressed: () {
                      final months =
                          LearnScope.read(
                            context,
                          ).planByCode(sub.planCode)?.months ??
                          1;
                      run(
                        () => repo.reviewSubscription(
                          subscription: sub,
                          approve: true,
                          months: months,
                        ),
                        'تم تفعيل الاشتراك وإشعار الطالب',
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'رفض',
                    icon: const Icon(Icons.cancel_outlined, color: Eps.red),
                    onPressed: () async {
                      final values = await _editDialog(
                        context,
                        title: 'سبب الرفض',
                        fields: const [
                          _Field('reason', 'السبب', required: true),
                        ],
                        initial: const {'reason': 'صورة الوصل غير واضحة'},
                      );
                      if (values != null) {
                        await run(
                          () => repo.reviewSubscription(
                            subscription: sub,
                            approve: false,
                            reason: '${values['reason']}',
                          ),
                          'تم رفض الطلب وإشعار الطالب',
                        );
                      }
                    },
                  ),
                ],
              ],
            );
          },
        ),
      if (subs.isEmpty)
        const Text('لا توجد طلبات دفع بعد', style: TextStyle(color: Eps.muted)),
    ];
  }

  List<Widget> students() {
    final subs = rows('subs');
    return [
      for (final u in rows('students'))
        rowTile(
          leading: CircleAvatar(
            backgroundColor: Eps.blueSoft,
            child: Text(
              firstLetter('${u['name']}'),
              style: const TextStyle(color: Eps.blue),
            ),
          ),
          title: '${u['name']}',
          subtitle: [
            '${u['phone']}',
            if ('${u['level'] ?? ''}'.isNotEmpty) '${u['level']}',
            if ('${u['university'] ?? ''}'.isNotEmpty) '${u['university']}',
            '${u['xp'] ?? 0} XP',
            '${subs.where((s) => s['student_id'] == u['id'] && s['status'] == 'active').length} مواد نشطة',
          ].join(' • '),
          badges: [
            if (u['status'] != 'active')
              EpsBadge('${u['status']}', tone: EpsTone.gray),
          ],
        ),
    ];
  }

  List<Widget> quizzes() {
    final fields = [
      const _Field('title', 'عنوان الاختبار', required: true),
      _Field(
        'subject_id',
        'المادة (فارغ للاختبارات العامة)',
        kind: _FieldKind.choice,
        options: subjectOptions,
      ),
      const _Field(
        'kind',
        'النوع',
        kind: _FieldKind.choice,
        options: {
          'daily': 'تحدي اليوم',
          'subject': 'اختبار مادة',
          'quick': 'لعب سريع',
        },
      ),
      const _Field('xp_reward', 'نقاط XP', kind: _FieldKind.number),
      const _Field(
        'question_seconds',
        'ثواني لكل سؤال',
        kind: _FieldKind.number,
      ),
      const _Field(
        'time_limit_seconds',
        'المدة الإجمالية بالثواني',
        kind: _FieldKind.number,
      ),
      const _Field('publish_date', 'تاريخ النشر', kind: _FieldKind.dateTime),
      const _Field('is_free', 'متاح مجاناً', kind: _FieldKind.toggle),
      const _Field('active', 'مفعل', kind: _FieldKind.toggle),
    ];
    Map<String, dynamic> fix(Map<String, dynamic> v) => {
      ...v,
      if (v['publish_date'] != null)
        'publish_date': '${v['publish_date']}'.substring(0, 10),
    };
    return [
      addButton('إضافة اختبار', () async {
        final v = await _editDialog(
          context,
          title: 'اختبار جديد',
          fields: fields,
          initial: {
            'kind': 'subject',
            'xp_reward': 50,
            'question_seconds': 30,
            'time_limit_seconds': 300,
            'active': true,
          },
        );
        if (v != null) {
          await run(() => repo.insert('quizzes', fix(v)), 'تمت إضافة الاختبار');
        }
      }),
      for (final q in rows('quizzes'))
        rowTile(
          title: '${q['title']}',
          subtitle: [
            if (q['subject_id'] != null)
              subjectName(q['subject_id'])
            else
              'عام',
            '${(q['quiz_questions'] as List?)?.length ?? 0} أسئلة',
            '${q['xp_reward']} XP',
            '${q['publish_date']}',
          ].join(' • '),
          badges: [
            if (q['kind'] == 'daily')
              const EpsBadge('تحدي اليوم', tone: EpsTone.orange),
            if (q['is_free'] == true)
              const EpsBadge('مجاني', tone: EpsTone.green),
          ],
          extra: [
            IconButton(
              tooltip: 'الأسئلة',
              icon: const Icon(Icons.quiz_outlined, size: 19),
              onPressed: () => pushPage(context, _QuestionsAdmin(quiz: q)),
            ),
          ],
          onEdit: () async {
            final v = await _editDialog(
              context,
              title: 'تعديل الاختبار',
              fields: fields,
              initial: q,
            );
            if (v != null) {
              await run(
                () => repo.update(
                  'quizzes',
                  '${q['id']}',
                  fix({for (final f in fields) f.key: v[f.key]}),
                ),
                'تم الحفظ',
              );
            }
          },
          onDelete: () => confirmDelete('quizzes', q['id']),
        ),
    ];
  }

  List<Widget> pdfs() {
    final fields = [
      const _Field('title', 'العنوان', required: true),
      _Field(
        'subject_id',
        'المادة',
        kind: _FieldKind.choice,
        options: subjectOptions,
        required: true,
      ),
      const _Field('url', 'رابط الملف', required: true),
      const _Field('page_count', 'عدد الصفحات', kind: _FieldKind.number),
      const _Field('size_text', 'الحجم (2.4 MB)'),
      const _Field('is_free', 'مجاني', kind: _FieldKind.toggle),
    ];
    return [
      addButton('إضافة ملف', () => edit('pdf_resources', 'ملف جديد', fields)),
      for (final p in rows('pdfs'))
        rowTile(
          title: '${p['title']}',
          subtitle: '${subjectName(p['subject_id'])} • ${p['page_count']} صفحة',
          badges: [
            if (p['is_free'] == true)
              const EpsBadge('مجاني', tone: EpsTone.green),
          ],
          onEdit: () => edit('pdf_resources', 'تعديل الملف', fields, row: p),
          onDelete: () => confirmDelete('pdf_resources', p['id']),
        ),
    ];
  }

  List<Widget> announcements() {
    const fields = [
      _Field('title', 'العنوان', required: true),
      _Field('body', 'النص', kind: _FieldKind.multiline),
      _Field('active', 'ظاهر للطلاب', kind: _FieldKind.toggle),
    ];
    return [
      addButton(
        'إعلان جديد',
        () => edit(
          'announcements',
          'إعلان جديد',
          fields,
          defaults: {'active': true},
        ),
      ),
      for (final a in rows('announcements'))
        rowTile(
          title: '${a['title']}',
          subtitle: '${a['body']}',
          badges: [
            if (a['active'] == false)
              const EpsBadge('مخفي', tone: EpsTone.gray),
          ],
          onEdit: () => edit('announcements', 'تعديل الإعلان', fields, row: a),
          onDelete: () => confirmDelete('announcements', a['id']),
        ),
    ];
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.index,
    required this.pending,
    required this.onSelect,
  });

  final int index;
  final int pending;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _adminNavy,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              EpsLogo(size: 44, shadow: null),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أبسيلون',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'لوحة التحكم',
                    style: TextStyle(fontSize: 8, color: Color(0xFFB4C0E0)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < _AdminConsoleState.sections.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: i == index ? Eps.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onSelect(i),
                        child: SizedBox(
                          height: 44,
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Icon(
                                _AdminConsoleState.sections[i].$2,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _AdminConsoleState.sections[i].$1,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (i == 5 && pending > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Eps.red,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    '$pending',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0x40FFFFFF)),
              minimumSize: const Size.fromHeight(40),
            ),
            onPressed: () => pushPage(context, const AdminDashboard()),
            icon: const Icon(Icons.tune_rounded, size: 17),
            label: const Text(
              'أدوات الإدارة الأخرى',
              style: TextStyle(fontSize: 10),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0x40FFFFFF)),
              minimumSize: const Size.fromHeight(40),
            ),
            onPressed: () => StoreScope.of(context).logout(),
            icon: const Icon(Icons.logout_rounded, size: 17),
            label: const Text('تسجيل الخروج', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.icon, this.label, this.value, this.note);

  final IconData icon;
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 8, color: Eps.muted),
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontFamily: Eps.fontNum,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Eps.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Eps.blueSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Eps.blue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(note, style: const TextStyle(fontSize: 7, color: Eps.green)),
        ],
      ),
    );
  }
}

/// Exercises of one lesson.
class _ExercisesAdmin extends StatefulWidget {
  const _ExercisesAdmin({required this.lesson});

  final Map<String, dynamic> lesson;

  @override
  State<_ExercisesAdmin> createState() => _ExercisesAdminState();
}

class _ExercisesAdminState extends State<_ExercisesAdmin> {
  List<Map<String, dynamic>> items = [];

  LearnRepository get repo => LearnScope.read(context).repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final rows = await repo.client
        .from('lesson_exercises')
        .select()
        .eq('lesson_id', '${widget.lesson['id']}')
        .order('sort_order');
    setState(
      () => items = (rows as List)
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(),
    );
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    const fields = [
      _Field(
        'question',
        'نص التمرين',
        kind: _FieldKind.multiline,
        required: true,
      ),
      _Field('illustration', 'المعطيات / المعادلة'),
      _Field(
        'steps',
        'خطوات الحل (كل خطوة في سطر)',
        kind: _FieldKind.multiline,
      ),
      _Field('sort_order', 'الترتيب', kind: _FieldKind.number),
      _Field('is_free', 'مجاني', kind: _FieldKind.toggle),
    ];
    final v = await _editDialog(
      context,
      title: row == null ? 'تمرين جديد' : 'تعديل التمرين',
      fields: fields,
      initial: row == null
          ? const {}
          : {
              ...row,
              'steps': ((row['solution_steps'] as List?) ?? []).join('\n'),
            },
    );
    if (v == null) {
      return;
    }
    final payload = {
      'lesson_id': widget.lesson['id'],
      'question': v['question'],
      'illustration': v['illustration'],
      'sort_order': v['sort_order'],
      'is_free': v['is_free'] == true,
      'solution_steps': '${v['steps'] ?? ''}'
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    };
    row == null
        ? await repo.insert('lesson_exercises', payload)
        : await repo.update('lesson_exercises', '${row['id']}', payload);
    await load();
  }

  @override
  Widget build(BuildContext context) {
    return EpsPage(
      title: 'تمارين: ${widget.lesson['title']}',
      bottom: EpsPrimaryButton(
        label: 'إضافة تمرين',
        icon: Icons.add_rounded,
        onPressed: edit,
      ),
      children: [
        for (final e in items)
          ListTile(
            title: Text('${e['question']}'),
            subtitle: Text(
              '${(e['solution_steps'] as List?)?.length ?? 0} خطوات',
            ),
            onTap: () => edit(e),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Eps.red),
              onPressed: () async {
                await repo.delete('lesson_exercises', '${e['id']}');
                await load();
              },
            ),
          ),
      ],
    );
  }
}

/// Questions of one quiz.
class _QuestionsAdmin extends StatefulWidget {
  const _QuestionsAdmin({required this.quiz});

  final Map<String, dynamic> quiz;

  @override
  State<_QuestionsAdmin> createState() => _QuestionsAdminState();
}

class _QuestionsAdminState extends State<_QuestionsAdmin> {
  List<Map<String, dynamic>> items = [];

  LearnRepository get repo => LearnScope.read(context).repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final rows = await repo.client
        .from('quiz_questions')
        .select()
        .eq('quiz_id', '${widget.quiz['id']}')
        .order('sort_order');
    setState(
      () => items = (rows as List)
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(),
    );
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    const fields = [
      _Field('prompt', 'السؤال', required: true),
      _Field('formula', 'المعادلة (اختياري)'),
      _Field('a', 'الخيار A', required: true),
      _Field('b', 'الخيار B', required: true),
      _Field('c', 'الخيار C'),
      _Field('d', 'الخيار D'),
      _Field(
        'correct',
        'الإجابة الصحيحة',
        kind: _FieldKind.choice,
        options: {'0': 'A', '1': 'B', '2': 'C', '3': 'D'},
        required: true,
      ),
      _Field('explanation', 'شرح الإجابة', kind: _FieldKind.multiline),
      _Field('sort_order', 'الترتيب', kind: _FieldKind.number),
    ];
    final opts = (row?['options'] as List?) ?? const [];
    final v = await _editDialog(
      context,
      title: row == null ? 'سؤال جديد' : 'تعديل السؤال',
      fields: fields,
      initial: row == null
          ? {'correct': '0', 'sort_order': items.length}
          : {
              ...row,
              'a': opts.isNotEmpty ? opts[0] : '',
              'b': opts.length > 1 ? opts[1] : '',
              'c': opts.length > 2 ? opts[2] : '',
              'd': opts.length > 3 ? opts[3] : '',
              'correct': '${row['correct_index']}',
            },
    );
    if (v == null) {
      return;
    }
    final options = [
      for (final k in ['a', 'b', 'c', 'd'])
        if ('${v[k] ?? ''}'.isNotEmpty) '${v[k]}',
    ];
    final payload = {
      'quiz_id': widget.quiz['id'],
      'prompt': v['prompt'],
      'formula': v['formula'] ?? '',
      'options': options,
      'correct_index': int.tryParse('${v['correct']}') ?? 0,
      'explanation': v['explanation'] ?? '',
      'sort_order': v['sort_order'] ?? 0,
    };
    row == null
        ? await repo.insert('quiz_questions', payload)
        : await repo.update('quiz_questions', '${row['id']}', payload);
    await load();
  }

  @override
  Widget build(BuildContext context) {
    return EpsPage(
      title: 'أسئلة: ${widget.quiz['title']}',
      bottom: EpsPrimaryButton(
        label: 'إضافة سؤال',
        icon: Icons.add_rounded,
        onPressed: edit,
      ),
      children: [
        for (final q in items)
          ListTile(
            title: Text('${q['prompt']}'),
            subtitle: Text(((q['options'] as List?) ?? []).join(' • ')),
            onTap: () => edit(q),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Eps.red),
              onPressed: () async {
                await repo.delete('quiz_questions', '${q['id']}');
                await load();
              },
            ),
          ),
      ],
    );
  }
}
