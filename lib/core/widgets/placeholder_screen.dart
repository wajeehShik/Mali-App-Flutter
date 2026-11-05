import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// شاشة مؤقتة لمسار لم تُنفَّذ ميزته بعد.
/// تُحذف عند اكتمال آخر ميزة (لا تُحتسب أي ميزة مكتملة بوجودها).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    this.icon = Icons.construction_rounded,
    super.key,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(title, style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'هذه الميزة قيد البناء ولم تُنفَّذ بعد.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}