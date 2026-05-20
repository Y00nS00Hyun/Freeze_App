// lib/models/events.dart
import 'dart:convert';

/// 모든 수신 이벤트의 공통 베이스
abstract class EventBase {
  final String event; // ex) 'yamnet', 'transcript', 'yolo'
  final String source; // ex) 'yamnet', 'whisper', 'clova', 'yolo'

  const EventBase({required this.event, required this.source});

  /// 서버에서 온 JSON을 적절한 이벤트 클래스로 라우팅
  factory EventBase.fromJson(Map<String, dynamic> j) {
    final src = (j['source'] ?? '').toString().toLowerCase();
    final ty = (j['type'] ?? j['event'] ?? '').toString().toLowerCase();

    // 1) YOLO
    if (src == 'yolo' ||
        ty == 'yolo' ||
        ty == 'snapshot' ||
        ty == 'yolo_recording_done') {
      return YoloEvent.fromJson(j);
    }

    // 2) STT (Clova/Whisper/Transcript)
    if (src == 'clova' ||
        src == 'whisper' ||
        ty == 'clova' ||
        ty == 'stt' ||
        ty == 'whisper' ||
        ty == 'transcript' ||
        j.containsKey('transcript')) {
      return ClovaEvent.fromJson(j);
    }

    // 3) YAMNet (명시적 src/type 또는 분류 결과 키가 있는 경우만)
    final hasClassification = j.containsKey('cat') ||
        j.containsKey('raw') ||
        j.containsKey('danger') ||
        j.containsKey('group') ||
        ((j.containsKey('label') || j.containsKey('name')) &&
            (j.containsKey('confidence') ||
                j.containsKey('conf') ||
                j.containsKey('score')));

    if (src == 'yamnet' || ty == 'yamnet' || hasClassification) {
      return YamnetEvent.fromJson(j);
    }

    return UnknownEvent(j);
  }

  @override
  String toString() => '$runtimeType(event=$event, source=$source)';
}

/// ─────────────────────────────────────────────────────────────────
/// 공용 파서 유틸
double _asDouble(dynamic v, [double d = 0]) =>
    (v is num) ? v.toDouble() : (double.tryParse((v ?? '').toString()) ?? d);

int _asInt(dynamic v, [int d = 0]) =>
    (v is num) ? v.toInt() : (int.tryParse((v ?? '').toString()) ?? d);

num? _asNumNullable(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString());
}

double? _asDoubleNullable(dynamic v) => _asNumNullable(v)?.toDouble();
int? _asIntNullable(dynamic v) => _asNumNullable(v)?.toInt();

List<num> _asNumList(dynamic v) => (v is List)
    ? v.map<num>((e) => _asNumNullable(e) ?? 0).toList(growable: false)
    : const <num>[];

String? _headText(String? s) {
  if (s == null) return null;
  final i = s.indexOf('(');
  return (i > 0 ? s.substring(0, i) : s).trim();
}

double? _extractParenScore(String? s) {
  if (s == null) return null;
  final i = s.indexOf('(');
  final j = s.indexOf(')', i + 1);
  if (i >= 0 && j > i) return double.tryParse(s.substring(i + 1, j));
  return null;
}

double? _parseLatencySeconds(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final numStr = v.toString().replaceAll(RegExp(r'[^0-9\.\-]'), '');
  return double.tryParse(numStr);
}

double? _parsePercentish(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  final n = double.tryParse(s.replaceAll('%', ''));
  if (n == null) return null;
  return s.endsWith('%') ? n / 100.0 : n;
}

/// ─────────────────────────────────────────────────────────────────
/// YOLO 이벤트
class YoloEvent extends EventBase {
  final String label;
  final double confidence;
  final List<num> bbox;
  final int? time;
  final String? file;
  final String? thumbnail;

  const YoloEvent({
    required super.event,
    required super.source,
    required this.label,
    required this.confidence,
    required this.bbox,
    this.time,
    this.file,
    this.thumbnail,
  });

  factory YoloEvent.fromJson(Map<String, dynamic> j) {
    final ty = (j['type'] ?? j['event'] ?? '').toString().toLowerCase();
    final dataUrl = j['data']?.toString();
    final rawTime = j['time'] ?? j['ts'] ?? j['timestamp'];

    return YoloEvent(
      event: (j['event'] ?? j['type'] ?? '').toString(),
      source: (j['source'] ?? 'yolo').toString(),
      label: (j['group_label'] ??
              j['label'] ??
              (ty == 'snapshot' ? 'snapshot' : ''))
          .toString(),
      confidence: _asDouble(j['group_conf'] ?? j['confidence']),
      bbox: _asNumList(j['bbox']),
      time: rawTime == null ? null : _asInt(rawTime),
      file: _pickFileUrl(j) ?? dataUrl,
      thumbnail: (j['thumbnail'] ?? j['thumb'] ?? dataUrl)?.toString(),
    );
  }

