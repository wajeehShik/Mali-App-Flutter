import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failure.dart';
import '../domain/category.dart';
import 'category_providers.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  int _selectedTab = 0;

  static const _kinds = [
    CategoryKind.income,
    CategoryKind.expense,
    CategoryKind.product,
  ];

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(categoryRepositoryProvider);

    return DefaultTabController(
      length: _kinds.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التصنيفات'),
          bottom: TabBar(
            onTap: (index) => setState(() => _selectedTab = index),
            tabs: const [
              Tab(text: 'الدخل'),
              Tab(text: 'المصروف'),
              Tab(text: 'المنتجات'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editCategory(
            context,
            initialKind: _kinds[_selectedTab],
          ),
          icon: const Icon(Icons.add),
          label: const Text('تصنيف جديد'),
        ),
        body: TabBarView(
          children: [
            for (final kind in _kinds)
              _CategoryList(
                stream: repository.watchByKind(kind),
                onEdit: (category) => _editCategory(
                  context,
                  category: category,
                  initialKind: kind,
                ),
                onDelete: (category) => _deleteCategory(context, category),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCategory(
    BuildContext context, {
    required CategoryKind initialKind,
    Category? category,
  }) async {
    final edited = await showDialog<Category>(
      context: context,
      builder: (_) => _CategoryDialog(
        category: category,
        initialKind: initialKind,
      ),
    );

    if (edited == null || !context.mounted) return;

    final controller = ref.read(categoryControllerProvider);
    final failure = category == null
        ? await controller.create(edited)
        : await controller.update(edited);

    if (!context.mounted) return;

    _showResult(
      context,
      failure,
      category == null ? 'تم إنشاء التصنيف.' : 'تم تحديث التصنيف.',
    );
  }

  Future<void> _deleteCategory(
    BuildContext context,
    Category category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف التصنيف'),
        content: Text('هل تريد حذف «${category.name}»؟'),
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

    if (confirmed != true || !context.mounted) return;

    final failure =
        await ref.read(categoryControllerProvider).softDelete(category.id);

    if (!context.mounted) return;
    _showResult(context, failure, 'تم حذف التصنيف.');
  }

  void _showResult(BuildContext context, Failure? failure, String success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure?.message ?? success)),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.stream,
    required this.onEdit,
    required this.onDelete,
  });

  final Stream<List<Category>> stream;
  final ValueChanged<Category> onEdit;
  final ValueChanged<Category> onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Category>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('تعذّر تحميل التصنيفات.'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data!;
        if (categories.isEmpty) {
          return const Center(child: Text('لا توجد تصنيفات هنا بعد.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          itemCount: categories.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final category = categories[index];

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.category_outlined),
                ),
                title: Text(category.name),
                onTap: () => onEdit(category),
                trailing: IconButton(
                  tooltip: 'حذف',
                  onPressed: () => onDelete(category),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({
    required this.initialKind,
    this.category,
  });

  final CategoryKind initialKind;
  final Category? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late CategoryKind _kind;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.category?.name ?? '');
    _kind = widget.category?.kind ?? widget.initialKind;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      Category(
        id: widget.category?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        kind: _kind,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'تصنيف جديد' : 'تعديل التصنيف'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'اسم التصنيف'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'اسم التصنيف مطلوب.'
                  : null,
            ),
            DropdownButtonFormField<CategoryKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'النوع'),
              items: const [
                DropdownMenuItem(
                  value: CategoryKind.income,
                  child: Text('الدخل'),
                ),
                DropdownMenuItem(
                  value: CategoryKind.expense,
                  child: Text('المصروف'),
                ),
                DropdownMenuItem(
                  value: CategoryKind.product,
                  child: Text('المنتجات'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _kind = value);
              },
            ),
          ],
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
