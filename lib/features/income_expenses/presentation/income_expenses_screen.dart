import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_providers.dart';
import '../domain/income_expense.dart';
import 'income_expense_providers.dart';

class IncomeExpensesScreen extends ConsumerStatefulWidget {
  const IncomeExpensesScreen({
    super.key,
    this.initialType = IncomeExpenseType.income,
  });

  final IncomeExpenseType initialType;

  @override
  ConsumerState<IncomeExpensesScreen> createState() =>
      _IncomeExpensesScreenState();
}

class _IncomeExpensesScreenState extends ConsumerState<IncomeExpensesScreen> {
  final _searchController = TextEditingController();

  late IncomeExpenseType _selectedType;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(
      incomeExpensesByTypeProvider(_selectedType),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإيرادات والمصروفات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              ref.invalidate(
                incomeExpensesByTypeProvider(_selectedType),
              );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              Expanded(
                child: _TypeTab(
                  label: 'الإيرادات',
                  selected: _selectedType == IncomeExpenseType.income,
                  onTap: () {
                    setState(() {
                      _selectedType = IncomeExpenseType.income;
                    });
                  },
                ),
              ),
              Expanded(
                child: _TypeTab(
                  label: 'المصروفات',
                  selected: _selectedType == IncomeExpenseType.expense,
                  onTap: () {
                    setState(() {
                      _selectedType = IncomeExpenseType.expense;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editEntry(),
        icon: const Icon(Icons.add),
        label: Text(
          _selectedType == IncomeExpenseType.income
              ? 'إيراد جديد'
              : 'مصروف جديد',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _query = value.trim().toLowerCase());
              },
              decoration: InputDecoration(
                hintText: 'ابحث بالملاحظة',
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
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('تعذّر تحميل الحركات.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(
                          incomeExpensesByTypeProvider(_selectedType),
                        );
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
              data: (entries) {
                final filteredEntries = entries.where((entry) {
                  if (_query.isEmpty) return true;

                  return (entry.note?.toLowerCase().contains(_query) ?? false) ||
                      entry.id.toLowerCase().contains(_query);
                }).toList(growable: false);

                if (filteredEntries.isEmpty) {
                  return Center(
                    child: Text(
                      entries.isEmpty
                          ? _selectedType == IncomeExpenseType.income
                              ? 'لا توجد إيرادات بعد.'
                              : 'لا توجد مصروفات بعد.'
                          : 'لا توجد نتائج مطابقة.',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: filteredEntries.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final entry = filteredEntries[index];

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            entry.type == IncomeExpenseType.income
                                ? Icons.trending_up
                                : Icons.trending_down,
                          ),
                        ),
                        title: Text(entry.amount.format()),
                        subtitle: Text(
                          '${_formatDate(entry.date)}'
                          '${entry.note == null ? '' : ' • ${entry.note}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editEntry(entry);
                            } else if (value == 'delete') {
                              _deleteEntry(entry);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('تعديل'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('حذف'),
                            ),
                          ],
                        ),
                        onTap: () => _editEntry(entry),
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

  Future<void> _editEntry([IncomeExpense? entry]) async {
    final edited = await showDialog<IncomeExpense>(
      context: context,
      builder: (_) => _IncomeExpenseDialog(
        type: entry?.type ?? _selectedType,
        entry: entry,
      ),
    );

    if (edited == null || !mounted) return;

    final controller = ref.read(incomeExpenseControllerProvider);
    final failure = entry == null
        ? await controller.create(edited)
        : await controller.update(edited);

    if (!mounted) return;

    _showResult(
      failure,
      entry == null ? 'تم حفظ الحركة.' : 'تم تحديث الحركة.',
    );

    if (failure == null) {
      ref.invalidate(incomeExpensesByTypeProvider(edited.type));
      ref.invalidate(allIncomeExpensesProvider);
    }
  }

  Future<void> _deleteEntry(IncomeExpense entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الحركة'),
        content: const Text('هل تريد حذف هذه الحركة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final failure = await ref
        .read(incomeExpenseControllerProvider)
        .softDelete(entry.id);

    if (!mounted) return;

    _showResult(failure, 'تم حذف الحركة.');

    if (failure == null) {
      ref.invalidate(incomeExpensesByTypeProvider(entry.type));
      ref.invalidate(allIncomeExpensesProvider);
    }
  }

  void _showResult(Failure? failure, String successMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure?.message ?? successMessage)),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? color : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _IncomeExpenseDialog extends ConsumerStatefulWidget {
  const _IncomeExpenseDialog({
    required this.type,
    this.entry,
  });

  final IncomeExpenseType type;
  final IncomeExpense? entry;

  @override
  ConsumerState<_IncomeExpenseDialog> createState() =>
      _IncomeExpenseDialogState();
}

class _IncomeExpenseDialogState
    extends ConsumerState<_IncomeExpenseDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late DateTime _date;
  String? _accountId;
  String? _categoryId;

  CategoryKind get _categoryKind =>
      widget.type == IncomeExpenseType.income
          ? CategoryKind.income
          : CategoryKind.expense;

  @override
  void initState() {
    super.initState();

    final entry = widget.entry;
    _amountController = TextEditingController(
      text: entry?.amount.toDecimalString() ?? '',
    );
    _noteController = TextEditingController(text: entry?.note ?? '');
    _date = entry?.date ?? DateTime.now();
    _accountId = entry?.accountId;
    _categoryId = entry?.categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = Money.tryParse(_amountController.text);
    final accountId = _accountId;

    if (amount == null || amount.minor <= 0 || accountId == null) return;

    final note = _noteController.text.trim();

    Navigator.of(context).pop(
      IncomeExpense(
        id: widget.entry?.id ?? const Uuid().v4(),
        type: widget.type,
        date: DateTime.utc(_date.year, _date.month, _date.day),
        accountId: accountId,
        amount: amount,
        categoryId: _categoryId == null || _categoryId!.isEmpty
            ? null
            : _categoryId,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsStream = ref.watch(accountRepositoryProvider).watchActive();
    final categoriesStream = ref
        .watch(categoryRepositoryProvider)
        .watchByKind(_categoryKind);

    return AlertDialog(
      title: Text(
        widget.entry == null
            ? widget.type == IncomeExpenseType.income
                ? 'إضافة إيراد'
                : 'إضافة مصروف'
            : widget.type == IncomeExpenseType.income
                ? 'تعديل إيراد'
                : 'تعديل مصروف',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final amount = Money.tryParse(value ?? '');
                    if (amount == null || amount.minor <= 0) {
                      return 'أدخل مبلغًا صحيحًا أكبر من صفر.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                StreamBuilder(
                  stream: accountsStream,
                  builder: (context, snapshot) {
                    final accounts = snapshot.data ?? const [];
                    final currentAccountId = _accountId;
                    final accountExists = accounts.any(
                      (account) => account.id == currentAccountId,
                    );

                    return DropdownButtonFormField<String>(
                      initialValue: currentAccountId != null && !accountExists
                          ? currentAccountId
                          : currentAccountId,
                      decoration: const InputDecoration(
                        labelText: 'الحساب',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                      items: [
                        if (currentAccountId != null && !accountExists)
                          DropdownMenuItem(
                            value: currentAccountId,
                            child: const Text('الحساب السابق غير متاح'),
                          ),
                        for (final account in accounts)
                          DropdownMenuItem(
                            value: account.id,
                            child: Text(account.name),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _accountId = value);
                      },
                      validator: (value) =>
                          value == null ? 'اختر الحساب.' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                StreamBuilder(
                  stream: categoriesStream,
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? const [];
                    final currentCategoryId = _categoryId;
                    final categoryExists = categories.any(
                      (category) => category.id == currentCategoryId,
                    );

                    return DropdownButtonFormField<String>(
                  initialValue: currentCategoryId ?? '',

                      decoration: const InputDecoration(
                        labelText: 'التصنيف (اختياري)',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('بدون تصنيف'),
                        ),
                        if (currentCategoryId != null &&
                            currentCategoryId.isNotEmpty &&
                            !categoryExists)
                          DropdownMenuItem(
                            value: currentCategoryId,
                            child: const Text('التصنيف السابق غير متاح'),
                          ),
                        for (final category in categories)
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _categoryId =
                              value == null || value.isEmpty ? null : value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('تاريخ الحركة'),
                  subtitle: Text(
                    '${_date.day.toString().padLeft(2, '0')}/'
                    '${_date.month.toString().padLeft(2, '0')}/'
                    '${_date.year}',
                  ),
                  onTap: _selectDate,
                ),
                TextFormField(
                  controller: _noteController,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