  static String? _pickFileUrl(Map<String, dynamic> j) {
    final top = j['file'];
    if (top is String && top.trim().isNotEmpty) return top.trim();

    final files = j['files'];
    if (files is Map) {
      for (final key in const ['snapshot_url', 'video_url', 'file', 'url']) {
        final v = files[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    return null;
  }
}

/// ─────────────────────────────────────────────────────────────────
/// STT(Clova/Whisper/Transcript) 이벤트
class ClovaEvent extends EventBase {
  final String text;
  final String? kind;
  final int? sr;
  final double? dur;
  final double? dbfs;

  const ClovaEvent({
    required super.event,
    required super.source,
    required this.text,
    this.kind,
    this.sr,
    this.dur,
    this.dbfs,
  });

  factory ClovaEvent.fromJson(Map<String, dynamic> j) {
    return ClovaEvent(
      event: (j['event'] ?? j['type'] ?? 'transcript').toString(),
      source: (j['source'] ?? 'clova').toString(),
      text: (j['transcript'] ?? j['text'] ?? j['sentence'] ?? '').toString(),
      kind: j['kind']?.toString(),
      sr: _asIntNullable(j['sr']),
      dur: _asDoubleNullable(j['dur']),
      dbfs: _asDoubleNullable(j['dbfs']),
    );
  }

  @override
  String toString() =>
      'ClovaEvent(text="$text", kind=$kind, sr=$sr, dur=$dur, dbfs=$dbfs)';
}

/// ─────────────────────────────────────────────────────────────────
/// YAMNet 이벤트
class YamnetEvent extends EventBase {
  final String label;
  final double confidence;
  final num? direction;
  final num? energy;
  final int? ms;
  final bool? danger;
  final String? group;
  final double? dbfs;
  final double? latencySec;

  const YamnetEvent({
    required super.event,
    required super.source,
    required this.label,
    required this.confidence,
    this.direction,
    this.energy,
    this.ms,
    this.danger,
    this.group,
    this.dbfs,
    this.latencySec,
  });

  YamnetEvent copyWith({
    String? event,
    String? source,
    String? label,
    double? confidence,
    num? direction,
    num? energy,
    int? ms,
    bool? danger,
    String? group,
    double? dbfs,
    double? latencySec,
  }) {
    return YamnetEvent(
      event: event ?? this.event,
      source: source ?? this.source,
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      direction: direction ?? this.direction,
      energy: energy ?? this.energy,
      ms: ms ?? this.ms,
      danger: danger ?? this.danger,
      group: group ?? this.group,
      dbfs: dbfs ?? this.dbfs,
      latencySec: latencySec ?? this.latencySec,
    );
  }

  factory YamnetEvent.fromJson(Map<String, dynamic> j) {
    final label = ((j['label'] ?? j['name'])?.toString().trim() ??
            _headText((j['raw'] ?? j['cat'])?.toString()) ??
            '')
        .trim();

    var conf = _parsePercentish(j['confidence']) ??
        _parsePercentish(j['conf']) ??
        _parsePercentish(j['score']) ??
        _extractParenScore(j['raw']?.toString()) ??
        _extractParenScore(j['cat']?.toString()) ??
        0.0;
    if (conf > 1.0) conf = conf / 100.0;
    conf = conf.clamp(0.0, 1.0);

    return YamnetEvent(
      event: (j['event'] ?? j['type'] ?? 'yamnet').toString(),
      source: (j['source'] ?? 'yamnet').toString(),
      label: label,
      confidence: conf,
      direction: _asNumNullable(j['direction'] ?? j['dir']),
      energy: _asNumNullable(j['energy'] ?? j['rms'] ?? j['db']),
      ms: _asIntNullable(j['ms'] ?? j['timestamp']),
      danger: j['danger'] is bool ? j['danger'] as bool : null,
      group: j['group']?.toString(),
      dbfs: _asDoubleNullable(j['dbfs']),
      latencySec: _parseLatencySeconds(j['latency']),
    );
  }

  @override
  String toString() =>
      'YamnetEvent(label=$label, conf=$confidence, dir=$direction, energy=$energy, ms=$ms)';
}

/// ─────────────────────────────────────────────────────────────────
/// 알 수 없는 이벤트
class UnknownEvent extends EventBase {
  final Map<String, dynamic> raw;

  UnknownEvent(this.raw)
      : super(
          event: (raw['event'] ?? raw['type'] ?? 'info').toString(),
          source: (raw['source'] ?? 'unknown').toString(),
        );

  @override
  String toString() => 'UnknownEvent(raw=$raw)';
}

/// 디버깅용 pretty JSON
String prettyJsonBody(List<int> bodyBytes) {
  final s = utf8.decode(bodyBytes);
  try {
    return const JsonEncoder.withIndent('  ').convert(json.decode(s));
  } catch (_) {
    return s;
  }
}
