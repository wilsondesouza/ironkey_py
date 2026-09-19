import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'IronKey Mobile';
  static const String appVersion = '1.0.0';
  static const int schemaVersion = 3;
  static const int tombstoneRetentionDays = 90;
  static const int defaultAutoLockSeconds = 300; // 5 minutos
  static const int clipboardClearSeconds = 30;

  static const String syncDocMagic = 'IronKeyPy-Sync';
  static const String enrollMagic = 'IronKeyPy-Enroll';
  static const String manifestMagic = 'IronKeyPy-Manifest';
}

class AppColors {
  // Paleta Dark (Padrão IronKey)
  static const Color darkBg = Color(0xFF0F141C);
  static const Color darkCard = Color(0xFF1B222C);
  static const Color darkCardHover = Color(0xFF242C39);
  static const Color darkBorder = Color(0xFF2D3748);
  
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryHover = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF3B82F6);
  
  static const Color accent = Color(0xFF38BDF8);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textSubtle = Color(0xFF64748B);
}
