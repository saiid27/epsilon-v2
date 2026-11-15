part of '../main.dart';

/// Opens the university results website inside the app. The student signs in
/// on the university's own page; nothing they type passes through Epsilon.
class UniversityResultsPage extends StatefulWidget {
  const UniversityResultsPage({required this.url, super.key});

  final String url;

  @override
  State<UniversityResultsPage> createState() => _UniversityResultsPageState();
}

class _UniversityResultsPageState extends State<UniversityResultsPage> {
  WebViewController? controller;
  int progress = 0;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      return;
    }
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) {
              setState(() => progress = value);
            }
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() => failed = false);
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              if (mounted) {
                setState(() => failed = true);
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> openOutside() =>
      launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);

  Future<bool> goBackInSite() async {
    final c = controller;
    if (c != null && await c.canGoBack()) {
      await c.goBack();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        if (!await goBackInSite() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Eps.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: EpsPageHeader(
                  title: 'نتائج الجامعة',
                  onBack: () => Navigator.of(context).maybePop(),
                  action: kIsWeb
                      ? EpsIconButton(
                          icon: Icons.open_in_new_rounded,
                          tooltip: 'فتح في نافذة جديدة',
                          onTap: openOutside,
                        )
                      : EpsIconButton(
                          icon: Icons.refresh_rounded,
                          tooltip: 'تحديث',
                          onTap: () => controller?.reload(),
                        ),
                ),
              ),
              if (!kIsWeb && progress < 100)
                LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 2,
                  color: Eps.blue,
                  backgroundColor: Eps.line,
                ),
              Expanded(
                child: failed
                    ? _ResultsError(
                        onRetry: () => controller?.reload(),
                        onOpen: openOutside,
                      )
                    : kIsWeb
                    ? Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            color: Eps.blueSoft,
                            child: GestureDetector(
                              onTap: openOutside,
                              child: const Text(
                                'إذا لم تظهر صفحة الجامعة هنا، اضغط لفتحها في نافذة جديدة',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Eps.blue,
                                ),
                              ),
                            ),
                          ),
                          Expanded(child: webIframe(widget.url)),
                        ],
                      )
                    : WebViewWidget(controller: controller!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsError extends StatelessWidget {
  const _ResultsError({required this.onRetry, required this.onOpen});

  final VoidCallback onRetry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EpsMark(
            icon: Icons.wifi_off_rounded,
            tone: EpsTone.red,
            size: 60,
          ),
          const SizedBox(height: 12),
          const Text(
            'تعذر فتح موقع الجامعة',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const Text(
            'تحقق من اتصالك بالإنترنت ثم أعد المحاولة.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Eps.muted),
          ),
          const SizedBox(height: 16),
          EpsPrimaryButton(label: 'إعادة المحاولة', onPressed: onRetry),
          TextButton(onPressed: onOpen, child: const Text('فتح في المتصفح')),
        ],
      ),
    );
  }
}

/// Home card that opens the university results page.
class UniversityResultsCard extends StatelessWidget {
  const UniversityResultsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final url = LearnScope.of(context).universityResultsUrl;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: FlatCard(
        onTap: () => pushPage(context, UniversityResultsPage(url: url)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Eps.greenSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fact_check_outlined,
                color: Eps.green,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نتائج الجامعة',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Eps.ink,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    'ادخل بمعلوماتك في موقع الجامعة لرؤية نتائجك',
                    style: TextStyle(
                      fontSize: 7,
                      color: Eps.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Eps.ink, size: 18),
          ],
        ),
      ),
    );
  }
}
