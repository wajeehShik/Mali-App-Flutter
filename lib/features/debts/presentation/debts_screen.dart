import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/money.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../contacts/domain/contact.dart';
import '../../contacts/presentation/contact_providers.dart';
import '../domain/debt_balance.dart';
import '../domain/debt_payment.dart';
import 'debt_providers.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  DebtDirection _direction = DebtDirection.receivable;

  @override
  Widget build(BuildContext context) {
    final balancesAsync = ref.watch(debtBalancesProvider);
    final contactsStream = _direction == DebtDirection.receivable
        ? ref.watch(contactRepositoryProvider).watchCustomers()
        : ref.watch(contactRepositoryProvider).watchSuppliers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الديون'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              ref.invalidate(debtBalancesProvider);
              ref.invalidate(allDebtBalancesProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              Expanded(
                child: _DebtTab(
                  label: 'ديون العملاء',
                  selected: _direction == DebtDirection.receivable,
                  onTap: () => setState(
                    () => _direction = DebtDirection.receivable,
                  ),
                ),
              ),
              Expanded(
                child: _DebtTab(
                  label: 'ديون الموردين',
                  selected: _direction == DebtDirection.payable,
                  onTap: () => setState(
                    () => _direction = DebtDirection.payable,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: balancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعذّر تحميل أرصدة الديون.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(debtBalancesProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (balances) => StreamBuilder<List<Contact>>(
          stream: contactsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('تعذّر تحميل جهات الاتصال.'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final contacts = {
              for (final contact in snapshot.data!) contact.id: contact,
            };

            final visibleBalances = balances
                .where((balance) => balance.direction == _direction)
                .toList(growable: false);

            if (visibleBalances.isEmpty) {
              return Center(
                child: Text(
                  _direction == DebtDirection.receivable
                      ? 'لا توجد ديون مستحقة على العملاء.'
                      : 'لا توجد ديون مستحقة للموردين.',
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visibleBalances.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final balance = visibleBalances[index];
                final contact = contacts[balance.contactId];

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        _direction == DebtDirection.receivable
                            ? Icons.person_outline
                            : Icons.local_shipping_outlined,
                      ),
                    ),
                    title: Text(contact?.name ?? 'جهة اتصال غير متاحة'),
                    subtitle: Text(
                      _direction == DebtDirection.receivable
                          ? 'مستحق لنا'
                          : 'مستحق علينا',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          balance.amount.format(),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        TextButton(
                          onPressed: contact == null
                              ? null
                              : () => _recordPayment(balance, contact),
                          child: Text(
                            _direction == DebtDirection.receivable
                                ? 'تحصيل'
                                : 'سداد',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _recordPayment(
    DebtBalance balance,
    Contact contact,
  ) async {
    final payment = await showDialog<DebtPayment>(
      context: context,
      builder: (_) => _DebtPaymentDialog(
        contactId: contact.id,
        contactName: contact.name,
        direction: balance.direction,
        outstandingAmount: balance.amount,
      ),
    );

    if (payment == null || !mounted) return;

    final failure =
        await ref.read(debtControllerProvider).recordPayment(payment);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure?.message ?? 'تم تسجيل السداد بنجاح.'),
      ),
    );

    if (failure == null) {
      ref.invalidate(debtBalancesProvider);
      ref.invalidate(allDebtBalancesProvider);
    }
  }
}

class _DebtTab extends StatelessWidget {
  const _DebtTab({
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

class _DebtPaymentDialog extends ConsumerStatefulWidget {
  const _DebtPaymentDialog({
    required this.contactId,
    required this.contactName,
    required this.direction,
    required this.outstandingAmount,
  });

  final String contactId;
  final String contactName;
  final DebtDirection direction;
  final Money outstandingAmount;

  @override
  ConsumerState<_DebtPaymentDialog> createState() =>
      _DebtPaymentDialogState();
}

class _DebtPaymentDialogState extends ConsumerState<_DebtPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _date = DateTime.now();
  String? _accountId;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = Money.tryParse(_amountController.text);
    final accountId = _accountId;
    if (amount == null || accountId == null) return;

    final note = _noteController.text.trim();

    Navigator.of(context).pop(
      DebtPayment(
        id: const Uuid().v4(),
        date: DateTime.utc(_date.year, _date.month, _date.day),
        accountId: accountId,
        contactId: widget.contactId,
        direction: widget.direction,
        amount: amount,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsStream = ref.watch(accountRepositoryProvider).watchActive();
    final isCustomerDebt = widget.direction == DebtDirection.receivable;

    return AlertDialog(
      title: Text(
        isCustomerDebt
            ? 'تحصيل من ${widget.contactName}'
            : 'سداد إلى ${widget.contactName}',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الرصيد المستحق'),
                  trailing: Text(widget.outstandingAmount.format()),
                ),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'مبلغ السداد',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final amount = Money.tryParse(value ?? '');
                    if (amount == null || amount.minor <= 0) {
                      return 'أدخل مبلغًا أكبر من صفر.';
                    }
                    if (amount.minor > widget.outstandingAmount.minor) {
                      return 'المبلغ أكبر من الرصيد المستحق.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                StreamBuilder(
                  stream: accountsStream,
                  builder: (context, snapshot) {
                    final accounts = snapshot.data ?? const [];

                    return DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      decoration: InputDecoration(
                        labelText: isCustomerDebt
                            ? 'حساب استلام المبلغ'
                            : 'حساب دفع المبلغ',
                        prefixIcon: const Icon(
                          Icons.account_balance_outlined,
                        ),
                      ),
                      items: [
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('تاريخ السداد'),
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
          child: Text(isCustomerDebt ? 'تسجيل التحصيل' : 'تسجيل السداد'),
        ),
      ],
    );
  }
}
