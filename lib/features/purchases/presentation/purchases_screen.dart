import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../contacts/presentation/contact_providers.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_providers.dart';
import '../domain/purchase.dart';
import 'purchase_providers.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(purchasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المشتريات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(purchasesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editPurchase(),
        icon: const Icon(Icons.add),
        label: const Text('فاتورة شراء'),
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
                hintText: 'ابحث بالملاحظة أو رقم العملية',
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
            child: purchasesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('تعذّر تحميل المشتريات.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(purchasesProvider),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
              data: (purchases) {
                final filtered = purchases.where((purchase) {
                  if (_query.isEmpty) return true;
                  return purchase.id.toLowerCase().contains(_query) ||
                      (purchase.note?.toLowerCase().contains(_query) ?? false);
                }).toList(growable: false);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      purchases.isEmpty
                          ? 'لا توجد مشتريات بعد.'
                          : 'لا توجد نتائج مطابقة.',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final purchase = filtered[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.shopping_cart_outlined),
                        ),
                        title: Text(purchase.total.format()),
                        subtitle: Text(
                          '${_formatDate(purchase.date)}'
                          ' • ${purchase.items.length} بنود'
                          '${purchase.note == null ? '' : '\n${purchase.note}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _editPurchase(purchase);
                            if (value == 'delete') _deletePurchase(purchase);
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
                        onTap: () => _editPurchase(purchase),
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

  Future<void> _editPurchase([Purchase? purchase]) async {
    final edited = await showDialog<Purchase>(
      context: context,
      builder: (_) => _PurchaseDialog(purchase: purchase),
    );

    if (edited == null || !mounted) return;

    final controller = ref.read(purchaseControllerProvider);
    final failure = purchase == null
        ? await controller.create(edited)
        : await controller.update(edited);

    if (!mounted) return;

    _showResult(
      failure,
      purchase == null ? 'تم حفظ فاتورة الشراء.' : 'تم تحديث فاتورة الشراء.',
    );

    if (failure == null) {
      ref.invalidate(purchasesProvider);
      ref.invalidate(allPurchasesProvider);
    }
  }

  Future<void> _deletePurchase(Purchase purchase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف فاتورة الشراء'),
        content: const Text('هل تريد حذف الفاتورة وبنودها؟'),
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
        .read(purchaseControllerProvider)
        .softDelete(purchase.id);

    if (!mounted) return;

    _showResult(failure, 'تم حذف فاتورة الشراء.');

    if (failure == null) {
      ref.invalidate(purchasesProvider);
      ref.invalidate(allPurchasesProvider);
    }
  }

  void _showResult(Failure? failure, String successMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure?.message ?? successMessage)),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }
}

class _PurchaseDialog extends ConsumerStatefulWidget {
  const _PurchaseDialog({this.purchase});

  final Purchase? purchase;

  @override
  ConsumerState<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends ConsumerState<_PurchaseDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _paidController;
  late final TextEditingController _noteController;

  late DateTime _date;
  late List<PurchaseItem> _items;
  String? _accountId;
  String? _supplierId;

  Money get _total => _items.fold(
        Money.zero,
        (sum, item) => sum + item.lineTotal,
      );

  @override
  void initState() {
    super.initState();

    final purchase = widget.purchase;
    _date = purchase?.date ?? DateTime.now();
    _items = [...?purchase?.items];
    _accountId = purchase?.accountId;
    _supplierId = purchase?.supplierId;
    _paidController = TextEditingController(
      text: purchase?.paidAmount.toDecimalString() ?? '0.00',
    );
    _noteController = TextEditingController(text: purchase?.note ?? '');
  }

