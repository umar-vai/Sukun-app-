import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

/// The external host retains the file; only the PDF pages are rendered here.
/// Web PDF network requests require the host to allow cross-origin reads.
typedef PdfReaderRenderer = Widget Function(
  Uri uri,
  PdfViewerController controller,
  PdfViewerParams params,
  Key key,
);

final pdfReaderRendererProvider = Provider<PdfReaderRenderer>(
  (ref) =>
      (uri, controller, params, key) => PdfViewer.uri(
        uri,
        key: key,
        controller: controller,
        params: params,
        timeout: const Duration(seconds: 30),
      ),
);

/// A Web-first, cross-platform PDF reader, never an automatic external link.
class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({required this.resource, super.key});

  final LinkedResource resource;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  final PdfViewerController _controller = PdfViewerController();
  int _attempt = 0;
  int _currentPage = 1;
  int _pageCount = 0;

  Uri? get _pdfUri {
    final target = resolveResourceMedia(widget.resource);
    return target?.kind == ResourceMediaKind.pdf ? target?.uri : null;
  }

  void _retry() {
    setState(() {
      _attempt++;
      _currentPage = 1;
      _pageCount = 0;
    });
  }

  Future<void> _goToPage(int page) async {
    if (!_controller.isReady || page < 1 || page > _pageCount) return;
    await _controller.goToPage(pageNumber: page);
  }

  @override
  Widget build(BuildContext context) {
    // The native route can outlive the browser authentication session.
    // Close a previously loaded document when the verified viewer changes.
    ref.listen<AsyncValue<AppSession>>(appSessionProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if (before?.userId == null && after?.userId == null) return;
      if (before?.userId != after?.userId || before?.role != after?.role) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      }
    });

    final uri = _pdfUri;
    return Scaffold(
      appBar: AppBar(
        title: const Text('পিডিএফ পড়ুন'),
        actions: [
          IconButton(
            tooltip: 'আবার লোড করুন',
            onPressed: uri == null ? null : _retry,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: uri == null
          ? const AppEmptyState(
              title: 'সঠিক পিডিএফ লিংক পাওয়া যায়নি',
              message: 'পিডিএফ পড়তে নিরাপদ HTTPS লিংক প্রয়োজন।',
            )
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      widget.resource.titleBn?.trim().isNotEmpty == true
                          ? widget.resource.titleBn!
                          : widget.resource.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'আগের পৃষ্ঠা',
                          onPressed: _pageCount > 0 && _currentPage > 1
                              ? () => _goToPage(_currentPage - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          _pageCount == 0
                              ? 'পৃষ্ঠা লোড হচ্ছে…'
                              : 'পৃষ্ঠা $_currentPage / $_pageCount',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        IconButton(
                          tooltip: 'পরের পৃষ্ঠা',
                          onPressed: _pageCount > 0 && _currentPage < _pageCount
                              ? () => _goToPage(_currentPage + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'ছোট করুন',
                          onPressed: _pageCount > 0
                              ? () => _controller.zoomDown()
                              : null,
                          icon: const Icon(Icons.zoom_out),
                        ),
                        IconButton(
                          tooltip: 'বড় করুন',
                          onPressed: _pageCount > 0
                              ? () => _controller.zoomUp()
                              : null,
                          icon: const Icon(Icons.zoom_in),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: ref.read(pdfReaderRendererProvider)(
                        uri,
                        _controller,
                        PdfViewerParams(
                          backgroundColor: SukunColors.mist,
                          onViewerReady: (document, controller) {
                            if (!mounted) return;
                            setState(() {
                              _pageCount = controller.pageCount;
                              _currentPage = controller.pageNumber ?? 1;
                            });
                          },
                          onPageChanged: (page) {
                            if (!mounted || page == null) return;
                            setState(() => _currentPage = page);
                          },
                          loadingBannerBuilder: (context, bytes, total) =>
                              const AppLoadingState(label: 'পিডিএফ লোড হচ্ছে…'),
                          errorBannerBuilder: (context, error, trace, ref) =>
                              AppErrorState(
                                message:
                                    'পিডিএফটি অ্যাপের মধ্যে পড়া যাচ্ছে না। '
                                    'বাহিরের সার্ভারে সরাসরি PDF ফাইল ও '
                                    'Browser CORS অনুমতি থাকতে হবে।',
                                onRetry: _retry,
                                showSafeMessage: true,
                              ),
                        ),
                        ValueKey('pdf-reader-${widget.resource.id}-$_attempt'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
