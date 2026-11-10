import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/exports/data/transaction_export_service.dart';
import 'package:mali/features/transactions/domain/transaction_entry.dart';

void main() {
  const pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDirectory;

  const service = TransactionExportService();

  final transactions = [
    TransactionEntry(
      id: 'sale-test-1',
      type: FinancialTransactionType.sale,
      date: DateTime.utc(2026, 11, 9),
      accountId: 'account-1',
      total: const Money(2500),
      paidAmount: const Money(1000),
      note: 'بيع تجريبي',
      items: const [
        TransactionEntryItem(
          productId: 'product-1',
          quantityMilli: 1000,
          unitPrice: Money(2500),
          unitCost: Money(1800),
        ),
      ],
    ),
  ];

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('mali-export-test-');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return tempDirectory.path;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);

    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('ينشئ CSV بترميز UTF-8 مع BOM ويحفظ النص العربي', () async {
    final file = await service.createCsv(transactions);
    final bytes = await file.readAsBytes();
    final text = utf8.decode(bytes);

    expect(await file.exists(), isTrue);
    expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
    expect(text, contains('رقم المعاملة'));
    expect(text, contains('بيع تجريبي'));
    expect(text, contains('sale-test-1'));
    expect(text, contains('product-1'));
  });

  test('ينشئ ملف Excel غير فارغ للمعاملات وبنودها', () async {
    final file = await service.createExcel(transactions);

    expect(await file.exists(), isTrue);
    expect(file.path, endsWith('.xlsx'));
    expect(await file.length(), greaterThan(0));
  });
}
