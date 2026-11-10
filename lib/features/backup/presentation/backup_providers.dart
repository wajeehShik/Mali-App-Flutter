import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/backup_service.dart';

/// خدمة النسخ الاحتياطي على قاعدة بيانات التطبيق الحالية.
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(appDatabaseProvider));
});
