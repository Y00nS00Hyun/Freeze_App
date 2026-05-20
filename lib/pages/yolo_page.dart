// lib/pages/yolo_page.dart
import 'package:flutter/material.dart';
import '../models/events.dart';
import '../utils/yolo_utils.dart';
import '../widgets/empty_state.dart';
import '../widgets/yolo_card.dart';
import 'event_viewer_page.dart' show BrandMark;

class YoloPage extends StatefulWidget {
  const YoloPage({
    super.key,
    required this.items,
    this.imageBaseUrl, // 예: http://<host>:<port>
  });

  final List<YoloEvent> items;
  final String? imageBaseUrl;

  @override
  State<YoloPage> createState() => _YoloPageState();
}

// 섹션 헤더 또는 카드 항목으로 펼친 리스트 엔트리
sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  const _HeaderRow(this.title);
  final String title;
}

class _CardRow extends _Row {
  const _CardRow({required this.imageUrl, required this.linkUrl, required this.fileName});
  final String imageUrl;
  final String? linkUrl;
  final String? fileName;
}

class _YoloPageState extends State<YoloPage> {
  DateTime? _selectedDate;

  // URL 정규화(절대/상대/127.0.0.1 교정)
  String? _normalizeUrl(String? url) {
    if (url == null) return null;
    final s = url.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('data:')) return s;

    final baseStr = widget.imageBaseUrl?.trim();
    final base = (baseStr != null && baseStr.isNotEmpty)
        ? Uri.tryParse(baseStr)
        : null;

    final u = Uri.tryParse(s);
    if (u != null && u.hasScheme) {
      final host = u.host.toLowerCase();
      if ((host == '127.0.0.1' || host == 'localhost') && base != null) {
        return Uri(
          scheme: base.scheme,
          host: base.host,
          port: base.hasPort ? base.port : null,
          path: u.path,
          query: u.query.isEmpty ? null : u.query,
          fragment: u.fragment.isEmpty ? null : u.fragment,
        ).toString();
      }
      return s;
    }

    if (base == null) return null;
    return base.resolve(s).toString();
  }

  // 썸네일 선택: thumbnail > jpg/png file > mp4→jpg 유추 > time 기반 파일명
  String? _pickDisplayImage(YoloEvent y) {
    final thumb = y.thumbnail?.trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;

    final file = (y.file ?? '').trim();
    final lower = file.toLowerCase();

    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png')) {
      return file;
    }
    if (lower.endsWith('.mp4')) {
      return file.replaceFirst(RegExp(r'\.mp4$', caseSensitive: false), '.jpg');
    }

    final name = fileNameFromEpoch(y.time);
    final base = widget.imageBaseUrl;
    if (name != null && base != null) {
      return '${base.replaceAll(RegExp(r'/+$'), '')}/$name';
    }
    return null;
  }

  bool _isSameCalendarDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate(List<YoloEvent> pool) async {
    final times = pool
        .map((e) => e.time ?? 0)
        .where((t) => t > 0)
        .toList()
      ..sort();

    final now = DateTime.now();
    final first = times.isEmpty
        ? now.subtract(const Duration(days: 365))
        : DateTime.fromMillisecondsSinceEpoch(times.first * 1000, isUtc: true).toLocal();
    final last = times.isEmpty
        ? now
        : DateTime.fromMillisecondsSinceEpoch(times.last * 1000, isUtc: true).toLocal();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? last,
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(last.year, last.month, last.day),
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
      locale: const Locale('ko', 'KR'),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // 표시 가능한 이벤트만 추려서, 날짜 섹션을 끼운 평탄화된 행 리스트로 반환
  List<_Row> _buildRows() {
    final visible = <(YoloEvent, String, String?)>[];
    for (final y in widget.items) {
      final rawLabel = y.label.trim();
      if (rawLabel.isEmpty || rawLabel.toLowerCase() == 'null') continue;

      final imageUrl = _normalizeUrl(_pickDisplayImage(y));
      if (imageUrl == null || !(Uri.tryParse(imageUrl)?.hasScheme ?? false)) continue;

      if (_selectedDate != null && y.time != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(
          y.time! * 1000,
          isUtc: true,
        ).toLocal();
        if (!_isSameCalendarDate(dt, _selectedDate!)) continue;
      }

      final linkRaw = (y.file?.trim().isNotEmpty == true) ? y.file!.trim() : imageUrl;
      visible.add((y, imageUrl, _normalizeUrl(linkRaw)));
    }

    // 시간 내림차순
    visible.sort((a, b) => (b.$1.time ?? 0).compareTo(a.$1.time ?? 0));

    final rows = <_Row>[];
    String? currentKey;
    for (final (y, imageUrl, linkUrl) in visible) {
      final key = dateKeyFromEpoch(y.time);
      if (key != currentKey) {
        rows.add(_HeaderRow(key));
        currentKey = key;
      }
      rows.add(_CardRow(
        imageUrl: imageUrl,
        linkUrl: linkUrl,
        fileName: fileNameFromEpoch(y.time),
      ));
    }
    return rows;
  }

  AppBar _buildAppBar() {
    return AppBar(
      titleSpacing: 8,
      title: const BrandMark(),
      iconTheme: const IconThemeData(color: Color(0xFF475569)),
      actions: [
        IconButton(
          tooltip: '날짜 선택',
          onPressed: () => _pickDate(widget.items),
          icon: const Icon(Icons.calendar_today_outlined),
          color: const Color(0xFF475569),
        ),
        if (_selectedDate != null)
          IconButton(
            tooltip: '필터 해제',
            onPressed: () => setState(() => _selectedDate = null),
            icon: const Icon(Icons.filter_alt_off_outlined),
            color: const Color(0xFF475569),
          ),
        const SizedBox(width: 8),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFE5EAF0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();

    if (rows.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FA),
        appBar: _buildAppBar(),
        body: const EmptyState(message: '현재 등록된 사진이 없습니다'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                if (_selectedDate != null)
                  _SelectedDateChip(
                    date: _selectedDate!,
                    onClear: () => setState(() => _selectedDate = null),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      return switch (row) {
                        _HeaderRow(:final title) => _SectionHeader(title: title),
                        _CardRow(:final imageUrl, :final linkUrl, :final fileName) =>
                          YoloCard(
                            imageUrl: imageUrl,
                            linkUrl: linkUrl,
                            fileName: fileName,
                          ),
                      };
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF0E9AAB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedDateChip extends StatelessWidget {
  const _SelectedDateChip({required this.date, required this.onClear});
  final DateTime date;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    String two(int v) => v.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F6F8),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFB7D7DE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: Color(0xFF0E9AAB),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${date.year}.${two(date.month)}.${two(date.day)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0E9AAB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Color(0xFF0E9AAB),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
