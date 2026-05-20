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

    final accent = effectiveIsDanger
        ? const Color(0xFFE11D48)
        : const Color(0xFF10B981);
    final accentSoft = effectiveIsDanger
        ? const Color(0xFFFEF1F3)
        : const Color(0xFFE8F8F1);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EAF0)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatusPill(
              text: effectiveIsDanger ? '위험 감지' : '안전 상태',
              color: accent,
              soft: accentSoft,
            ),
            const SizedBox(height: 18),
            _PulseIcon(
              color: accent,
              soft: accentSoft,
              isDanger: effectiveIsDanger,
            ),
            const SizedBox(height: 16),
            Text(
              titleText,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: accent,
              ),
              textAlign: TextAlign.center,
            ),
            if (dirDeg != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FA),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5EAF0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Compass(angleDeg: dirDeg, color: accent),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '방향',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${dirDeg.toStringAsFixed(0)}°',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.color,
    required this.soft,
  });
  final String text;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(999),
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
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseIcon extends StatefulWidget {
  const _PulseIcon({
    required this.color,
    required this.soft,
    required this.isDanger,
  });
  final Color color;
  final Color soft;
  final bool isDanger;

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isDanger) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDanger && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.isDanger && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isDanger)
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final t = _ctrl.value;
                final size = 96 + t * 36;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: (1 - t) * 0.22),
                  ),
                );
              },
            ),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.soft,
            ),
            child: Icon(
              widget.isDanger
                  ? Icons.warning_amber_rounded
                  : Icons.shield_outlined,
              color: widget.color,
              size: 52,
            ),
          ),
        ],
      ),
    );
  }
}

class _Compass extends StatelessWidget {
  const _Compass({required this.angleDeg, required this.color});
  final double angleDeg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5EAF0), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ(-(angleDeg + 90) * math.pi / 180.0),
        child: Icon(Icons.arrow_forward_rounded, color: color, size: 34),
      ),
    );
  }
}
