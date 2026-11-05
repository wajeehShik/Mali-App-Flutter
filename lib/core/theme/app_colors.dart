import 'package:flutter/material.dart';

/// ألوان تطبيق مالي. المصدر الوحيد للألوان في المشروع.
abstract final class AppColors {
  // الألوان الأساسية
  static const Color primary = Color(0xFF166534);
  static const Color secondary = Color(0xFF14532D);

  // الخلفيات والأسطح
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);

  // النصوص
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);

  // الحالات
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);

  // ألوان مساعدة (مشتقة من الهوية، تُستخدم للحدود والخلفيات الخفيفة)
  static const Color border = Color(0xFFE2E8F0);
  static const Color primarySoft = Color(0xFFDCFCE7);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color errorSoft = Color(0xFFFEE2E2);
}