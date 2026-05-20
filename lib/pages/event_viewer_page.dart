// lib/pages/event_viewer_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/events.dart';
import '../services/ws_client.dart';
import '../services/notification_service.dart';
import '../theme/tokens.dart';
import '../widgets/yamnet_card.dart';
import '../widgets/clova_panel.dart';
import 'yolo_page.dart';

class EventViewerPage extends StatefulWidget {
  const EventViewerPage({super.key, required this.endpoint});
  final String endpoint;

  @override
  State<EventViewerPage> createState() => _EventViewerPageState();
}

class _EventViewerPageState extends State<EventViewerPage> {
  static const double _minConfidence = 0.30;
  static const Duration _dangerHold = Duration(seconds: 7);
  static const Duration _yamNotiCooldown = Duration(seconds: 3);
  static const Duration _clovaNotiCooldown = Duration(seconds: 2);
  static const int _maxYoloHistory = 100;

  // 비위험으로 간주할 라벨 키워드 (음성류 / safe)
  static const Set<String> _nonDangerKeywords = {
    'speech', 'talking', 'conversation', 'narration', 'monologue',
    'debate', 'dialogue', 'chant', 'narrator', 'singing', 'silence', 'safe',
  };

  late final WsClient _ws;

  YamnetEvent? _yam;
  YamnetEvent? _holdYam;
  ClovaEvent? _clova;
  final List<YoloEvent> _yolos = [];
  final Set<String> _yoloKeys = {};

  Timer? _yamHideTimer;
  DateTime? _dangerHoldUntil;

  String _wsState = 'connecting';

  // YAMNet 위험 알림 쿨다운
  String? _lastYamNotiKey;
  DateTime _lastYamNotiAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Clova 알림 쿨다운
  String? _lastClovaText;
  DateTime _lastClovaNotiAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _isHolding =>
      _dangerHoldUntil != null && DateTime.now().isBefore(_dangerHoldUntil!);

  @override
  void initState() {
    super.initState();
    _ws = WsClient(
      widget.endpoint,
      onEvent: _onEvent,
      onState: _onState,
    );
    unawaited(_ws.connect());
  }

  @override
  void dispose() {
    _yamHideTimer?.cancel();
    _ws.dispose();
    super.dispose();
  }

  void _onEvent(EventBase evt) {
    if (!mounted) return;

    if (evt is YamnetEvent) {
      _onYamnet(evt);
    } else if (evt is ClovaEvent) {
      setState(() => _clova = evt);
      _maybeNotifyClova(evt.text);
    } else if (evt is YoloEvent) {
      _onYolo(evt);
    }
  }

  Future<void> _onState(String s) async {
    if (!mounted) return;
    setState(() => _wsState = s);
    if (s == 'connected') {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      _ws.sendJson({'action': 'subscribe', 'topic': 'public'});
      _ws.sendJson({'action': 'subscribe', 'topic': 'app'});
    }
  }

  // ── YAMNet ────────────────────────────────────────────────────────
  void _onYamnet(YamnetEvent e) {
    final label = e.label.trim().isEmpty ? 'Unknown' : e.label.trim();
    final isDanger =
        (e.danger ?? !_isNonDanger(label)) && e.confidence >= _minConfidence;

    if (_isHolding && !isDanger) return;

    _yam = e.copyWith(label: label);

    if (isDanger) {
      _holdYam = _yam;
      _dangerHoldUntil = DateTime.now().add(_dangerHold);

      _yamHideTimer?.cancel();
      _yamHideTimer = Timer(_dangerHold, () {
        if (!mounted) return;
        setState(() => _dangerHoldUntil = null);
      });

      _notifyYamnetDanger(label, e.confidence, e.ms);
    }
    setState(() {});
  }

