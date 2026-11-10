import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  File? _backupFile;
  bool _isCreating = false;
  bool _isSharing = false;
  bool _isRestoring = false;
  String? _errorMessage;

  Future<void> _createBackup() async {
    if (_isCreating || _isRestoring) return;

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final file = await ref.read(backupServiceProvider).createBackup();
      if (!mounted) return;

      setState(() => _backupFile = file);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء النسخة الاحتياطية بنجاح.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'تعذّر إنشاء النسخة الاحتياطية: $error');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _shareBackup() async {
    final file = _backupFile;
    if (file == null || _isSharing) return;

    setState(() {
      _isSharing = true;
      _errorMessage = null;
    });

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'نسخة احتياطية من تطبيق مالي',
          text: 'نسخة قاعدة بيانات تطبيق مالي.',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'تعذّرت مشاركة النسخة: $error');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_isCreating || _isRestoring) return;

    setState(() => _errorMessage = null);

    try {
      final selectedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['sqlite', 'db'],
      );

      if (!mounted || selectedFiles.isEmpty) return;

      final selectedFile = selectedFiles.first;
      final selectedPath = selectedFile.path;

      if (selectedPath == null || selectedPath.isEmpty) {
        setState(() => _errorMessage = 'تعذّر الوصول إلى الملف المحدد.');
        return;
      }

      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تأكيد استعادة النسخة'),
          content: const Text(
            'ستُستبدل بيانات التطبيق الحالية ببيانات ملف النسخة المحدد. '
            'سيُنشئ التطبيق نسخة أمان من بياناتك الحالية أولًا. '
            'بعد اكتمال الاستعادة يجب إغلاق التطبيق وفتحه مجددًا. '
            'هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('استعادة البيانات'),
            ),
          ],
        ),
      );

      if (!mounted || approved != true) return;

      setState(() => _isRestoring = true);

      final safetyBackup = await ref
          .read(backupServiceProvider)
          .restoreBackup(File(selectedPath));

      if (!mounted) return;

      setState(() => _backupFile = safetyBackup);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('اكتملت الاستعادة'),
          content: Text(
            'تمت استعادة قاعدة البيانات بنجاح. '
            'أُنشئت نسخة أمان من البيانات السابقة هنا:\n'
            '${safetyBackup.path}\n\n'
            'أغلق التطبيق بالكامل ثم افتحه مجددًا لاستخدام البيانات المستعادة.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'تعذّرت استعادة النسخة: $error');
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isCreating || _isRestoring;

    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي والاستعادة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'أنشئ نسخة محلية من قاعدة البيانات لحفظ حساباتك '
                'ومعاملاتك ومنتجاتك. احتفظ بالنسخة في مكان آمن. '
                'استعادة نسخة قديمة تستبدل البيانات الحالية.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isBusy ? null : _createBackup,
            icon: _isCreating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.backup_outlined),
            label: Text(
              _isCreating ? 'جارٍ إنشاء النسخة...' : 'إنشاء نسخة احتياطية',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isBusy ? null : _restoreBackup,
            icon: _isRestoring
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.settings_backup_restore_outlined),
            label: Text(
              _isRestoring ? 'جارٍ استعادة البيانات...' : 'استعادة نسخة',
            ),
          ),
          if (_backupFile != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(child: Text('النسخة جاهزة')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(_backupFile!.path),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isSharing || isBusy ? null : _shareBackup,
                      icon: _isSharing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share_outlined),
                      label: Text(
                        _isSharing ? 'جارٍ المشاركة...' : 'مشاركة النسخة',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_errorMessage!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
