part of '../main.dart';

/// One attachment: a PDF opens in the secure viewer, an image opens full size.
class AttachmentTile extends StatelessWidget {
  const AttachmentTile({required this.attachment, super.key});

  final EpsAttachment attachment;

  void open(BuildContext context) {
    if (attachment.isImage) {
      showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          child: InteractiveViewer(child: Image.network(attachment.url)),
        ),
      );
    } else {
      pushPage(
        context,
        SecureContentViewerPage(
          title: attachment.title,
          url: attachment.url,
          kind: SecureContentKind.pdf,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = attachment.isImage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FlatCard(
        onTap: () => open(context),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: image ? Eps.greenSoft : Eps.blueSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                image ? Icons.image_outlined : Icons.picture_as_pdf_rounded,
                color: image ? Eps.green : Eps.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                attachment.title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Eps.ink,
                ),
              ),
            ),
            Text(
              image ? 'عرض' : 'فتح',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Eps.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The files the admin attached to one lesson, shown above the lesson's PDF.
class LessonAttachments extends StatefulWidget {
  const LessonAttachments({required this.lessonId, super.key});

  final String lessonId;

  @override
  State<LessonAttachments> createState() => _LessonAttachmentsState();
}

class _LessonAttachmentsState extends State<LessonAttachments> {
  late final Future<List<EpsAttachment>> future = LearnScope.read(
    context,
  ).repo.lessonAttachments(widget.lessonId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EpsAttachment>>(
      future: future,
      builder: (context, snap) {
        final items = snap.data ?? const <EpsAttachment>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 9),
            const HomeSectionTitle('مرفقات الدرس'),
            for (final a in items) AttachmentTile(attachment: a),
          ],
        );
      },
    );
  }
}

/// Files attached to the subject itself (not to one lesson).
class SubjectFiles extends StatefulWidget {
  const SubjectFiles({required this.subjectId, super.key});

  final String subjectId;

  @override
  State<SubjectFiles> createState() => _SubjectFilesState();
}

class _SubjectFilesState extends State<SubjectFiles> {
  late final Future<List<EpsAttachment>> future = LearnScope.read(
    context,
  ).repo.subjectFiles(widget.subjectId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EpsAttachment>>(
      future: future,
      builder: (context, snap) {
        final items = snap.data ?? const <EpsAttachment>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final a in items) AttachmentTile(attachment: a)],
        );
      },
    );
  }
}

/// Admin: attach files or images to a subject, or to one of its lessons.
class AdminAttachments extends StatefulWidget {
  const AdminAttachments({super.key});

  @override
  State<AdminAttachments> createState() => _AdminAttachmentsState();
}

class _AdminAttachmentsState extends State<AdminAttachments> {
  final title = TextEditingController();
  List<Map<String, dynamic>> subjects = [];
  List<Map<String, dynamic>> lessons = [];
  List<EpsAttachment> items = [];
  String? subjectId;
  String? lessonId;
  bool busy = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadSubjects());
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  LearnRepository get repo => LearnScope.read(context).repo;

  Future<void> loadSubjects() async {
    try {
      final rows = await repo.client
          .from('subjects')
          .select('id, name')
          .order('sort_order');
      if (mounted) {
        setState(() {
          subjects = [
            for (final r in rows as List) Map<String, dynamic>.from(r as Map),
          ];
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = 'تعذر تحميل المواد: $e');
    }
  }

  Future<void> selectSubject(String id) async {
    setState(() {
      subjectId = id;
      lessonId = null;
      error = '';
    });
    try {
      final rows = await repo.client
          .from('lessons')
          .select('id, title')
          .eq('subject_id', id)
          .order('sort_order');
      final list = await repo.allAttachments(id);
      if (mounted) {
        setState(() {
          lessons = [
            for (final r in rows as List) Map<String, dynamic>.from(r as Map),
          ];
          items = list;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = 'تعذر التحميل: $e');
    }
  }

  Future<void> upload() async {
    final sid = subjectId;
    if (sid == null) {
      setState(() => error = 'اختر المادة أولاً.');
      return;
    }
    if (title.text.trim().isEmpty) {
      setState(() => error = 'اكتب عنواناً للملف.');
      return;
    }
    final picked =
        await NativeFilePicker.pickPdf() ?? await NativeFilePicker.pickImage();
    if (picked == null) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final bytes =
          NativeFilePicker.webFiles[picked.path] ??
          await File(picked.path).readAsBytes();
      if (bytes.length > 7 * 1024 * 1024) {
        throw StateError('الملف أكبر من 7 ميغابايت.');
      }
      await repo.addAttachment(
        subjectId: sid,
        lessonId: lessonId,
        title: title.text,
        bytes: bytes,
        fileName: picked.name,
      );
      title.clear();
      await selectSubject(sid);
    } on Object catch (e) {
      if (mounted) setState(() => error = 'تعذر الرفع: ${friendlyApiError(e)}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(EpsAttachment a) async {
    try {
      await repo.deleteAttachment(a.id);
      if (subjectId != null) await selectSubject(subjectId!);
    } on Object catch (e) {
      if (mounted) setState(() => error = 'تعذر الحذف: ${friendlyApiError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ارفع ملفات أو صوراً للمادة، واربط كلاً منها بفيديو معين إن أردت. يراها المشتركون في المادة فقط.',
          style: TextStyle(fontSize: 9, color: Eps.muted, height: 1.6),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: subjectId,
          decoration: const InputDecoration(labelText: 'المادة'),
          items: [
            for (final s in subjects)
              DropdownMenuItem(
                value: s['id'] as String,
                child: Text('${s['name']}'),
              ),
          ],
          onChanged: (v) {
            if (v != null) selectSubject(v);
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: lessonId,
          decoration: const InputDecoration(
            labelText: 'مرتبط بفيديو (اختياري)',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('ملف عام للمادة'),
            ),
            for (final l in lessons)
              DropdownMenuItem<String?>(
                value: l['id'] as String,
                child: Text('${l['title']}'),
              ),
          ],
          onChanged: (v) => setState(() => lessonId = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'عنوان الملف'),
        ),
        const SizedBox(height: 10),
        EpsPrimaryButton(
          label: 'اختيار ملف أو صورة ورفعها',
          icon: Icons.upload_file_rounded,
          loading: busy,
          onPressed: busy ? null : upload,
        ),
        if (error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(error, style: const TextStyle(color: Eps.red, fontSize: 10)),
        ],
        const SizedBox(height: 12),
        for (final a in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: AttachmentTile(attachment: a)),
                IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete_outline, color: Eps.red),
                  onPressed: () => remove(a),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