  void _notifyYamnetDanger(String label, double conf, int? ms) {
    final key = '${ms ?? 0}:${label.toLowerCase()}';
    final now = DateTime.now();
    final isCoolingDown = _lastYamNotiKey == key &&
        now.difference(_lastYamNotiAt) < _yamNotiCooldown;
    if (isCoolingDown) return;

    _lastYamNotiKey = key;
    _lastYamNotiAt = now;
    NotiService.I.showNow(
      title: '⚠️ 비상 상황 감지',
      body: '$label · 신뢰도 ${(conf * 100).toStringAsFixed(0)}%',
    );
  }

  static bool _isNonDanger(String label) {
    final s = label.toLowerCase();
    return _nonDangerKeywords.any(s.contains);
  }

  // ── Clova ─────────────────────────────────────────────────────────
  void _maybeNotifyClova(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    // 점만 있는 텍스트는 알림 제외 (예: ".", "..", "...")
    if (RegExp(r'^\.+$').hasMatch(text)) return;

    final now = DateTime.now();
    final keyChanged = _lastClovaText != text;
    final timeOk = now.difference(_lastClovaNotiAt) >= _clovaNotiCooldown;
    if (!keyChanged && !timeOk) return;

    _lastClovaText = text;
    _lastClovaNotiAt = now;
    NotiService.I.showNow(title: '🗣️ 음성 인식', body: text);
  }

  // ── YOLO ──────────────────────────────────────────────────────────
  void _onYolo(YoloEvent e) {
    if (e.event.toLowerCase() == 'yolo_recording_done') return;

    final key = _yoloKeyOf(e);
    if (_yoloKeys.contains(key)) return;
    _yoloKeys.add(key);

    _yolos.insert(0, e);
    if (_yolos.length > _maxYoloHistory) {
      final removed = _yolos.removeLast();
      _yoloKeys.remove(_yoloKeyOf(removed));
    }
    setState(() {});
  }

  String _yoloKeyOf(YoloEvent e) {
    final f = e.file?.trim();
    if (f != null && f.isNotEmpty) return f;
    return '${e.time ?? 0}:${e.label}'.toLowerCase();
  }

  // ── Navigation ────────────────────────────────────────────────────
  String? _httpBaseFromWs(String wsEndpoint) {
    final u = Uri.tryParse(wsEndpoint);
    if (u == null) return null;
    final scheme = u.scheme == 'wss' ? 'https' : 'http';
    final port = u.hasPort ? ':${u.port}' : '';
    return '$scheme://${u.host}$port';
  }

  void _openYoloPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YoloPage(
          items: _yolos,
          imageBaseUrl: _httpBaseFromWs(widget.endpoint),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 600;
    final yamHeight = (size.height * 0.46).clamp(340.0, 500.0);
    final displayed = _isHolding ? _holdYam : _yam;
    final connected = _wsState == 'connected';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        titleSpacing: 20,
        title: const BrandMark(),
        actions: [
          ConnectionPill(connected: connected),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'YOLO 결과 보기',
            onPressed: _openYoloPage,
            icon: const Icon(Icons.photo_library_outlined),
            color: AppColors.iconMuted,
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    height: yamHeight,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: displayed != null
                          ? KeyedSubtree(
                              key: const ValueKey('yamnet'),
                              child: YamnetCard(event: displayed),
                            )
                          : KeyedSubtree(
                              key: const ValueKey('idle'),
                              child: _IdleStatusCard(connected: connected),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: ClovaPanel(event: _clova),
                    ),
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

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: AppGradients.brand,
          ),
          child: const Icon(
            Icons.graphic_eq_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Sound Sense',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class ConnectionPill extends StatelessWidget {
  const ConnectionPill({super.key, required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.success : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              connected ? 'LIVE' : 'CONNECTING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleStatusCard extends StatelessWidget {
  const _IdleStatusCard({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primarySoft,
            ),
            child: Icon(
              connected ? Icons.hearing_outlined : Icons.wifi_tethering_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            connected ? '소리를 듣고 있어요' : '연결 중...',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            connected
                ? '주변 소리를 감지하면 여기에 알려드릴게요'
                : '서버에 연결하고 있습니다',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
