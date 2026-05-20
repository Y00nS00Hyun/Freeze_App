// lib/utils/yolo_utils.dart

/// 두 자리로 zero-pad
String pad2(int v) => v.toString().padLeft(2, '0');

String? fileNameFromEpoch(int? epochSec) {
  if (epochSec == null) return null;
  final dt = DateTime.fromMillisecondsSinceEpoch(
    epochSec * 1000,
    isUtc: true,
  ).toLocal();
  return '${dt.year}_${pad2(dt.month)}_${pad2(dt.day)}_'
      '${pad2(dt.hour)}${pad2(dt.minute)}${pad2(dt.second)}.jpg';
}

String dateKeyFromEpoch(int? epochSec) {
  if (epochSec == null) return 'unknown';
  final dt = DateTime.fromMillisecondsSinceEpoch(
    epochSec * 1000,
    isUtc: true,
  ).toLocal();
  return '${dt.year}-${pad2(dt.month)}-${pad2(dt.day)}';
}
