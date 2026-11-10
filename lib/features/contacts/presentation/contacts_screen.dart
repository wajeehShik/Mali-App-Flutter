import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failure.dart';
import '../domain/contact.dart';
import 'contact_providers.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  int _selectedTab = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(contactRepositoryProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('العملاء والموردون'),
          bottom: TabBar(
            onTap: (index) => setState(() => _selectedTab = index),
            tabs: const [
              Tab(text: 'العملاء'),
              Tab(text: 'الموردون'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editContact(
            context,
            initialKind: _selectedTab == 0
                ? ContactKind.customer
                : ContactKind.supplier,
          ),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('إضافة جهة'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو الهاتف',
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
              child: TabBarView(
                children: [
                  _ContactList(
                    stream: repository.watchCustomers(),
                    query: _query,
                    onEdit: (contact) =>
                        _editContact(context, contact: contact),
                    onDelete: (contact) => _deleteContact(context, contact),
                  ),
                  _ContactList(
                    stream: repository.watchSuppliers(),
                    query: _query,
                    onEdit: (contact) =>
                        _editContact(context, contact: contact),
                    onDelete: (contact) => _deleteContact(context, contact),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editContact(
    BuildContext context, {
    Contact? contact,
    ContactKind initialKind = ContactKind.customer,
  }) async {
    final edited = await showDialog<Contact>(
      context: context,
      builder: (_) => _ContactDialog(
        contact: contact,
        initialKind: initialKind,
      ),
    );

    if (edited == null || !context.mounted) return;

    final controller = ref.read(contactControllerProvider);
    final failure = contact == null
        ? await controller.create(edited)
        : await controller.update(edited);

    if (!context.mounted) return;

    _showResult(
      context,
      failure,
      successMessage: contact == null ? 'تمت إضافة الجهة.' : 'تم تحديث الجهة.',
    );
  }

  Future<void> _deleteContact(BuildContext context, Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف جهة الاتصال'),
        content: Text('سيتم حذف «${contact.name}» حذفًا ناعمًا.'),
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
        await ref.read(contactControllerProvider).softDelete(contact.id);

    if (!context.mounted) return;
    _showResult(context, failure, successMessage: 'تم حذف الجهة.');
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

class _ContactList extends StatelessWidget {
  const _ContactList({
    required this.stream,
    required this.query,
    required this.onEdit,
    required this.onDelete,
  });

  final Stream<List<Contact>> stream;
  final String query;
  final ValueChanged<Contact> onEdit;
  final ValueChanged<Contact> onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Contact>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('تعذّر تحميل جهات الاتصال.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final normalizedQuery = query.toLowerCase();
        final contacts = snapshot.data!.where((contact) {
          return normalizedQuery.isEmpty ||
              contact.name.toLowerCase().contains(normalizedQuery) ||
              (contact.phone?.toLowerCase().contains(normalizedQuery) ?? false);
        }).toList(growable: false);

        if (contacts.isEmpty) {
          return Center(
            child: Text(
              query.isEmpty
                  ? 'لا توجد جهات اتصال هنا بعد.'
                  : 'لا توجد نتائج مطابقة.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          itemCount: contacts.length,
     separatorBuilder: (context, index) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final contact = contacts[index];

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(switch (contact.kind) {
                    ContactKind.customer => Icons.person_outline,
                    ContactKind.supplier => Icons.local_shipping_outlined,
                    ContactKind.both => Icons.people_outline,
                  }),
                ),
                title: Text(contact.name),
                subtitle: Text(
                  [
                    if (contact.phone != null) contact.phone!,
                    if (contact.note != null) contact.note!,
                  ].join(' • '),
                ),
                onTap: () => onEdit(contact),
                trailing: IconButton(
                  tooltip: 'حذف',
                  onPressed: () => onDelete(contact),
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

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({
    required this.initialKind,
    this.contact,
  });

  final ContactKind initialKind;
  final Contact? contact;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _noteController;
  late ContactKind _kind;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _phoneController = TextEditingController(text: widget.contact?.phone ?? '');
    _noteController = TextEditingController(text: widget.contact?.note ?? '');
    _kind = widget.contact?.kind ?? widget.initialKind;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      Contact(
        id: widget.contact?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        kind: _kind,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.contact == null ? 'إضافة جهة اتصال' : 'تعديل جهة اتصال'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'الاسم'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'الاسم مطلوب.'
                    : null,
              ),
              TextFormField(
                controller: _phoneController,
                maxLength: 30,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'الهاتف'),
              ),
              DropdownButtonFormField<ContactKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'النوع'),
                items: const [
                  DropdownMenuItem(
                    value: ContactKind.customer,
                    child: Text('عميل'),
                  ),
                  DropdownMenuItem(
                    value: ContactKind.supplier,
                    child: Text('مورد'),
                  ),
                  DropdownMenuItem(
                    value: ContactKind.both,
                    child: Text('عميل ومورد'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _kind = value);
                },
              ),
              TextFormField(
                controller: _noteController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظة'),
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
