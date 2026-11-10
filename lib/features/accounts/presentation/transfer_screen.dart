import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/money.dart';
import '../domain/account.dart';
import '../domain/account_transfer.dart';
import 'account_providers.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _fromAccountId;
  String? _toAccountId;
  bool _busy = false;
  String? _amountError;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _amountError = null);

    if (!_formKey.currentState!.validate()) return;

    final amount = Money.tryParse(_amountController.text);
    if (amount == null || !amount.isPositive) {
      setState(() => _amountError = 'أدخل مبلغًا صحيحًا أكبر من صفر.');
      return;
    }

    final fromId = _fromAccountId;
    final toId = _toAccountId;
    if (fromId == null || toId == null || fromId == toId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر حسابين مختلفين للتحويل.')),
      );
      return;
    }

    setState(() => _busy = true);

    final failure = await ref.read(transferControllerProvider).create(
          AccountTransfer(
            id: const Uuid().v4(),
            fromAccountId: fromId,
            toAccountId: toId,
            amount: amount,
            date: DateTime.now().toUtc(),
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
        );

    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure?.message ?? 'تم تسجيل التحويل.'),
      ),
    );

    if (failure == null) {
      _amountController.clear();
      _noteController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountStream =
        ref.watch(accountRepositoryProvider).watchActive();

    return Scaffold(
      appBar: AppBar(title: const Text('تحويل بين الحسابات')),
      body: StreamBuilder<List<Account>>(
        stream: accountStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('تعذّر تحميل الحسابات.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final accounts = snapshot.data!;
          if (accounts.length < 2) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'يلزم وجود حسابين نشطين على الأقل لإجراء تحويل.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final fromId = accounts.any((account) => account.id == _fromAccountId)
              ? _fromAccountId
              : accounts.first.id;
          final availableTargets =
              accounts.where((account) => account.id != fromId).toList();
          final toId =
              availableTargets.any((account) => account.id == _toAccountId)
                  ? _toAccountId
                  : availableTargets.first.id;

          if (_fromAccountId != fromId || _toAccountId != toId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _fromAccountId = fromId;
                _toAccountId = toId;
              });
            });
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'انقل مبلغًا بين حساباتك',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: fromId,
                      decoration: const InputDecoration(
                        labelText: 'من الحساب',
                        border: OutlineInputBorder(),
                      ),
                      items: accounts
                          .map(
                            (account) => DropdownMenuItem(
                              value: account.id,
                              child: Text(_accountLabel(account)),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _fromAccountId = value;
                                if (_toAccountId == value) {
                                  _toAccountId = null;
                                }
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: toId,
                      decoration: const InputDecoration(
                        labelText: 'إلى الحساب',
                        border: OutlineInputBorder(),
                      ),
                      items: availableTargets
                          .map(
                            (account) => DropdownMenuItem(
                              value: account.id,
                              child: Text(_accountLabel(account)),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _toAccountId = value);
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      enabled: !_busy,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'المبلغ',
                        suffixText: accounts
                            .firstWhere((account) => account.id == fromId)
                            .currency,
                        errorText: _amountError,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'أدخل المبلغ.'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteController,
                      enabled: !_busy,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظة (اختيارية)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('تأكيد التحويل'),
                      ),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _accountLabel(Account account) {
    final type = switch (account.type) {
      AccountType.cash => 'نقدي',
      AccountType.bank => 'بنك',
      AccountType.wallet => 'محفظة',
    };
    return '${account.name} — $type';
  }
}
