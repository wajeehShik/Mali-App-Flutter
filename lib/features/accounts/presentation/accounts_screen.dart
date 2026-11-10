import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../activation/presentation/activation_providers.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import '../domain/account.dart';
import 'account_providers.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountRepositoryProvider).watchActive();
final canWrite =
    ref.watch(activationControllerProvider).value?.canWrite ?? false;


    return Scaffold(
      appBar: AppBar(title: const Text('الحسابات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createAccount(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('حساب جديد'),
      ),
      body: StreamBuilder<List<Account>>(
        stream: accounts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('تعذّر تحميل الحسابات.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('لا توجد حسابات بعد.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final account = items[index];
              return _AccountCard(
                account: account,
                onArchive: account.isArchived || !canWrite
                    ? null
                    : () => _archiveAccount(context, ref, account),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createAccount(BuildContext context, WidgetRef ref) async {
    final account = await showDialog<Account>(
      context: context,
      builder: (_) => const _CreateAccountDialog(),
    );
    if (account == null || !context.mounted) return;

    final failure =
        await ref.read(accountControllerProvider).create(account);
    if (!context.mounted) return;

    _showResult(context, failure, successMessage: 'تم إنشاء الحساب.');
  }

  Future<void> _archiveAccount(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('أرشفة الحساب'),
        content: Text('هل تريد أرشفة «${account.name}»؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('أرشفة'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final failure =
        await ref.read(accountControllerProvider).archive(account.id);
    if (!context.mounted) return;

    _showResult(context, failure, successMessage: 'تمت أرشفة الحساب.');
  }

  void _showResult(
    BuildContext context,
    Failure? failure, {
    required String successMessage,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure?.message ?? successMessage)),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({
    required this.account,
    required this.onArchive,
  });

  final Account account;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref
        .watch(accountRepositoryProvider)
        .getBalance(account.id);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_iconFor(account.type)),
        ),
        title: Text(account.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_labelFor(account.type)),
            const SizedBox(height: 4),
            FutureBuilder<Result<Money>>(
              future: balance,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('الرصيد: جارٍ الحساب…');
                }
                final result = snapshot.data!;
                final failure = result.failureOrNull;
                if (failure != null) {
                  return Text('تعذّر حساب الرصيد: ${failure.message}');
                }
                return Text(
                  'الرصيد: ${result.valueOrNull!.format(symbol: account.currency)}',
                );
              },
            ),
            if (account.isArchived)
              const Text('مؤرشف', style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: onArchive == null
            ? null
            : IconButton(
                tooltip: 'أرشفة الحساب',
                onPressed: onArchive,
                icon: const Icon(Icons.archive_outlined),
              ),
      ),
    );
  }

  IconData _iconFor(AccountType type) => switch (type) {
        AccountType.cash => Icons.payments_outlined,
        AccountType.bank => Icons.account_balance_outlined,
        AccountType.wallet => Icons.account_balance_wallet_outlined,
      };

  String _labelFor(AccountType type) => switch (type) {
        AccountType.cash => 'نقدي',
        AccountType.bank => 'بنك',
        AccountType.wallet => 'محفظة',
      };
}

class _CreateAccountDialog extends StatefulWidget {
  const _CreateAccountDialog();

  @override
  State<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<_CreateAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');

  AccountType _type = AccountType.cash;
  String? _balanceError;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final rawBalance = _balanceController.text.trim();
    final openingBalance =
        rawBalance.isEmpty ? Money.zero : Money.tryParse(rawBalance);

    if (openingBalance == null) {
      setState(() => _balanceError = 'أدخل مبلغًا صحيحًا.');
      return;
    }

    Navigator.of(context).pop(
      Account(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        type: _type,
        openingBalance: openingBalance,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('حساب جديد'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'اسم الحساب',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'اسم الحساب مطلوب.';
                  }
                  if (value.trim().length > 100) {
                    return 'الاسم طويل جدًا.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
             initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'نوع الحساب',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: AccountType.cash,
                    child: Text('نقدي'),
                  ),
                  DropdownMenuItem(
                    value: AccountType.bank,
                    child: Text('بنك'),
                  ),
                  DropdownMenuItem(
                    value: AccountType.wallet,
                    child: Text('محفظة'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _balanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'الرصيد الافتتاحي',
                  border: const OutlineInputBorder(),
                  errorText: _balanceError,
                ),
                onChanged: (_) {
                  if (_balanceError != null) {
                    setState(() => _balanceError = null);
                  }
                },
              ),
            ],
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
