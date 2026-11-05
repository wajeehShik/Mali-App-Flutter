import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// مبلغ مالي مخزَّن كعدد صحيح بأصغر وحدة نقدية (minor units).
///
/// مثال: مع decimals = 2 يكون Money(1250) هو 12.50.
/// عدد الخانات العشرية يُمرَّر عند التنسيق والتحليل، وسيأتي لاحقًا من إعدادات العملة.
@immutable
final class Money implements Comparable<Money> {
  const Money(this.minor);

  /// أصغر وحدة نقدية (قرش/هللة...).
  final int minor;

  static const Money zero = Money(0);

  /// عدد الخانات العشرية الافتراضي.
  static const int defaultDecimals = 2;

  static const List<int> _pow10 = [1, 10, 100, 1000, 10000];
  static final NumberFormat _grouping = NumberFormat('#,##0', 'en');

  static int _factor(int decimals) {
    assert(
      decimals >= 0 && decimals < _pow10.length,
      'decimals must be between 0 and 4',
    );
    return _pow10[decimals];
  }

  /// يحلل نصًا أدخله المستخدم إلى مبلغ، أو يعيد null إن كان غير صالح.
  ///
  /// - يقبل الأرقام العربية (٠-٩) والفارسية (۰-۹).
  /// - يقبل الفاصل العشري "." أو "٫" ويتجاهل فواصل الآلاف "," أو "٬" والمسافات.
  /// - يرفض الكسور الأطول من [decimals] إلا إذا كانت الخانات الزائدة أصفارًا.
  static Money? tryParse(String input, {int decimals = defaultDecimals}) {
    var text = _normalizeDigits(input).trim();
    if (text.isEmpty) {
      return null;
    }
    text = text
        .replaceAll(RegExp(r'[,\u066C\s]'), '')
        .replaceAll('\u066B', '.');

    final match = RegExp(r'^([+-])?(\d+)?(?:\.(\d+))?$').firstMatch(text);
    if (match == null) {
      return null;
    }

    final sign = match.group(1);
    final wholeText = match.group(2);
    var fracText = match.group(3) ?? '';
    if (wholeText == null && fracText.isEmpty) {
      return null;
    }
    if ((wholeText?.length ?? 0) > 12) {
      return null;
    }

    if (fracText.length > decimals) {
      final extra = fracText.substring(decimals);
      if (extra.replaceAll('0', '').isNotEmpty) {
        return null;
      }
      fracText = fracText.substring(0, decimals);
    }
    fracText = fracText.padRight(decimals, '0');

    final whole = int.tryParse(wholeText ?? '0');
    if (whole == null) {
      return null;
    }
    final frac = fracText.isEmpty ? 0 : int.parse(fracText);
    final value = whole * _factor(decimals) + frac;
    return Money(sign == '-' ? -value : value);
  }

  static String _normalizeDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(rune - 0x0660 + 0x30);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(rune - 0x06F0 + 0x30);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;
  bool get isPositive => minor > 0;

  Money abs() => Money(minor.abs());

  Money operator +(Money other) => Money(minor + other.minor);
  Money operator -(Money other) => Money(minor - other.minor);
  Money operator -() => Money(-minor);

  /// الضرب في كمية صحيحة.
  Money operator *(int quantity) => Money(minor * quantity);

  /// الضرب في عامل عشري (كمية بالوزن أو نسبة). التقريب لأقرب وحدة، والنصف بعيدًا عن الصفر.
  Money scaled(double factor) => Money((minor * factor).round());

  bool operator <(Money other) => minor < other.minor;
  bool operator <=(Money other) => minor <= other.minor;
  bool operator >(Money other) => minor > other.minor;
  bool operator >=(Money other) => minor >= other.minor;

  @override
  int compareTo(Money other) => minor.compareTo(other.minor);

  /// نص للعرض في الواجهة، مثل: 1,250.50 (أرقام لاتينية مع فواصل آلاف).
  ///
  /// يُحاط الرقم بعلامة LRM حتى لا ينقلب موضع الإشارة السالبة داخل نص RTL.
  String format({int decimals = defaultDecimals, String? symbol}) {
    final factor = _factor(decimals);
    final absolute = minor.abs();
    final whole = absolute ~/ factor;
    final frac = absolute % factor;

    final buffer = StringBuffer('\u200E');
    if (minor < 0) {
      buffer.write('-');
    }
    buffer.write(_grouping.format(whole));
    if (decimals > 0) {
      buffer
        ..write('.')
        ..write(frac.toString().padLeft(decimals, '0'));
    }
    buffer.write('\u200E');

    final text = buffer.toString();
    return symbol == null ? text : '$text $symbol';
  }

  /// نص خام بلا فواصل آلاف ولا علامات اتجاه، للتصدير (CSV/Excel) والتخزين النصي.
  String toDecimalString({int decimals = defaultDecimals}) {
    final factor = _factor(decimals);
    final absolute = minor.abs();
    final whole = absolute ~/ factor;
    final frac = absolute % factor;
    final sign = minor < 0 ? '-' : '';
    if (decimals == 0) {
      return '$sign$whole';
    }
    return '$sign$whole.${frac.toString().padLeft(decimals, '0')}';
  }

  @override
  bool operator ==(Object other) => other is Money && other.minor == minor;

  @override
  int get hashCode => minor.hashCode;

  @override
  String toString() => 'Money($minor)';
}

extension MoneyIterableX on Iterable<Money> {
  /// مجموع المبالغ.
  Money get total => fold(Money.zero, (sum, item) => sum + item);
}