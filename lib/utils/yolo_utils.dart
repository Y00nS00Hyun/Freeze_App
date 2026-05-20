// lib/utils/yolo_utils.dart

String? fileNameFromEpoch(int? epochSec) {
  if (epochSec == null) return null;
  final dt = DateTime.fromMillisecondsSinceEpoch(
    epochSec * 1000,
    isUtc: true,
  ).toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}_${two(dt.month)}_${two(dt.day)}_'
      '${two(dt.hour)}${two(dt.minute)}${two(dt.second)}.jpg';
}

String dateKeyFromEpoch(int? epochSec) {
  if (epochSec == null) return 'unknown';
  final dt = DateTime.fromMillisecondsSinceEpoch(
    epochSec * 1000,
    isUtc: true,
  ).toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
}
