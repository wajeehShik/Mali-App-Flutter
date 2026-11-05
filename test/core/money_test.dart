import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/utils/money.dart';

void main() {
  group('Money.tryParse', () {
    test('يحلل أعدادًا عشرية وصحيحة', () {
      expect(Money.tryParse('12.50'), const Money(1250));
      expect(Money.tryParse('12'), const Money(1200));
      expect(Money.tryParse('.5'), const Money(50));
      expect(Money.tryParse('0.05'), const Money(5));
    });

    test('يقبل الأرقام العربية والفاصل العشري العربي', () {
      expect(Money.tryParse('١٢٫٥٠'), const Money(1250));
      expect(Money.tryParse('٣'), const Money(300));
    });

    test('يتجاهل فواصل الآلاف والمسافات', () {
      expect(Money.tryParse('1,250.5'), const Money(125050));
      expect(Money.tryParse('1٬250'), const Money(125000));
      expect(Money.tryParse(' 1 250 '), const Money(125000));
    });

    test('يدعم الإشارات', () {
      expect(Money.tryParse('-3.2'), const Money(-320));
      expect(Money.tryParse('+5'), const Money(500));
    });

    test('يرفض الكسور الزائدة غير الصفرية ويقبل الأصفار الزائدة', () {
      expect(Money.tryParse('12.345'), isNull);
      expect(Money.tryParse('12.500'), const Money(1250));
    });

    test('يرفض المدخلات غير الصالحة', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('   '), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('.'), isNull);
      expect(Money.tryParse('1.2.3'), isNull);
      expect(Money.tryParse('12a'), isNull);
    });

    test('يرفض الأعداد الضخمة جدًا', () {
      expect(Money.tryParse('1234567890123'), isNull);
    });

    test('يعمل مع decimals = 0', () {
      expect(Money.tryParse('15', decimals: 0), const Money(15));
      expect(Money.tryParse('15.0', decimals: 0), const Money(15));
      expect(Money.tryParse('15.5', decimals: 0), isNull);
    });
  });

  group('Money.format', () {
    test('ينسق مع فواصل آلاف وخانتين عشريتين', () {
      expect(const Money(125050).format(), '\u200E1,250.50\u200E');
      expect(const Money(5).format(), '\u200E0.05\u200E');
      expect(Money.zero.format(), '\u200E0.00\u200E');
    });

    test('ينسق القيم السالبة', () {
      expect(const Money(-5).format(), '\u200E-0.05\u200E');
      expect(const Money(-125050).format(), '\u200E-1,250.50\u200E');
    });

    test('يضيف الرمز ويدعم decimals مختلفة', () {
      expect(
        const Money(125050).format(symbol: 'USD'),
        '\u200E1,250.50\u200E USD',
      );
      expect(const Money(1500).format(decimals: 0), '\u200E1,500\u200E');
      expect(const Money(1234).format(decimals: 3), '\u200E1.234\u200E');
    });

    test('يرفض decimals خارج النطاق', () {
      expect(
        () => Money.zero.format(decimals: 5),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Money.toDecimalString', () {
    test('نص خام للتصدير', () {
      expect(const Money(125050).toDecimalString(), '1250.50');
      expect(const Money(-5).toDecimalString(), '-0.05');
      expect(const Money(15).toDecimalString(decimals: 0), '15');
    });

    test('عكسية مع tryParse', () {
      for (final minor in [0, 1, 99, 100, 123456, -7, -100000]) {
        final text = Money(minor).toDecimalString();
        expect(Money.tryParse(text), Money(minor), reason: text);
      }
    });
  });

  group('Money العمليات', () {
    test('الجمع والطرح والنفي والقيمة المطلقة', () {
      expect(const Money(100) + const Money(250), const Money(350));
      expect(const Money(100) - const Money(250), const Money(-150));
      expect(-const Money(100), const Money(-100));
      expect(const Money(-100).abs(), const Money(100));
    });

    test('الضرب في كمية صحيحة', () {
      expect(const Money(250) * 3, const Money(750));
    });

    test('الضرب في عامل عشري مع التقريب بعيدًا عن الصفر', () {
      expect(const Money(100).scaled(1.5), const Money(150));
      expect(const Money(5).scaled(0.5), const Money(3));
      expect(const Money(-5).scaled(0.5), const Money(-3));
    });

    test('المقارنات والترتيب', () {
      expect(const Money(1) < const Money(2), isTrue);
      expect(const Money(2) <= const Money(2), isTrue);
      expect(const Money(3) > const Money(2), isTrue);
      expect(const Money(2) >= const Money(3), isFalse);

      final sorted = [const Money(30), const Money(-5), const Money(10)]
        ..sort();
      expect(sorted, [const Money(-5), const Money(10), const Money(30)]);
    });

    test('الخصائص المساعدة', () {
      expect(Money.zero.isZero, isTrue);
      expect(const Money(-1).isNegative, isTrue);
      expect(const Money(1).isPositive, isTrue);
    });

    test('المساواة وhashCode', () {
      expect(const Money(100), const Money(100));
      expect(const Money(100).hashCode, const Money(100).hashCode);
      expect(const Money(100) == const Money(101), isFalse);
    });

    test('total يجمع قائمة المبالغ', () {
      expect(
        [const Money(100), const Money(250), const Money(-50)].total,
        const Money(300),
      );
      expect(<Money>[].total, Money.zero);
    });
  });
}