part of '../main.dart';

/// One results website per faculty, from the admin setting: one line each,
/// `name | url` (a bare url is accepted too).
List<({String name, String url})> parseResultsLinks(String raw) {
  final links = <({String name, String url})>[];
  for (final line in raw.split(RegExp(r'[\r\n]+'))) {
    final text = line.trim();
    if (text.isEmpty) {
      continue;
    }
    final bar = text.lastIndexOf('|');
    final url = (bar < 0 ? text : text.substring(bar + 1)).trim();
    var name = bar < 0 ? '' : text.substring(0, bar).trim();
    if (!url.startsWith('http')) {
      continue;
    }
    if (name.isEmpty) {
      name = url.contains('/FST/') ? 'كلية العلوم والتقنيات' : 'نتائج الجامعة';
    }
    links.add((name: name, url: url));
  }
  return links.isEmpty
      ? [
          (
            name: 'كلية العلوم والتقنيات',
            url: LearnStore.defaultUniversityResultsUrl,
          ),
        ]
      : links;
}

/// Opens the university results website inside the app. The student signs in
/// on the university's own page; nothing they type passes through Epsilon.
class UniversityResultsPage extends StatefulWidget {
  const UniversityResultsPage({required this.url, super.key});

  /// The admin setting: one or more faculty links (see [parseResultsLinks]).
  final String url;

  @override
  State<UniversityResultsPage> createState() => _UniversityResultsPageState();
}

class _UniversityResultsPageState extends State<UniversityResultsPage> {
  late final links = parseResultsLinks(widget.url);
  late String url = links.first.url;
  WebViewController? controller;
  int progress = 0;
  bool failed = false;

  /// The university site is built for computers; on a phone it is shown
  /// smaller so the whole page fits, with + / − to adjust.
  double? zoom;

  static const _fitPage = '''
(function () {
  var m = document.querySelector('meta[name=viewport]');
  if (!m) { m = document.createElement('meta'); m.name = 'viewport'; document.head.appendChild(m); }
  m.content = 'width=1000, initial-scale=' + (screen.width / 1000) + ', user-scalable=yes';
})();
''';

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
          onPageFinished: (_) {
            controller?.runJavaScript(_fitPage).catchError((Object _) {});
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
      ..loadRequest(Uri.parse(url));
    final platform = controller!.platform;
    if (platform is AndroidWebViewController) {
      unawaited(platform.enableZoom(true));
    }
  }

  void choose(String next) {
    if (next == url) {
      return;
    }
    setState(() {
      url = next;
      failed = false;
      progress = 0;
    });
    controller?.loadRequest(Uri.parse(next));
  }

  Future<void> openOutside() =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

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
                  title: 'نتائجي الجامعية',
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
              if (links.length > 1)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    children: [
                      for (final link in links)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Text(
                              link.name,
                              style: TextStyle(
                                fontSize: 10,
                                color: link.url == url ? Colors.white : Eps.ink,
                              ),
                            ),
                            selected: link.url == url,
                            showCheckmark: false,
                            onSelected: (_) => choose(link.url),
                          ),
                        ),
                    ],
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
                    ? LayoutBuilder(
                        builder: (context, box) {
                          final z =
                              zoom ??
                              (box.maxWidth < 700
                                  ? (box.maxWidth / 1000).clamp(0.35, 1.0)
                                  : 1.0);
                          final shown = (z * 100).round() / 100;
                          return Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                color: Eps.blueSoft,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: openOutside,
                                        child: const Text(
                                          'إذا لم تظهر الصفحة، اضغط لفتحها في نافذة جديدة',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Eps.blue,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'تصغير',
                                      icon: const Icon(
                                        Icons.zoom_out_rounded,
                                        color: Eps.blue,
                                      ),
                                      onPressed: () => setState(
                                        () => zoom = (shown - 0.1).clamp(
                                          0.3,
                                          1.5,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'تكبير',
                                      icon: const Icon(
                                        Icons.zoom_in_rounded,
                                        color: Eps.blue,
                                      ),
                                      onPressed: () => setState(
                                        () => zoom = (shown + 0.1).clamp(
                                          0.3,
                                          1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ClipRect(
                                  child: webIframe(url, zoom: shown),
                                ),
                              ),
                            ],
                          );
                        },
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
                    'نتائجي الجامعية',
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
