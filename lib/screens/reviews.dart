part of '../main.dart';

/// The student reviews on the first screen, before sign-up. Only the reviews
/// the admin left visible are shown; with none, nothing is shown.
class StudentReviews extends StatelessWidget {
  const StudentReviews({super.key});

  @override
  Widget build(BuildContext context) {
    final learn = LearnScope.of(context);
    return FutureBuilder<List<EpsReview>>(
      future: learn.repo.visibleReviews(),
      builder: (context, snap) {
        final list = snap.data ?? const <EpsReview>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ماذا يقول طلابنا',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Eps.ink,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _ReviewCard(review: list[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final EpsReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Eps.radius),
        boxShadow: Eps.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Eps.ink,
                  ),
                ),
              ),
              for (var i = 0; i < 5; i++)
                Icon(
                  i < review.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 13,
                  color: const Color(0xFFF1B91C),
                ),
            ],
          ),
          if (review.role.isNotEmpty)
            Text(
              review.role,
              style: const TextStyle(fontSize: 10, color: Eps.blue),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              review.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Eps.muted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A student rates the app. The review waits for the admin before it shows.
class RateAppScreen extends StatefulWidget {
  const RateAppScreen({super.key});

  @override
  State<RateAppScreen> createState() => _RateAppScreenState();
}

class _RateAppScreenState extends State<RateAppScreen> {
  int stars = 5;
  final text = TextEditingController();
  bool sending = false;
  bool sent = false;
  String error = '';

  Future<void> send() async {
    final learn = LearnScope.read(context);
    final uid = learn.userId;
    if (uid == null) return;
    if (text.text.trim().length < 5) {
      setState(() => error = 'اكتب رأيك في سطر على الأقل.');
      return;
    }
    setState(() {
      sending = true;
      error = '';
    });
    try {
      final p = learn.profile;
      await learn.repo.submitAppReview(
        userId: uid,
        name: p?.name ?? 'طالب',
        role: [
          p?.faculty ?? '',
          p?.level ?? '',
        ].where((e) => e.isNotEmpty).join(' · '),
        text: text.text,
        rating: stars,
      );
      if (mounted) setState(() => sent = true);
    } on Object catch (e) {
      if (mounted) setState(() => error = friendlyApiError(e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EpsPage(
      title: 'قيّم التطبيق',
      children: [
        if (sent)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'شكراً لك! سيظهر تقييمك بعد مراجعة الإدارة.',
              style: TextStyle(
                fontSize: 12,
                color: Eps.green,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Eps.radius),
              boxShadow: Eps.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'كيف تقيّم إبسيلون؟',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        onPressed: () => setState(() => stars = i),
                        icon: Icon(
                          i <= stars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFF1B91C),
                          size: 30,
                        ),
                      ),
                  ],
                ),
                TextField(
                  controller: text,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'ما الذي أعجبك، وما الذي يمكن تحسينه؟',
                  ),
                ),
              ],
            ),
          ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error,
                style: const TextStyle(color: Eps.red, fontSize: 10),
              ),
            ),
          const SizedBox(height: 12),
          EpsPrimaryButton(
            label: sending ? 'جارٍ الإرسال' : 'إرسال التقييم',
            icon: Icons.send_rounded,
            onPressed: sending ? null : send,
          ),
        ],
      ],
    );
  }
}

/// The admin manages the reviews: show or hide each one, edit, add, delete.
class AdminReviews extends StatefulWidget {
  const AdminReviews({super.key});

  @override
  State<AdminReviews> createState() => _AdminReviewsState();
}

class _AdminReviewsState extends State<AdminReviews> {
  List<EpsReview> reviews = [];
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
      final list = await learn.repo.allReviews();
      if (mounted) {
        setState(() {
          reviews = list;
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

  Future<void> edit([EpsReview? r]) async {
    final learn = LearnScope.read(context);
    final name = TextEditingController(text: r?.name ?? '');
    final role = TextEditingController(text: r?.role ?? '');
    final text = TextEditingController(text: r?.text ?? '');
    final rating = TextEditingController(text: '${r?.rating ?? 5}');
    final order = TextEditingController(text: '${r?.sortOrder ?? 0}');
    var visible = r?.visible ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(r == null ? 'تقييم جديد' : 'تعديل التقييم'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم الطالب'),
                ),
                TextField(
                  controller: role,
                  decoration: const InputDecoration(
                    labelText: 'الكلية أو القسم (اختياري)',
                  ),
                ),
                TextField(
                  controller: text,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'نص التقييم'),
                ),
                TextField(
                  controller: rating,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد النجوم (1 إلى 5)',
                  ),
                ),
                TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الترتيب'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ظاهر للطلاب'),
                  value: visible,
                  onChanged: (v) => set(() => visible = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty || text.text.trim().isEmpty)
      return;
    try {
      await learn.repo.saveReview(
        id: r?.id,
        name: name.text,
        role: role.text,
        text: text.text,
        rating: int.tryParse(rating.text.trim()) ?? 5,
        visible: visible,
        sortOrder: int.tryParse(order.text.trim()) ?? 0,
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

  Future<void> toggle(EpsReview r, bool visible) async {
    await LearnScope.read(context).repo.setReviewVisible(r.id, visible);
    await load();
  }

  @override
  Widget build(BuildContext context) {
    return EpsPage(
      title: 'تقييمات الطلاب',
      action: EpsIconButton(
        icon: Icons.add_rounded,
        tooltip: 'تقييم جديد',
        onTap: () => edit(),
      ),
      children: [
        const Text(
          'تظهر التقييمات المفعّلة فقط في الشاشة الأولى قبل إنشاء الحساب.',
          style: TextStyle(fontSize: 10, color: Eps.muted),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Eps.red, fontSize: 10))
        else if (reviews.isEmpty)
          const Text(
            'لا توجد تقييمات بعد.',
            style: TextStyle(fontSize: 10, color: Eps.muted),
          )
        else
          for (final r in reviews)
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${r.name} · ${r.rating}★',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Switch(value: r.visible, onChanged: (v) => toggle(r, v)),
                    ],
                  ),
                  Text(
                    r.text,
                    style: const TextStyle(fontSize: 11, color: Eps.muted),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => edit(r),
                        child: const Text('تعديل'),
                      ),
                      const Spacer(),
                      Text(
                        r.visible ? 'ظاهر' : 'مخفي',
                        style: TextStyle(
                          fontSize: 10,
                          color: r.visible ? Eps.green : Eps.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
