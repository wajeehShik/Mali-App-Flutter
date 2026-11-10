import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// قاعدة بيانات مشتركة للتطبيق، تُفتح عند أول استخدام وتُغلق عند التخلص منها.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.forDevice();
  ref.onDispose(() {
    unawaited(database.close());
  });
  return database;
});
