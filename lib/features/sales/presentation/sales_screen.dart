import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../contacts/presentation/contact_providers.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_providers.dart';
import '../domain/sale.dart';
import 'sale_providers.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المبيعات ونقطة البيع'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(salesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editSale(),
        icon: const Icon(Icons.point_of_sale_outlined),
        label: const Text('بيع جديد'),
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
                hintText: 'ابحث بالملاحظة أو رقم الفاتورة',
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
            child: salesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('تعذّر تحميل المبيعات.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(salesProvider),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
              data: (sales) {
                final filteredSales = sales.where((sale) {
                  if (_query.isEmpty) return true;
                  return sale.id.toLowerCase().contains(_query) ||
                      (sale.note?.toLowerCase().contains(_query) ?? false);
                }).toList(growable: false);

                if (filteredSales.isEmpty) {
                  return Center(
                    child: Text(
                      sales.isEmpty
                          ? 'لا توجد مبيعات بعد. ابدأ ببيع جديد.'
                          : 'لا توجد نتائج مطابقة.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: filteredSales.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final sale = filteredSales[index];

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.point_of_sale_outlined),
                        ),
                        title: Text(sale.total.format()),
                        subtitle: Text(
                          '${_formatDate(sale.date)}'
                          ' • ${sale.items.length} أصناف'
                          '${sale.note == null ? '' : '\n${sale.note}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _editSale(sale);
                            if (value == 'delete') _deleteSale(sale);
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
                        onTap: () => _editSale(sale),
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

  Future<void> _editSale([Sale? sale]) async {
    final edited = await showDialog<Sale>(
      context: context,
      builder: (_) => _SaleDialog(sale: sale),
    );

    if (edited == null || !mounted) return;

    final controller = ref.read(saleControllerProvider);
    final failure = sale == null
        ? await controller.create(edited)
        : await controller.update(edited);

    if (!mounted) return;

    _showResult(
      failure,
      sale == null ? 'تم حفظ فاتورة البيع.' : 'تم تحديث فاتورة البيع.',
    );

    if (failure == null) {
      ref.invalidate(salesProvider);
      ref.invalidate(allSalesProvider);
    }
  }

  Future<void> _deleteSale(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف فاتورة البيع'),
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

    final failure = await ref.read(saleControllerProvider).softDelete(sale.id);
    if (!mounted) return;

    _showResult(failure, 'تم حذف فاتورة البيع.');

    if (failure == null) {
      ref.invalidate(salesProvider);
      ref.invalidate(allSalesProvider);
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

class _SaleDialog extends ConsumerStatefulWidget {
  const _SaleDialog({this.sale});

  final Sale? sale;

  @override
  ConsumerState<_SaleDialog> createState() => _SaleDialogState();
}

class _SaleDialogState extends ConsumerState<_SaleDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _paidController;
  late final TextEditingController _noteController;

  late DateTime _date;
  late List<SaleItem> _items;
  String? _accountId;
  String? _customerId;

  Money get _total => _items.fold(
        Money.zero,
        (sum, item) => sum + item.lineTotal,
      );

  @override
  void initState() {
    super.initState();

    final sale = widget.sale;
    _date = sale?.date ?? DateTime.now();
    _items = [...?sale?.items];
    _accountId = sale?.accountId;
    _customerId = sale?.customerId;

    _paidController = TextEditingController(
      text: sale?.paidAmount.toDecimalString() ?? '0.00',
    );
    _noteController = TextEditingController(text: sale?.note ?? '');
  }

  @override
  void dispose() {
    _paidController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final products =
        await ref.read(productRepositoryProvider).watchActive().first;
    if (!mounted) return;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد منتجات نشطة للبيع.')),
      );
      return;
    }

    final item = await showDialog<SaleItem>(
      context: context,
      builder: (_) => _SaleItemDialog(products: products),
    );

    if (item != null && mounted) {
      setState(() => _items = [..._items, item]);
    }
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
        const SnackBar(content: Text('أضف صنفًا واحدًا على الأقل.')),
      );
      return;
    }

    final accountId = _accountId;
    final paidAmount = Money.tryParse(_paidController.text);

    if (accountId == null || paidAmount == null) return;

    final note = _noteController.text.trim();

    Navigator.of(context).pop(
      Sale(
        id: widget.sale?.id ?? const Uuid().v4(),
        date: DateTime.utc(_date.year, _date.month, _date.day),
        accountId: accountId,
        customerId: _customerId,
        total: _total,
        paidAmount: paidAmount,
        note: note.isEmpty ? null : note,
        items: List<SaleItem>.unmodifiable(_items),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsStream = ref.watch(accountRepositoryProvider).watchActive();
    final customersStream =
        ref.watch(contactRepositoryProvider).watchCustomers();

    return AlertDialog(
      title: Text(widget.sale == null ? 'بيع جديد' : 'تعديل فاتورة البيع'),
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
                    final accountAvailable =
                        accounts.any((account) => account.id == _accountId);

                    return DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      decoration: const InputDecoration(
                        labelText: 'حساب استلام المبلغ',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                      items: [
                        if (_accountId != null && !accountAvailable)
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
                  stream: customersStream,
                  builder: (context, snapshot) {
                    final customers = snapshot.data ?? const [];
                    final customerAvailable =
                        customers.any((customer) => customer.id == _customerId);

                    return DropdownButtonFormField<String>(
                      initialValue: customerAvailable ? _customerId ?? '' : '',
                      decoration: const InputDecoration(
                        labelText: 'العميل (اختياري)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('بيع نقدي / بدون عميل'),
                        ),
                        if (_customerId != null && !customerAvailable)
                          DropdownMenuItem(
                            value: _customerId,
                            child: const Text('العميل السابق غير متاح'),
                          ),
                        for (final customer in customers)
                          DropdownMenuItem(
                            value: customer.id,
                            child: Text(customer.name),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _customerId =
                              value == null || value.isEmpty ? null : value;
                        });
                      },
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('تاريخ البيع'),
                  subtitle: Text(_formatDate(_date)),
                  onTap: _selectDate,
                ),
                const Divider(),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'أصناف الفاتورة',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إضافة صنف',
                      onPressed: _addItem,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('لم تتم إضافة أصناف.'),
                  )
                else
                  for (var index = 0; index < _items.length; index++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('منتج: ${_items[index].productId}'),
                      subtitle: Text(
                        '${Money(_items[index].quantityMilli).toDecimalString(decimals: 3)}'
                        ' × ${_items[index].unitPrice.format()}'
                        ' = ${_items[index].lineTotal.format()}',
                      ),
                      trailing: IconButton(
                        tooltip: 'إزالة الصنف',
                        onPressed: () {
                          setState(() => _items.removeAt(index));
                        },
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
                    labelText: 'المبلغ المقبوض',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final amount = Money.tryParse(value ?? '');
                    if (amount == null || amount.minor < 0) {
                      return 'أدخل مبلغًا مقبوضًا صحيحًا.';
                    }
                    if (amount.minor > _total.minor) {
                      return 'المبلغ المقبوض أكبر من إجمالي الفاتورة.';
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
          child: const Text('حفظ البيع'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _SaleItemDialog extends StatefulWidget {
  const _SaleItemDialog({required this.products});

  final List<Product> products;

  @override
  State<_SaleItemDialog> createState() => _SaleItemDialogState();
}

class _SaleItemDialogState extends State<_SaleItemDialog> {
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
      final product = widget.products.first;
      _productId = product.id;
      _priceController.text = product.salePrice.toDecimalString();
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
    final price = Money.tryParse(_priceController.text);

    if (product == null ||
        quantity == null ||
        price == null ||
        quantity.minor <= 0) {
      return;
    }

    Navigator.of(context).pop(
      SaleItem(
        productId: product.id,
        quantityMilli: quantity.minor,
        unitPrice: price,
        unitCost: product.costPrice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة صنف للبيع'),
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
                  Product? selected;

                  for (final product in widget.products) {
                    if (product.id == value) selected = product;
                  }

                  setState(() {
                    _productId = value;
                    if (selected != null) {
                      _priceController.text =
                          selected.salePrice.toDecimalString();
                    }
                  });
                },
                validator: (value) => value == null ? 'اختر المنتج.' : null,
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
                  final quantity = Money.tryParse(value ?? '', decimals: 3);
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
                decoration: const InputDecoration(labelText: 'سعر الوحدة'),
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
