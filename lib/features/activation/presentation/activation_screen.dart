import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../core/router/app_routes.dart';
import '../domain/activation_state.dart';
import 'activation_providers.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _busy = false;
  String? _nameError;
  String? _phoneError;
  String? _codeError;
  String? _message;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _nameError = null;
      _phoneError = null;
      _message = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    final failure = await ref
        .read(activationControllerProvider.notifier)
        .submitRequest(
          name: _nameController.text,
          phone: _phoneController.text,
        );
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (failure is ValidationFailure) {
        _nameError = failure.fieldErrors['name'];
        _phoneError = failure.fieldErrors['phone'];
      }
      _message = failure?.message;
    });
  }

  Future<void> _activateWithCode() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _codeError = null;
      _message = null;
    });

    setState(() => _busy = true);
    final failure = await ref
        .read(activationControllerProvider.notifier)
        .activateWithCode(_codeController.text);
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (failure is ValidationFailure) {
        _codeError = failure.fieldErrors['code'];
      }
      _message = failure?.message;
    });

    if (failure == null) {
      context.go(AppRoutes.dashboard);
    }
  }

  Future<void> _refreshPending() async {
    setState(() {
      _busy = true;
      _message = null;
    });

    final failure =
        await ref.read(activationControllerProvider.notifier).refreshPending();
    if (!mounted) return;

    setState(() {
      _busy = false;
      _message = failure?.message;
    });

    if (failure == null &&
        ref.read(activationControllerProvider).value is ActivationActive) {
      context.go(AppRoutes.dashboard);
    }
  }

  Future<void> _copyDeviceId(String deviceId) async {
    await Clipboard.setData(ClipboardData(text: deviceId));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ معرّف الجهاز.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activation = ref.watch(activationControllerProvider);

    if (activation.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (activation.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفعيل مالي')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _failureMessage(activation.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.read(activationControllerProvider.notifier).reload(),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final state = activation.value;
    if (state is ActivationActive) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pending = state is ActivationPending;
    final rejectedMessage =
        state is NotActivated ? state.rejectedMessage : null;

    return Scaffold(
      appBar: AppBar(title: const Text('تفعيل مالي')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'أهلًا بك في مالي',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'قدّم طلب تفعيل أو أدخل رمز التفعيل الذي استلمته.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _DeviceIdCard(
              onCopy: _copyDeviceId,
            ),
            const SizedBox(height: 24),
            if (rejectedMessage != null && rejectedMessage.isNotEmpty) ...[
              _MessageBox(
                message: 'تم رفض الطلب: $rejectedMessage',
                isError: true,
              ),
              const SizedBox(height: 16),
            ],
            if (pending) ...[
              const _MessageBox(
                message: 'طلبك قيد المراجعة. يمكنك تحديث الحالة.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _refreshPending,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث الحالة'),
              ),
              const SizedBox(height: 24),
            ] else ...[
              Text(
                'طلب تفعيل',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: 'الاسم أو اسم النشاط التجاري',
                        errorText: _nameError,
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'الاسم مطلوب.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف (اختياري)',
                        errorText: _phoneError,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _submitRequest,
                        child: const Text('إرسال طلب التفعيل'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text(
              'رمز تفعيل يدوي',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              enabled: !_busy,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'الصق رمز التفعيل هنا',
                errorText: _codeError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _activateWithCode,
                child: const Text('تفعيل الرمز'),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_message != null) ...[
              const SizedBox(height: 16),
              _MessageBox(message: _message!, isError: true),
            ],
          ],
        ),
      ),
    );
  }

  String _failureMessage(Object? error) {
    if (error is FailureException) return error.failure.message;
    if (error is Failure) return error.message;
    return 'تعذّر تحميل حالة التفعيل. حاول مرة أخرى.';
  }
}

class _DeviceIdCard extends ConsumerWidget {
  const _DeviceIdCard({required this.onCopy});

  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(deviceIdProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: deviceId.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تعذّر تحميل معرّف الجهاز.'),
              TextButton(
                onPressed: () => ref.invalidate(deviceIdProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
          data: (id) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'معرّف الجهاز',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(id, textDirection: TextDirection.ltr),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'نسخ معرّف الجهاز',
                  onPressed: () => onCopy(id),
                  icon: const Icon(Icons.copy),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Theme.of(context).colorScheme.error : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.08) ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: color),
      ),
    );
  }
}
