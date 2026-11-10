import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../exports/data/transaction_export_service.dart';
import '../../transactions/domain/transaction_entry.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/dashboard_summary.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTimeRange _range;
  Future<List<TransactionEntry>>? _transactionsFuture;
  bool _isExporting = false;

  static const _exportService = TransactionExportService();

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  @override
  Widget build(BuildContext context) {
    _transactionsFuture ??= _loadTransactions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        actions: [
          IconButton(
            tooltip: 'اختيار الفترة',
            onPressed: _selectRange,
            icon: const Icon(Icons.date_range_outlined),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<TransactionEntry>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorView(
              message: 'تعذّر تحميل التقرير: ${snapshot.error}',
              onRetry: _refresh,
            );
          }

          final transactions = snapshot.data;
          if (transactions == null) {
            return _ErrorView(
              message: 'تعذّر تحميل بيانات التقرير.',
              onRetry: _refresh,
            );
          }

          final summary = DashboardSummary.fromTransactions(transactions);

          return _ReportContent(
            range: _range,
            transactions: transactions,
            summary: summary,
            isExporting: _isExporting,
            onExportCsv: () => _export(transactions, excel: false),
            onExportExcel: () => _export(transactions, excel: true),
          );
        },
      ),
    );
  }

  Future<List<TransactionEntry>> _loadTransactions() async {
    final from = DateTime(
      _range.start.year,
      _range.start.month,
      _range.start.day,
    );
    final toExclusive = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day + 1,
    );

    final result = await ref
        .read(transactionRepositoryProvider)
        .getTransactions(from: from, to: toExclusive);

    final failure = result.failureOrNull;
    if (failure != null) {
      throw Exception(failure.message);
    }

    return result.unwrap();
  }

  Future<void> _selectRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );

    if (!mounted || picked == null) return;

    setState(() {
      _range = picked;
      _transactionsFuture = _loadTransactions();
    });
  }

  void _refresh() {
    setState(() {
      _transactionsFuture = _loadTransactions();
    });
  }

  Future<void> _export(
    List<TransactionEntry> transactions, {
    required bool excel,
  }) async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final file = excel
          ? await _exportService.createExcel(transactions)
          : await _exportService.createCsv(transactions);

      if (!mounted) return;

      await _exportService.shareFile(
        file,
        subject: excel ? 'تقرير معاملات Excel' : 'تقرير معاملات CSV',
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تصدير التقرير: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({
    required this.range,
    required this.transactions,
    required this.summary,
    required this.isExporting,
    required this.onExportCsv,
    required this.onExportExcel,
  });

  final DateTimeRange range;
  final List<TransactionEntry> transactions;
  final DashboardSummary summary;
  final bool isExporting;
  final VoidCallback onExportCsv;
  final VoidCallback onExportExcel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('الفترة المحددة'),
            subtitle: Text(
              '${_formatDate(range.start)} - ${_formatDate(range.end)}',
            ),
            trailing: Text('${transactions.length} عملية'),
          ),
        ),
        const SizedBox(height: 8),
        if (isExporting)
          const LinearProgressIndicator()
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onExportCsv,
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('تصدير CSV'),
              ),
              OutlinedButton.icon(
                onPressed: onExportExcel,
                icon: const Icon(Icons.grid_on_outlined),
                label: const Text('تصدير Excel'),
              ),
            ],
          ),
        const SizedBox(height: 12),
        _ReportMetric(
          title: 'الإيرادات المقبوضة',
          amount: summary.incomeReceived,
          icon: Icons.trending_up_rounded,
          color: Colors.green,
        ),
        _ReportMetric(
          title: 'المصروفات المدفوعة',
          amount: summary.expensesPaid,
          icon: Icons.trending_down_rounded,
          color: Colors.red,
        ),
        _ReportMetric(
          title: 'إجمالي المبيعات',
          amount: summary.salesTotal,
          icon: Icons.point_of_sale_outlined,
          color: Colors.blue,
        ),
        _ReportMetric(
          title: 'إجمالي المشتريات',
          amount: summary.purchasesTotal,
          icon: Icons.shopping_cart_outlined,
          color: Colors.deepOrange,
        ),
        Card(
          color: theme.colorScheme.secondaryContainer,
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('صافي التدفق النقدي'),
            subtitle: Text(
              'داخل ${summary.cashInflow.format()}'
              ' • خارج ${summary.cashOutflow.format()}',
            ),
            trailing: Text(
              summary.netCashFlow.format(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('التدفق اليومي', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (summary.dailyCashFlows.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا توجد معاملات خلال الفترة المحددة.'),
            ),
          )
        else
          for (final flow in summary.dailyCashFlows.reversed)
            _DailyReportRow(flow: flow),
      ],
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String title;
  final Money amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: Text(
          amount.format(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _DailyReportRow extends StatelessWidget {
  const _DailyReportRow({required this.flow});

  final DailyCashFlow flow;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(_formatDate(flow.date))),
                Text('الصافي: ${flow.net.format()}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('داخل: ${flow.inflow.format()}')),
                Expanded(child: Text('خارج: ${flow.outflow.format()}')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year}';
}
