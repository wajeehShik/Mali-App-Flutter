import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/utils/money.dart';
import 'package:mali/features/reports/domain/dashboard_summary.dart';
import 'package:mali/features/transactions/domain/transaction_entry.dart';

void main() {
  TransactionEntry entry({
    required String id,
    required FinancialTransactionType type,
    required int total,
    required int paid,
    DateTime? date,
  }) {
    return TransactionEntry(
      id: id,
      type: type,
      date: date ?? DateTime.utc(2026, 11, 9),
      accountId: 'account-1',
      total: Money(total),
      paidAmount: Money(paid),
    );
  }

  group('DashboardSummary.fromTransactions', () {
    test('يحسب الإجماليات والتدفقات والديون من كل أنواع الحركات', () {
      final summary = DashboardSummary.fromTransactions([
        entry(
          id: 'income-1',
          type: FinancialTransactionType.income,
          total: 1000,
          paid: 1000,
        ),
        entry(
          id: 'expense-1',
          type: FinancialTransactionType.expense,
          total: 2000,
          paid: 2000,
        ),
        entry(
          id: 'sale-1',
          type: FinancialTransactionType.sale,
          total: 5000,
          paid: 2000,
        ),
        entry(
          id: 'purchase-1',
          type: FinancialTransactionType.purchase,
          total: 4000,
          paid: 1000,
        ),
        entry(
          id: 'debt-in-1',
          type: FinancialTransactionType.debtIn,
          total: 500,
          paid: 500,
        ),
        entry(
          id: 'debt-out-1',
          type: FinancialTransactionType.debtOut,
          total: 300,
          paid: 300,
        ),
        entry(
          id: 'transfer-1',
          type: FinancialTransactionType.transfer,
          total: 900,
          paid: 900,
        ),
      ]);

      expect(summary.incomeReceived, const Money(1000));
      expect(summary.expensesPaid, const Money(2000));
      expect(summary.salesTotal, const Money(5000));
      expect(summary.purchasesTotal, const Money(4000));
      expect(summary.receivables, const Money(3000));
      expect(summary.payables, const Money(3000));
      expect(summary.cashInflow, const Money(3500));
      expect(summary.cashOutflow, const Money(3300));
      expect(summary.netCashFlow, const Money(200));
      expect(summary.transactionCount, 7);
    });

    test('يجمع صافي التدفق حسب اليوم ويرتب الأيام تصاعديًا', () {
      final summary = DashboardSummary.fromTransactions([
        entry(
          id: 'income-day-2',
          type: FinancialTransactionType.income,
          total: 700,
          paid: 700,
          date: DateTime.utc(2026, 11, 10),
        ),
        entry(
          id: 'expense-day-1',
          type: FinancialTransactionType.expense,
          total: 200,
          paid: 200,
          date: DateTime.utc(2026, 11, 9),
        ),
        entry(
          id: 'sale-day-1',
          type: FinancialTransactionType.sale,
          total: 1000,
          paid: 400,
          date: DateTime.utc(2026, 11, 9, 15),
        ),
      ]);

      expect(summary.dailyCashFlows, hasLength(2));
      expect(summary.dailyCashFlows.first.date.day, 9);
      expect(summary.dailyCashFlows.first.inflow, const Money(400));
      expect(summary.dailyCashFlows.first.outflow, const Money(200));
      expect(summary.dailyCashFlows.first.net, const Money(200));
      expect(summary.dailyCashFlows.last.date.day, 10);
      expect(summary.dailyCashFlows.last.inflow, const Money(700));
      expect(summary.dailyCashFlows.last.outflow, Money.zero);
    });

    test('يرجع ملخصًا صفريًا عند عدم وجود معاملات', () {
      final summary = DashboardSummary.fromTransactions(const []);

      expect(summary.incomeReceived, Money.zero);
      expect(summary.expensesPaid, Money.zero);
      expect(summary.salesTotal, Money.zero);
      expect(summary.purchasesTotal, Money.zero);
      expect(summary.receivables, Money.zero);
      expect(summary.payables, Money.zero);
      expect(summary.cashInflow, Money.zero);
      expect(summary.cashOutflow, Money.zero);
      expect(summary.dailyCashFlows, isEmpty);
      expect(summary.transactionCount, 0);
    });
  });
}
