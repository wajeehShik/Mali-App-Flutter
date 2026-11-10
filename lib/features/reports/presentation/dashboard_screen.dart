import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../domain/dashboard_summary.dart';
import 'dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(dashboardSummaryProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعذّر تحميل ملخص لوحة التحكم.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(dashboardSummaryProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (summary) => _DashboardContent(summary: summary),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'صافي التدفق النقدي',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  summary.netCashFlow.format(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text('عدد المعاملات: ${summary.transactionCount}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(
              title: 'الإيرادات المقبوضة',
              amount: summary.incomeReceived,
              icon: Icons.trending_up_rounded,
              color: Colors.green,
            ),
            _SummaryCard(
              title: 'المصروفات المدفوعة',
              amount: summary.expensesPaid,
              icon: Icons.trending_down_rounded,
              color: Colors.red,
            ),
            _SummaryCard(
              title: 'إجمالي المبيعات',
              amount: summary.salesTotal,
              icon: Icons.point_of_sale_outlined,
              color: Colors.blue,
            ),
            _SummaryCard(
              title: 'إجمالي المشتريات',
              amount: summary.purchasesTotal,
              icon: Icons.shopping_cart_outlined,
              color: Colors.deepOrange,
            ),
            _SummaryCard(
              title: 'ديون العملاء',
              amount: summary.receivables,
              icon: Icons.person_outline,
              color: Colors.indigo,
            ),
            _SummaryCard(
              title: 'ديون الموردين',
              amount: summary.payables,
              icon: Icons.local_shipping_outlined,
              color: Colors.purple,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('التدفق النقدي اليومي', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (summary.dailyCashFlows.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا توجد معاملات لعرض التدفق النقدي.'),
            ),
          )
        else
          for (final flow in summary.dailyCashFlows.reversed.take(14))
            _DailyFlowCard(flow: flow),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
    return SizedBox(
      width: 166,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                amount.format(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyFlowCard extends StatelessWidget {
  const _DailyFlowCard({required this.flow});

  final DailyCashFlow flow;

  @override
  Widget build(BuildContext context) {
    final maxAmount = flow.inflow.minor > flow.outflow.minor
        ? flow.inflow.minor
        : flow.outflow.minor;

    double fraction(int amount) {
      if (maxAmount <= 0) return 0;
      return amount / maxAmount;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(_formatDate(flow.date))),
                Text('الصافي: ${flow.net.format()}'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 72, child: Text('داخل')),
                Expanded(
                  child: LinearProgressIndicator(
                    value: fraction(flow.inflow.minor),
                    color: Colors.green,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: 8),
                Text(flow.inflow.format()),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 72, child: Text('خارج')),
                Expanded(
                  child: LinearProgressIndicator(
                    value: fraction(flow.outflow.minor),
                    color: Colors.red,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: 8),
                Text(flow.outflow.format()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}
