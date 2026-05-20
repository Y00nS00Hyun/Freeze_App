// lib/theme/tokens.dart
import 'package:flutter/widgets.dart';

/// 앱 전역 색상 토큰
class AppColors {
  AppColors._();

  // Surface
  static const Color bg = Color(0xFFF6F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF6F8FA);
  static const Color border = Color(0xFFE5EAF0);

  // Text / Icon
  static const Color ink = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color iconMuted = Color(0xFF475569);

  // Brand (teal)
  static const Color primary = Color(0xFF0E9AAB);
  static const Color primaryLight = Color(0xFF18C0D2);
  static const Color primarySoft = Color(0xFFE6F6F8);
  static const Color primarySoftBorder = Color(0xFFB7D7DE);

  // Status
  static const Color danger = Color(0xFFE11D48);
  static const Color dangerSoft = Color(0xFFFEF1F3);
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFE8F8F1);
  static const Color warning = Color(0xFFEAB308);
}

/// 모서리 반경 토큰
class AppRadius {
  AppRadius._();
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;
}

/// 그라데이션 토큰
class AppGradients {
  AppGradients._();
  static const LinearGradient brand = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
