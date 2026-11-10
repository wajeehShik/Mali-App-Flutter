import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../domain/transaction_entry.dart';
import 'transaction_providers.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  FinancialTransactionType? _type;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المعاملات'),
        actions: [
          IconButton(
            tooltip: 'اختيار فترة',
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range_outlined),
          ),
          IconButton(
            tooltip: 'مسح الفلاتر',
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(transactionsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'ابحث برقم المعاملة أو الملاحظة',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<FinancialTransactionType?>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'نوع المعاملة',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('كل الأنواع'),
                      ),
                      for (final type in FinancialTransactionType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(_typeLabel(type)),
                        ),
                    ],
                    onChanged: (value) => setState(() => _type = value),
                  ),
                ),
                if (_dateRange != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const Icon(Icons.event, size: 16),
                    label: Text(_dateRangeLabel(_dateRange!)),
                    onDeleted: () => setState(() => _dateRange = null),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('تعذّر تحميل سجل المعاملات.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(transactionsProvider),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
              data: (transactions) {
                final filtered = transactions.where(_matches).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      transactions.isEmpty
                          ? 'لا توجد معاملات مسجلة.'
                          : 'لا توجد نتائج مطابقة للفلاتر.',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(_typeIcon(entry.type)),
                        ),
                        title: Text(_typeLabel(entry.type)),
                        subtitle: Text(
                          '${_formatDate(entry.date)}'
                          ' • ${entry.note ?? entry.id}'
                          '${entry.items.isEmpty ? '' : ' • ${entry.items.length} بنود'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          entry.total.format(),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        onTap: () => _showDetails(entry),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matches(TransactionEntry entry) {
    if (_type != null && entry.type != _type) return false;

    if (_query.isNotEmpty &&
        !entry.id.toLowerCase().contains(_query) &&
        !(entry.note?.toLowerCase().contains(_query) ?? false)) {
      return false;
    }

    final range = _dateRange;
    if (range != null) {
      final date = entry.date.toLocal();
      final from = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final toExclusive = DateTime(
        range.end.year,
        range.end.month,
        range.end.day + 1,
      );

      if (date.isBefore(from) || !date.isBefore(toExclusive)) return false;
    }

    return true;
  }

  Future<void> _selectDateRange() async {
    final today = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: DateTime(today.year, today.month, 1),
            end: today,
          ),
    );

    if (picked != null) setState(() => _dateRange = picked);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _type = null;
      _dateRange = null;
    });
  }

  Future<void> _showDetails(TransactionEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TransactionDetailsSheet(entry: entry),
    );
  }
}

class _TransactionDetailsSheet extends StatelessWidget {
  const _TransactionDetailsSheet({required this.entry});

  final TransactionEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _typeLabel(entry.type),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _DetailLine(label: 'رقم المعاملة', value: entry.id),
              _DetailLine(label: 'التاريخ', value: _formatDate(entry.date)),
              _DetailLine(label: 'الحساب', value: entry.accountId),
              if (entry.toAccountId != null)
                _DetailLine(
                  label: 'الحساب الوجهة',
                  value: entry.toAccountId!,
                ),
              if (entry.contactId != null)
                _DetailLine(label: 'جهة الاتصال', value: entry.contactId!),
              if (entry.categoryId != null)
                _DetailLine(label: 'التصنيف', value: entry.categoryId!),
              _DetailLine(label: 'الإجمالي', value: entry.total.format()),
              _DetailLine(label: 'المدفوع', value: entry.paidAmount.format()),
              if (entry.type == FinancialTransactionType.sale ||
                  entry.type == FinancialTransactionType.purchase)
                _DetailLine(
                  label: 'المتبقي',
                  value: entry.remainingAmount.format(),
                ),
              if (entry.note != null && entry.note!.isNotEmpty)
                _DetailLine(label: 'ملاحظة', value: entry.note!),
              if (entry.items.isNotEmpty) ...[
                const Divider(height: 24),
                Text('بنود العملية', style: theme.textTheme.titleMedium),
                for (final item in entry.items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('المنتج: ${item.productId}'),
                    subtitle: Text(
                      '${Money(item.quantityMilli).toDecimalString(decimals: 3)}'
                      ' × ${item.unitPrice.format()}'
                      ' • تكلفة ${item.unitCost.format()}',
                    ),
                    trailing: Text(item.lineTotal.format()),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
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

IconData _typeIcon(FinancialTransactionType type) {
  return switch (type) {
    FinancialTransactionType.income => Icons.trending_up_rounded,
    FinancialTransactionType.expense => Icons.trending_down_rounded,
    FinancialTransactionType.sale => Icons.point_of_sale_outlined,
    FinancialTransactionType.purchase => Icons.shopping_cart_outlined,
    FinancialTransactionType.transfer => Icons.swap_horiz_rounded,
    FinancialTransactionType.debtIn => Icons.call_received_rounded,
    FinancialTransactionType.debtOut => Icons.call_made_rounded,
  };
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year}';
}

String _dateRangeLabel(DateTimeRange range) {
  return '${range.start.day}/${range.start.month}'
      ' – ${range.end.day}/${range.end.month}';
}
