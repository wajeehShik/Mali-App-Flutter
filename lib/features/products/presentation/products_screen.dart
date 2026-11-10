import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failure.dart';
import '../../../core/utils/money.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_providers.dart';
import '../domain/product.dart';
import 'product_providers.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  late Future<Result<List<Product>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = ref.read(productRepositoryProvider).getAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _productsFuture = ref.read(productRepositoryProvider).getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryStream = ref
        .watch(categoryRepositoryProvider)
        .watchByKind(CategoryKind.product);

    return Scaffold(
      appBar: AppBar(title: const Text('المنتجات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editProduct(context, categoryStream),
        icon: const Icon(Icons.add),
        label: const Text('منتج جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الباركود',
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
            child: FutureBuilder<Result<List<Product>>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('تعذّر تحميل المنتجات.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final result = snapshot.data!;
                final products = result.valueOrNull;
                if (products == null) {
                  return Center(
                    child: Text(
                      result.failureOrNull?.message ?? 'تعذّر تحميل المنتجات.',
                    ),
                  );
                }

                final normalized = _query.toLowerCase();
                final filtered = products.where((product) {
                  if (normalized.isEmpty) return true;
                  return product.name.toLowerCase().contains(normalized) ||
                      (product.barcode?.toLowerCase().contains(normalized) ??
                          false);
                }).toList(growable: false);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? 'لا توجد منتجات بعد.'
                          : 'لا توجد نتائج مطابقة.',
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return _ProductTile(
                        product: product,
                        onTap: () => _editProduct(
                          context,
                          categoryStream,
                          product: product,
                        ),
                        onToggle: () => _setActive(product),
                        onDelete: () => _deleteProduct(product),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProduct(
    BuildContext context,
    Stream<List<Category>> categories, {
    Product? product,
  }) async {
    final edited = await showDialog<Product>(
      context: context,
      builder: (_) => _ProductDialog(
        categories: categories,
        product: product,
      ),
    );

    if (edited == null || !context.mounted) return;

    final controller = ref.read(productControllerProvider);
    final failure = product == null
        ? await controller.create(edited)
        : await controller.update(edited);

    if (!context.mounted) return;

    _showResult(
      context,
      failure,
      product == null ? 'تم إنشاء المنتج.' : 'تم تحديث المنتج.',
    );
    if (failure == null) _reload();
  }

  Future<void> _setActive(Product product) async {
    final failure = await ref
        .read(productControllerProvider)
        .setActive(product.id, !product.isActive);

    if (!mounted) return;

    _showResult(
      context,
      failure,
      product.isActive ? 'تم إيقاف المنتج.' : 'تم تفعيل المنتج.',
    );
    if (failure == null) _reload();
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('سيتم حذف «${product.name}» حذفًا ناعمًا.'),
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

    final failure =
        await ref.read(productControllerProvider).softDelete(product.id);

    if (!mounted) return;

    _showResult(context, failure, 'تم حذف المنتج.');
    if (failure == null) _reload();
  }

  void _showResult(BuildContext context, Failure? failure, String success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure?.message ?? success)),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(product.name),
        subtitle: Text(
          '${product.salePrice.format()} • ${product.unit}'
          '${product.barcode == null ? '' : ' • ${product.barcode}'}',
        ),
        leading: CircleAvatar(
          child: Icon(
            product.isActive ? Icons.inventory_2_outlined : Icons.inventory,
          ),
        ),
        onTap: onTap,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'toggle') onToggle();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(product.isActive ? 'إيقاف' : 'تفعيل'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
        ),
      ),
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({
    required this.categories,
    this.product,
  });

  final Stream<List<Category>> categories;
  final Product? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _unitController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _minStockController;
  String _categoryId = '';

  @override
  void initState() {
    super.initState();
    final product = widget.product;

    _nameController = TextEditingController(text: product?.name ?? '');
    _barcodeController = TextEditingController(text: product?.barcode ?? '');
    _unitController = TextEditingController(text: product?.unit ?? 'قطعة');
    _salePriceController = TextEditingController(
      text: product?.salePrice.toDecimalString() ?? '',
    );
    _costPriceController = TextEditingController(
      text: product?.costPrice.toDecimalString() ?? '',
    );
    _minStockController = TextEditingController(
      text: product == null
          ? '0'
          : Money(product.minStock).toDecimalString(decimals: 3),
    );
    _categoryId = product?.categoryId ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    _salePriceController.dispose();
    _costPriceController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  String? _validateMoney(String? value, String label) {
    final parsed = Money.tryParse(value ?? '');
    if (parsed == null) return 'أدخل $label صحيحًا.';
    if (parsed.isNegative) return '$label لا يمكن أن يكون سالبًا.';
    return null;
  }

  String? _validateStock(String? value) {
    final parsed = Money.tryParse(value ?? '', decimals: 3);
    if (parsed == null) return 'أدخل حد المخزون بشكل صحيح (حتى 3 خانات).';
    if (parsed.isNegative) return 'حد المخزون لا يمكن أن يكون سالبًا.';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final salePrice = Money.tryParse(_salePriceController.text)!;
    final costPrice = Money.tryParse(_costPriceController.text)!;
    final minStock =
        Money.tryParse(_minStockController.text, decimals: 3)!.minor;

    Navigator.of(context).pop(
      Product(
        id: widget.product?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        categoryId: _categoryId.isEmpty ? null : _categoryId,
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        unit: _unitController.text.trim(),
        salePrice: salePrice,
        costPrice: costPrice,
        minStock: minStock,
        isActive: widget.product?.isActive ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'إضافة منتج' : 'تعديل منتج'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 150,
                  decoration: const InputDecoration(labelText: 'اسم المنتج'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'اسم المنتج مطلوب.'
                      : null,
                ),
                StreamBuilder<List<Category>>(
                  stream: widget.categories,
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? const <Category>[];
                    final hasCurrentCategory = categories.any(
                      (category) => category.id == _categoryId,
                    );

                    return DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(labelText: 'التصنيف'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('بدون تصنيف'),
                        ),
                        if (_categoryId.isNotEmpty && !hasCurrentCategory)
                          DropdownMenuItem(
                            value: _categoryId,
                            child: const Text('التصنيف الحالي غير متاح'),
                          ),
                        for (final category in categories)
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _categoryId = value);
                        }
                      },
                    );
                  },
                ),
                TextFormField(
                  controller: _barcodeController,
                  maxLength: 64,
                  decoration: const InputDecoration(labelText: 'الباركود'),
                ),
                TextFormField(
                  controller: _unitController,
                  maxLength: 30,
                  decoration: const InputDecoration(labelText: 'الوحدة'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'وحدة المنتج مطلوبة.'
                      : null,
                ),
                TextFormField(
                  controller: _salePriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'سعر البيع'),
                  validator: (value) => _validateMoney(value, 'سعر البيع'),
                ),
                TextFormField(
                  controller: _costPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'سعر التكلفة'),
                  validator: (value) => _validateMoney(value, 'سعر التكلفة'),
                ),
                TextFormField(
                  controller: _minStockController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'حد التنبيه للمخزون',
                  ),
                  validator: _validateStock,
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
