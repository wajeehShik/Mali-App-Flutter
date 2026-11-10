import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/money.dart';
import '../../transactions/domain/transaction_entry.dart';

/// ينشئ ملفات CSV وExcel لسجل المعاملات، ثم يتيح مشاركتها.
class TransactionExportService {
  const TransactionExportService();

  Future<File> createCsv(List<TransactionEntry> transactions) async {
    final rows = <List<String>>[
      [
        'رقم المعاملة',
        'النوع',
        'التاريخ',
        'معرّف الحساب',
        'معرّف الحساب الوجهة',
        'معرّف جهة الاتصال',
        'معرّف التصنيف',
        'الإجمالي',
        'المدفوع',
        'المتبقي',
        'الملاحظة',
        'بنود المنتجات',
      ],
      for (final transaction in transactions)
        [
          transaction.id,
          _typeLabel(transaction.type),
          transaction.date.toIso8601String(),
          transaction.accountId,
          transaction.toAccountId ?? '',
          transaction.contactId ?? '',
          transaction.categoryId ?? '',
          transaction.total.toDecimalString(),
          transaction.paidAmount.toDecimalString(),
          transaction.remainingAmount.toDecimalString(),
          transaction.note ?? '',
          transaction.items
              .map(
                (item) =>
                    '${item.productId} × '
                    '${Money(item.quantityMilli).toDecimalString(decimals: 3)}',
              )
              .join(' | '),
        ],
    ];

    final csvText = rows
        .map((row) => row.map(_escapeCsvField).join(','))
        .join('\r\n');

    // BOM يساعد Excel على اكتشاف ترميز UTF-8 للنص العربي.
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(csvText)];

    return _writeFile('mali_transactions', 'csv', bytes);
  }

  Future<File> createExcel(List<TransactionEntry> transactions) async {
    final workbook = Excel.createExcel();
    final transactionSheet = workbook['Transactions'];
    final itemSheet = workbook['Items'];

    transactionSheet.appendRow([
      TextCellValue('رقم المعاملة'),
      TextCellValue('النوع'),
      TextCellValue('التاريخ'),
      TextCellValue('معرّف الحساب'),
      TextCellValue('معرّف الحساب الوجهة'),
      TextCellValue('معرّف جهة الاتصال'),
      TextCellValue('معرّف التصنيف'),
      TextCellValue('الإجمالي'),
      TextCellValue('المدفوع'),
      TextCellValue('المتبقي'),
      TextCellValue('الملاحظة'),
    ]);

    itemSheet.appendRow([
      TextCellValue('رقم المعاملة'),
      TextCellValue('معرّف المنتج'),
      TextCellValue('الكمية'),
      TextCellValue('سعر الوحدة'),
      TextCellValue('تكلفة الوحدة'),
      TextCellValue('إجمالي البند'),
    ]);

    for (final transaction in transactions) {
      transactionSheet.appendRow([
        TextCellValue(transaction.id),
        TextCellValue(_typeLabel(transaction.type)),
        TextCellValue(transaction.date.toIso8601String()),
        TextCellValue(transaction.accountId),
        TextCellValue(transaction.toAccountId ?? ''),
        TextCellValue(transaction.contactId ?? ''),
        TextCellValue(transaction.categoryId ?? ''),
        TextCellValue(transaction.total.toDecimalString()),
        TextCellValue(transaction.paidAmount.toDecimalString()),
        TextCellValue(transaction.remainingAmount.toDecimalString()),
        TextCellValue(transaction.note ?? ''),
      ]);

      for (final item in transaction.items) {
        itemSheet.appendRow([
          TextCellValue(transaction.id),
          TextCellValue(item.productId),
          TextCellValue(
            Money(item.quantityMilli).toDecimalString(decimals: 3),
          ),
          TextCellValue(item.unitPrice.toDecimalString()),
          TextCellValue(item.unitCost.toDecimalString()),
          TextCellValue(item.lineTotal.toDecimalString()),
        ]);
      }
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('تعذّر إنشاء ملف Excel.');
    }

    return _writeFile('mali_transactions', 'xlsx', bytes);
  }

  Future<ShareResult> shareFile(
    File file, {
    String subject = 'تصدير معاملات مالي',
  }) {
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject,
      ),
    );
  }

  Future<File> _writeFile(
    String baseName,
    String extension,
    List<int> bytes,
  ) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File(
      '${directory.path}/${baseName}_$timestamp.$extension',
    );

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// يحيط كل حقل بعلامتي اقتباس ويضاعف الاقتباس الداخلي حسب CSV.
  String _escapeCsvField(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _typeLabel(FinancialTransactionType type) {
    return switch (type) {
      FinancialTransactionType.income => 'إيراد',
      FinancialTransactionType.expense => 'مصروف',
      FinancialTransactionType.sale => 'بيع',
      FinancialTransactionType.purchase => 'شراء',
      FinancialTransactionType.transfer => 'تحويل',
      FinancialTransactionType.debtIn => 'تحصيل دين',
      FinancialTransactionType.debtOut => 'سداد دين',
    };
  }
}
