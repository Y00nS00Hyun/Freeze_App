// lib/pages/event_viewer_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/events.dart';
import '../services/ws_client.dart';
import '../services/notification_service.dart';
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
    )..connect();
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

    _yam = YamnetEvent(
      event: e.event,
      source: e.source,
      label: label,
      confidence: e.confidence,
      direction: e.direction,
      energy: e.energy,
      ms: e.ms,
      danger: e.danger,
      group: e.group,
      dbfs: e.dbfs,
      latencySec: e.latencySec,
    );

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
    final h = MediaQuery.of(context).size.height;
    final yamHeight = (h * 0.50).clamp(380.0, 560.0);
    final displayed = _isHolding ? _holdYam : _yam;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF9FBFD),
        centerTitle: true,
        shape: const Border(
          bottom: BorderSide(
            color: Color.fromARGB(255, 151, 198, 206),
            width: 1.3,
          ),
        ),
        title: Text(
          'SOUND SENSE',
          style: GoogleFonts.gowunDodum(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: const Color(0xFF78B8C4),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'YOLO 결과 보기',
            onPressed: _openYoloPage,
            icon: const Icon(Icons.photo_camera_outlined, color: Colors.grey),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            SizedBox(
              height: yamHeight,
              child: Center(
                child: AnimatedOpacity(
                  opacity: displayed != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: YamnetCard(event: displayed),
                  ),
                ),
              ),
            ),
            Expanded(child: ClovaPanel(event: _clova)),
          ],
        ),
      ),
    );
  }
}
