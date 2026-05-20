// lib/widgets/yamnet_card.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/events.dart';

/// YAMNet 이벤트 표시 카드 (위험 라벨은 7초간 유지)
class YamnetCard extends StatefulWidget {
  const YamnetCard({super.key, this.event});
  final YamnetEvent? event;

  static const Duration _delayHold = Duration(seconds: 7);

  // 일부 서버 응답이 '{label: x, conf: y}' 형태의 문자열 라벨을 보내는 경우 대비
  static (String, double) _normalizeLabelAndConf(String rawLabel, double rawConf) {
    final s = rawLabel.trim();
    if (s.startsWith('{')) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          final label = (decoded['label'] ?? rawLabel).toString();
          final conf = (decoded['conf'] ?? decoded['confidence']) as num?;
          return (_stripQuotes(label), conf?.toDouble() ?? rawConf);
        }
      } catch (_) {
        // 무시: 일반 문자열로 처리
      }
    }
    return (_stripQuotes(s), rawConf);
  }

  static String _stripQuotes(String v) {
    final s = v.trim();
    if (s.length >= 2 &&
        ((s.startsWith('"') && s.endsWith('"')) ||
            (s.startsWith("'") && s.endsWith("'")))) {
      return s.substring(1, s.length - 1).trim();
    }
    return s;
  }

  static String _labelKo(String label) {
    final s = label.trim().toLowerCase();
    if (s == 'safe') return '안전';
    if (s == 'horn' || s == 'car horn') return '경적소리';
    return label.isEmpty ? '대기 중' : label;
  }

  static bool _isNonDanger(String label) {
    final s = label.trim().toLowerCase();
    return s == 'safe' || s == '안전';
  }

  static bool _shouldDelay(String label) {
    final s = label.trim().toLowerCase();
    return s == '사이렌' || s == '경적소리' || s == 'horn' || s == 'car horn';
  }

  @override
  State<YamnetCard> createState() => _YamnetCardState();
}

class _YamnetCardState extends State<YamnetCard>
    with AutomaticKeepAliveClientMixin {
  DateTime? _dangerUntil;
  Timer? _tick;
  String? _lastDangerKo;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _applyEvent(widget.event);
  }

  @override
  void didUpdateWidget(covariant YamnetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event != widget.event) {
      _applyEvent(widget.event);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _applyEvent(YamnetEvent? e) {
    if (e == null) {
      _startOrStopTicker();
      setState(() {});
      return;
    }

    final (label, _) = YamnetCard._normalizeLabelAndConf(e.label, e.confidence);
    final isDanger = e.danger ?? !YamnetCard._isNonDanger(label);

    if (isDanger) {
      _lastDangerKo = YamnetCard._labelKo(label);
    }

    if (YamnetCard._shouldDelay(label)) {
      final now = DateTime.now();
      if (_dangerUntil == null || now.isAfter(_dangerUntil!)) {
        _dangerUntil = now.add(YamnetCard._delayHold);
      }
    }

    _startOrStopTicker();
    setState(() {});
  }

  bool get _isDelayActive {
    final until = _dangerUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _startOrStopTicker() {
    if (_isDelayActive && _tick == null) {
      _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        if (!_isDelayActive) {
          _tick?.cancel();
          _tick = null;
        }
        setState(() {});
      });
    } else if (!_isDelayActive && _tick != null) {
      _tick?.cancel();
      _tick = null;
    }
  }

  double? _parseDirection(dynamic dir) {
    if (dir == null) return null;
    if (dir is num) {
      final v = dir.toDouble();
      final isRad = v.abs() <= 2 * math.pi + 1e-6;
      return isRad ? (v * 180.0 / math.pi) : v;
    }
    if (dir is String) {
      final direct = double.tryParse(dir);
      if (direct != null) return direct;
      final m = RegExp(
        r'(-?\d+(?:\.\d+)?)\s*(deg|°|rad)?',
        caseSensitive: false,
      ).firstMatch(dir);
      if (m != null) {
        final v = double.parse(m.group(1)!);
        final unit = (m.group(2) ?? 'deg').toLowerCase();
        return unit.contains('rad') ? (v * 180.0 / math.pi) : v;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final e = widget.event;
    if (e == null) return const SizedBox.shrink();

    final (label, _) = YamnetCard._normalizeLabelAndConf(e.label, e.confidence);

    final rawDirDeg = _parseDirection(e.direction);
    final dirDeg = (rawDirDeg == null || !rawDirDeg.isFinite)
        ? null
        : ((rawDirDeg % 360) + 360) % 360;

    final ko = YamnetCard._labelKo(label);
    final isNonDanger = YamnetCard._isNonDanger(label);
    final isDanger = e.danger ?? !isNonDanger;
    final effectiveIsDanger = _isDelayActive ? true : isDanger;

    final titleText = effectiveIsDanger
        ? (_isDelayActive && isNonDanger ? (_lastDangerKo ?? ko) : ko)
        : '안전';
    final titleColor =
        effectiveIsDanger ? Colors.redAccent : const Color(0xFF3BB273);

    final mainSymbol = effectiveIsDanger
        ? const Icon(
            Icons.warning_amber_rounded,
            color: Color.fromARGB(255, 255, 4, 0),
            size: 80,
          )
        : const Icon(Icons.check_circle, color: Color(0xFF3BB273), size: 80);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              mainSymbol,
              const SizedBox(height: 12),
              Text(
                titleText,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              if (dirDeg != null) ...[
                const Text(
                  '방향 정보',
                  style: TextStyle(fontSize: 30, color: Colors.black87),
                ),
                const SizedBox(height: 25),
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..rotateZ(-(dirDeg + 90) * math.pi / 180.0),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFB3E5EB),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
