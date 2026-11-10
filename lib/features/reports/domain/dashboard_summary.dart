import 'package:flutter/foundation.dart';

import '../../../core/utils/money.dart';
import '../../transactions/domain/transaction_entry.dart';

/// ملخص مالي مشتق من سجل المعاملات، ولا يُخزَّن في قاعدة البيانات.
@immutable
final class DashboardSummary {
  const DashboardSummary({
    required this.incomeReceived,
    required this.expensesPaid,
    required this.salesTotal,
    required this.purchasesTotal,
    required this.receivables,
    required this.payables,
    required this.cashInflow,
    required this.cashOutflow,
    required this.dailyCashFlows,
    required this.transactionCount,
  });

  /// المبالغ المقبوضة من حركات الإيراد.
  final Money incomeReceived;

  /// المبالغ المدفوعة في حركات المصروف.
  final Money expensesPaid;

  /// إجمالي قيمة المبيعات، شاملًا الجزء غير المقبوض.
  final Money salesTotal;

  /// إجمالي قيمة المشتريات، شاملًا الجزء غير المدفوع.
  final Money purchasesTotal;

  /// المبالغ المتبقية على العملاء من فواتير البيع.
  final Money receivables;

  /// المبالغ المتبقية للموردين من فواتير الشراء.
  final Money payables;

  /// التدفق النقدي الداخل من الإيرادات والمبيعات وتحصيل الديون.
  final Money cashInflow;

  /// التدفق النقدي الخارج للمصروفات والمشتريات وسداد الديون.
  final Money cashOutflow;

  final List<DailyCashFlow> dailyCashFlows;
  final int transactionCount;

  Money get netCashFlow => cashInflow - cashOutflow;

  /// يحسب الملخص والتدفق اليومي من المعاملات المعطاة.
  ///
  /// تُستخدم المبالغ المدفوعة/المقبوضة لحساب التدفق النقدي،
  /// بينما تبقى إجماليات المبيعات والمشتريات على أساس إجمالي الفاتورة.
  factory DashboardSummary.fromTransactions(
    Iterable<TransactionEntry> transactions,
  ) {
    var incomeReceived = Money.zero;
    var expensesPaid = Money.zero;
    var salesTotal = Money.zero;
    var purchasesTotal = Money.zero;
    var receivables = Money.zero;
    var payables = Money.zero;
    var cashInflow = Money.zero;
    var cashOutflow = Money.zero;

    final daily = <DateTime, _DailyAccumulator>{};
    var transactionCount = 0;

    for (final transaction in transactions) {
      transactionCount++;

      final localDate = transaction.date.toLocal();
      final day = DateTime(localDate.year, localDate.month, localDate.day);
      final accumulator = daily.putIfAbsent(day, _DailyAccumulator.new);

      switch (transaction.type) {
        case FinancialTransactionType.income:
          incomeReceived += transaction.paidAmount;
          cashInflow += transaction.paidAmount;
          accumulator.inflow += transaction.paidAmount;

        case FinancialTransactionType.expense:
          expensesPaid += transaction.paidAmount;
          cashOutflow += transaction.paidAmount;
          accumulator.outflow += transaction.paidAmount;

        case FinancialTransactionType.sale:
          salesTotal += transaction.total;
          receivables += transaction.remainingAmount;
          cashInflow += transaction.paidAmount;
          accumulator.inflow += transaction.paidAmount;

        case FinancialTransactionType.purchase:
          purchasesTotal += transaction.total;
          payables += transaction.remainingAmount;
          cashOutflow += transaction.paidAmount;
          accumulator.outflow += transaction.paidAmount;

        case FinancialTransactionType.debtIn:
          cashInflow += transaction.paidAmount;
          accumulator.inflow += transaction.paidAmount;

        case FinancialTransactionType.debtOut:
          cashOutflow += transaction.paidAmount;
          accumulator.outflow += transaction.paidAmount;

        case FinancialTransactionType.transfer:
          // التحويل بين حسابات المنشأة لا يغير التدفق النقدي الإجمالي.
          break;
      }
    }

    final dailyCashFlows = daily.entries
        .map(
          (entry) => DailyCashFlow(
            date: entry.key,
            inflow: entry.value.inflow,
            outflow: entry.value.outflow,
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return DashboardSummary(
      incomeReceived: incomeReceived,
      expensesPaid: expensesPaid,
      salesTotal: salesTotal,
      purchasesTotal: purchasesTotal,
      receivables: receivables,
      payables: payables,
      cashInflow: cashInflow,
      cashOutflow: cashOutflow,
      dailyCashFlows: List<DailyCashFlow>.unmodifiable(dailyCashFlows),
      transactionCount: transactionCount,
    );
  }
}

/// التدفق النقدي ليوم واحد.
@immutable
final class DailyCashFlow {
  const DailyCashFlow({
    required this.date,
    required this.inflow,
    required this.outflow,
  });

  final DateTime date;
  final Money inflow;
  final Money outflow;

  Money get net => inflow - outflow;

  @override
  bool operator ==(Object other) =>
      other is DailyCashFlow &&
      other.date == date &&
      other.inflow == inflow &&
      other.outflow == outflow;

  @override
  int get hashCode => Object.hash(date, inflow, outflow);
}

class _DailyAccumulator {
  Money inflow = Money.zero;
  Money outflow = Money.zero;
}
