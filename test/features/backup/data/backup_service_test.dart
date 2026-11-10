import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/features/backup/data/backup_service.dart';

import '../../../core/database/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  late Directory tempDirectory;
  late AppDatabase database;
  var databaseClosed = false;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('mali-backup-test-');
    database = createTestDatabase();
    databaseClosed = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return tempDirectory.path;
    });
  });

  tearDown(() async {
    if (!databaseClosed) await database.close();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);

    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('ينشئ نسخة SQLite صحيحة من قاعدة البيانات', () async {
    await addAccount(database, name: 'حساب اختبار');

    final service = BackupService(database);
    final backup = await service.createBackup();

    expect(await backup.exists(), isTrue);
    expect(backup.path, endsWith('.sqlite'));
    expect(await backup.length(), greaterThanOrEqualTo(100));

    final handle = await backup.open();
    try {
      final header = String.fromCharCodes(await handle.read(16));
      expect(header, 'SQLite format 3\u0000');
    } finally {
      await handle.close();
    }
  });

  test('يرفض ملفًا ليس قاعدة SQLite قبل إغلاق قاعدة التطبيق', () async {
    final invalidFile = File(
      '${tempDirectory.path}/not-a-database.sqlite',
    );
    await invalidFile.writeAsString('هذا ليس ملف قاعدة بيانات');

    final service = BackupService(database);

    await expectLater(
      service.restoreBackup(invalidFile),
      throwsA(isA<FileSystemException>()),
    );

    // يظل اتصال القاعدة الحالية صالحًا لأن فحص الملف فشل قبل الاستعادة.
    await addAccount(database, name: 'ما زال يعمل');
  });

  test('يستعيد نسخة صحيحة بعد إنشاء نسخة أمان للبيانات الحالية', () async {
    final sourceDatabase = createTestDatabase();
    await addAccount(sourceDatabase, name: 'من النسخة');

    final sourceFile = File(
      '${tempDirectory.path}/source_backup.sqlite',
    );
    final escapedSourcePath = sourceFile.path.replaceAll("'", "''");

    await sourceDatabase.customStatement(
      "VACUUM INTO '$escapedSourcePath'",
    );
    await sourceDatabase.close();

    final service = BackupService(database);
    await addAccount(database, name: 'الحالية');

    final safetyBackup = await service.restoreBackup(sourceFile);
    databaseClosed = true;

    expect(await safetyBackup.exists(), isTrue);
    expect(safetyBackup.path, endsWith('.sqlite'));

    final restoredFile = File('${tempDirectory.path}/mali.sqlite');
    expect(await restoredFile.exists(), isTrue);

    final restoredDatabase = AppDatabase(
      NativeDatabase.createInBackground(restoredFile),
    );

    try {
      final rows = await restoredDatabase
          .customSelect('SELECT COUNT(*) AS account_count FROM accounts')
          .getSingle();

      expect(rows.read<int>('account_count'), 1);
    } finally {
      await restoredDatabase.close();
    }
  });
}
