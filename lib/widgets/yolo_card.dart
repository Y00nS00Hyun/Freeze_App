import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/tokens.dart';

/// 공용 YOLO 카드
/// - 이미지 로드 성공 시에만 렌더링(프로빙)
class YoloCard extends StatefulWidget {
  const YoloCard({
    super.key,
    required this.imageUrl,
    this.fileName,
    this.linkUrl,
  });

  final String imageUrl;
  final String? fileName;
  final String? linkUrl;

  @override
  State<YoloCard> createState() => _YoloCardState();
}

class _YoloCardState extends State<YoloCard> {
  bool _imageOk = false;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _probeImage(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant YoloCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _disposeStream();
      _imageOk = false;
      _probeImage(widget.imageUrl);
    }
  }

  void _probeImage(String url) {
    final provider = NetworkImage(url);
    final stream = provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener(
      (ImageInfo _, bool __) {
        if (!mounted) return;
        setState(() => _imageOk = true);
      },
      onError: (dynamic _, StackTrace? __) {
        if (!mounted) return;
        setState(() => _imageOk = false);
      },
    );
    stream.addListener(_listener!);
    _stream = stream;
  }

  void _disposeStream() {
    if (_listener != null && _stream != null) {
      _stream!.removeListener(_listener!);
    }
    _listener = null;
    _stream = null;
  }

  @override
  void dispose() {
    _disposeStream();
    super.dispose();
  }

  String get _targetUrl {
    final t = (widget.linkUrl?.trim().isNotEmpty == true)
        ? widget.linkUrl!.trim()
        : widget.imageUrl.trim();
    return t;
  }

  bool get _hasLink => (Uri.tryParse(_targetUrl)?.hasScheme ?? false);

  Future<void> _openExternal(BuildContext context) async {
    if (!_hasLink) return;
    final ok = await launchUrl(
      Uri.parse(_targetUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('링크를 열 수 없어요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_imageOk) return const SizedBox.shrink();

    final hasLink = _hasLink;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: hasLink ? () => _openExternal(context) : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                child: AspectRatio(
                  aspectRatio: 16 / 11,
                  child: Image.network(widget.imageUrl, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.fileName != null && widget.fileName!.isNotEmpty)
                  Expanded(
                    child: Text(
                      widget.fileName!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (hasLink)
                  TextButton.icon(
                    onPressed: () => _openExternal(context),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('다운로드'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: AppColors.primarySoft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