  @override
  void dispose() {
    _paidController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final products = await ref
        .read(productRepositoryProvider)
        .watchActive()
        .first;

    if (!mounted) return;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف منتجًا نشطًا أولًا.')),
      );
      return;
    }

    final item = await showDialog<PurchaseItem>(
      context: context,
      builder: (_) => _PurchaseItemDialog(products: products),
    );

    if (item != null && mounted) {
      setState(() => _items = [..._items, item]);
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
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
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف بندًا واحدًا على الأقل.')),
      );
      return;
    }

    final accountId = _accountId;
    final paidAmount = Money.tryParse(_paidController.text);

    if (accountId == null || paidAmount == null) return;

    final note = _noteController.text.trim();

    Navigator.of(context).pop(
      Purchase(
        id: widget.purchase?.id ?? const Uuid().v4(),
        date: DateTime.utc(_date.year, _date.month, _date.day),
        accountId: accountId,
        supplierId: _supplierId,
        total: _total,
        paidAmount: paidAmount,
        note: note.isEmpty ? null : note,
        items: List<PurchaseItem>.unmodifiable(_items),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsStream = ref.watch(accountRepositoryProvider).watchActive();
    final suppliersStream = ref.watch(contactRepositoryProvider).watchSuppliers();

    return AlertDialog(
      title: Text(widget.purchase == null ? 'فاتورة شراء جديدة' : 'تعديل فاتورة شراء'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder(
                  stream: accountsStream,
                  builder: (context, snapshot) {
                    final accounts = snapshot.data ?? const [];
                    final selectedAccountId =
                        accounts.any((account) => account.id == _accountId)
                            ? _accountId
                            : null;

                    return DropdownButtonFormField<String>(
                      initialValue: selectedAccountId,
                      decoration: const InputDecoration(
                        labelText: 'حساب الدفع',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                      items: [
                        if (_accountId != null && selectedAccountId == null)
                          DropdownMenuItem(
                            value: _accountId,
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
                  stream: suppliersStream,
                  builder: (context, snapshot) {
                    final suppliers = snapshot.data ?? const [];
                    final selectedSupplierId =
                        suppliers.any((supplier) => supplier.id == _supplierId)
                            ? _supplierId
                            : null;

                    return DropdownButtonFormField<String>(
                      initialValue: selectedSupplierId ?? '',
                      decoration: const InputDecoration(
                        labelText: 'المورد (اختياري)',
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('بدون مورد'),
                        ),
                        if (_supplierId != null && selectedSupplierId == null)
                          DropdownMenuItem(
                            value: _supplierId,
                            child: const Text('المورد السابق غير متاح'),
                          ),
                        for (final supplier in suppliers)
                          DropdownMenuItem(
                            value: supplier.id,
                            child: Text(supplier.name),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _supplierId =
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
                  title: const Text('تاريخ الشراء'),
                  subtitle: Text(
                    '${_date.day.toString().padLeft(2, '0')}/'
                    '${_date.month.toString().padLeft(2, '0')}/'
                    '${_date.year}',
                  ),
                  onTap: _selectDate,
                ),
                const Divider(),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'بنود الفاتورة',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إضافة منتج',
                      onPressed: _addItem,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('لم تتم إضافة منتجات.'),
                  )
                else
                  for (var index = 0; index < _items.length; index++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('منتج: ${_items[index].productId}'),
                      subtitle: Text(
                        '${Money(_items[index].quantityMilli).toDecimalString(decimals: 3)}'
                        ' وحدة × ${_items[index].unitPrice.format()}'
                        ' = ${_items[index].lineTotal.format()}',
                      ),
                      trailing: IconButton(
                        tooltip: 'إزالة البند',
                        onPressed: () => _removeItem(index),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الإجمالي'),
                  trailing: Text(
                    _total.format(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextFormField(
                  controller: _paidController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المدفوع',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final amount = Money.tryParse(value ?? '');
                    if (amount == null || amount.minor < 0) {
                      return 'أدخل مبلغًا مدفوعًا صحيحًا.';
                    }
                    if (amount.minor > _total.minor) {
                      return 'المبلغ المدفوع أكبر من الإجمالي.';
                    }
                    return null;
                  },
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

class _PurchaseItemDialog extends StatefulWidget {
  const _PurchaseItemDialog({
    required this.products,
  });

  final List<Product> products;

  @override
  State<_PurchaseItemDialog> createState() => _PurchaseItemDialogState();
}

class _PurchaseItemDialogState extends State<_PurchaseItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();

  String? _productId;

  Product? get _selectedProduct {
    for (final product in widget.products) {
      if (product.id == _productId) return product;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.products.isNotEmpty) {
      _productId = widget.products.first.id;
      _priceController.text =
          widget.products.first.costPrice.toDecimalString();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final product = _selectedProduct;
    final quantity = Money.tryParse(
      _quantityController.text,
      decimals: 3,
    );
    final unitPrice = Money.tryParse(_priceController.text);

    if (product == null ||
        quantity == null ||
        unitPrice == null ||
        quantity.minor <= 0) {
      return;
    }

    Navigator.of(context).pop(
      PurchaseItem(
        productId: product.id,
        quantityMilli: quantity.minor,
        unitPrice: unitPrice,
        unitCost: unitPrice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة بند شراء'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _productId,
                decoration: const InputDecoration(labelText: 'المنتج'),
                items: [
                  for (final product in widget.products)
                    DropdownMenuItem(
                      value: product.id,
                      child: Text('${product.name} • ${product.unit}'),
                    ),
                ],
                onChanged: (value) {
                  final product = widget.products
                      .where((item) => item.id == value)
                      .firstOrNull;
                  setState(() {
                    _productId = value;
                    if (product != null) {
                      _priceController.text =
                          product.costPrice.toDecimalString();
                    }
                  });
                },
                validator: (value) =>
                    value == null ? 'اختر المنتج.' : null,
              ),
              TextFormField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'الكمية (حتى 3 خانات عشرية)',
                ),
                validator: (value) {
                  final quantity = Money.tryParse(
                    value ?? '',
                    decimals: 3,
                  );
                  if (quantity == null || quantity.minor <= 0) {
                    return 'أدخل كمية أكبر من صفر.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'سعر الوحدة',
                ),
                validator: (value) {
                  final price = Money.tryParse(value ?? '');
                  if (price == null || price.minor < 0) {
                    return 'أدخل سعرًا صحيحًا.';
                  }
                  return null;
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
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}
