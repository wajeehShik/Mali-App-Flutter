import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/accounts_table.dart';
import 'tables/base_columns.dart';
import 'tables/categories_table.dart';
import 'tables/contacts_table.dart';
import 'tables/outbox_table.dart';
import 'tables/products_table.dart';
import 'tables/settings_table.dart';
import 'tables/transaction_items_table.dart';
import 'tables/transactions_table.dart';
import 'daos/accounts_dao.dart';
import 'daos/contacts_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/transactions_dao.dart';
import 'daos/products_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/settings_dao.dart';
part 'app_database.g.dart';

/// قاعدة بيانات التطبيق المحلية (SQLite عبر Drift).
@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Contacts,
    Products,
    Transactions,
    TransactionItems,
    Settings,
    Outbox,
  ],
  daos: [AccountsDao,CategoriesDao,ContactsDao,ProductsDao,TransactionsDao,SettingsDao,    OutboxDao,],
)
class AppDatabase extends _$AppDatabase {
  /// للاختبارات: مرّر `NativeDatabase.memory()`.
  AppDatabase(super.executor);

  /// قاعدة الجهاز الفعلية (ملف mali.sqlite في مجلد مستندات التطبيق).
  AppDatabase.forDevice() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        beforeOpen: (details) async {
          // SQLite لا يفرض المفاتيح الأجنبية إلا إذا فُعّلت في كل اتصال.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createIndexes() async {
    const statements = [
      'CREATE INDEX idx_tx_date ON transactions (date)',
      'CREATE INDEX idx_tx_account ON transactions (account_id)',
      'CREATE INDEX idx_tx_contact ON transactions (contact_id)',
      'CREATE INDEX idx_tx_type ON transactions (type)',
      'CREATE INDEX idx_items_tx ON transaction_items (transaction_id)',
      'CREATE INDEX idx_items_product ON transaction_items (product_id)',
      'CREATE INDEX idx_products_barcode ON products (barcode)',
      'CREATE INDEX idx_outbox_created ON outbox (created_at)',
    ];
    for (final sql in statements) {
      await customStatement(sql);
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'mali.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}