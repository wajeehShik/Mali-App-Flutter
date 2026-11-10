import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';

/// ينشئ نسخ SQLite احتياطية ويتحقق منها ويستعيدها بأمان.
class BackupService {
  const BackupService(this._database);

  final AppDatabase _database;

  /// ينشئ نسخة احتياطية في مجلد مستندات التطبيق.
  /// يستخدم VACUUM INTO لتجنب نسخ ملف SQLite الحي مباشرة.
  Future<File> createBackup() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final backupDirectory = Directory(
      p.join(documentsDirectory.path, 'backups'),
    );
    await backupDirectory.create(recursive: true);

    final backupFile = File(
      p.join(backupDirectory.path, 'mali_backup_${_timestamp()}.sqlite'),
    );

    final escapedPath = backupFile.path.replaceAll("'", "''");
    await _database.customStatement("VACUUM INTO '$escapedPath'");

    await _validateSqliteFile(backupFile);
    return backupFile;
  }

  /// يستعيد [source] بعد التحقق منها وحفظ نسخة أمان من القاعدة الحالية.
  ///
  /// عند النجاح يصبح اتصال قاعدة البيانات الحالي مغلقًا. يجب إعادة تشغيل
  /// التطبيق ليُفتح اتصال جديد على قاعدة البيانات المستعادة.
  /// يعيد مسار نسخة الأمان المنشأة قبل الاستعادة.
  Future<File> restoreBackup(File source) async {
    await _validateSqliteFile(source);
    await _validateDatabaseIntegrity(source);

    final safetyBackup = await createBackup();
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databaseFile = File(
      p.join(documentsDirectory.path, 'mali.sqlite'),
    );
    final stagingFile = File(
      p.join(
        documentsDirectory.path,
        'mali_restore_${_timestamp()}.sqlite',
      ),
    );
    final previousFile = File(
      p.join(
        documentsDirectory.path,
        'mali_before_restore_${_timestamp()}.sqlite',
      ),
    );

    await source.copy(stagingFile.path);
    await _validateSqliteFile(stagingFile);
    await _validateDatabaseIntegrity(stagingFile);

    await _database.close();

    var movedCurrentDatabase = false;
    try {
      if (await databaseFile.exists()) {
        await databaseFile.rename(previousFile.path);
        movedCurrentDatabase = true;
      }

      await stagingFile.rename(databaseFile.path);

      if (movedCurrentDatabase && await previousFile.exists()) {
        await previousFile.delete();
      }

      return safetyBackup;
    } catch (_) {
      if (await databaseFile.exists()) {
        await databaseFile.delete();
      }

      if (movedCurrentDatabase && await previousFile.exists()) {
        await previousFile.rename(databaseFile.path);
      }

      rethrow;
    } finally {
      if (await stagingFile.exists()) {
        await stagingFile.delete();
      }
    }
  }

  Future<void> _validateSqliteFile(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('ملف النسخة غير موجود.', file.path);
    }

    if (await file.length() < 100) {
      throw FileSystemException('ملف النسخة غير مكتمل.', file.path);
    }

    final handle = await file.open();
    try {
      final header = String.fromCharCodes(await handle.read(16));
      if (header != 'SQLite format 3\u0000') {
        throw FileSystemException(
          'الملف المحدد ليس قاعدة SQLite صالحة.',
          file.path,
        );
      }
    } finally {
      await handle.close();
    }
  }

  Future<void> _validateDatabaseIntegrity(File file) async {
    final verifier = AppDatabase(
      NativeDatabase.createInBackground(file),
    );

    try {
      final integrityRows =
          await verifier.customSelect('PRAGMA integrity_check').get();

      if (integrityRows.isEmpty ||
          integrityRows.first.read<String>('integrity_check') != 'ok') {
        throw FileSystemException(
          'قاعدة البيانات داخل النسخة تالفة.',
          file.path,
        );
      }

      final accountsTable = await verifier
          .customSelect(
            'SELECT name FROM sqlite_master '
            "WHERE type = 'table' AND name = 'accounts'",
          )
          .getSingleOrNull();

      if (accountsTable == null) {
        throw FileSystemException(
          'النسخة ليست نسخة صالحة من تطبيق مالي.',
          file.path,
        );
      }
    } finally {
      await verifier.close();
    }
  }

  String _timestamp() {
    return DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
  }
}
