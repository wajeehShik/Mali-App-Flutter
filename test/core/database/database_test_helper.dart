import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mali/core/database/app_database.dart';
import 'package:mali/core/database/tables/accounts_table.dart';
import 'package:mali/core/database/tables/contacts_table.dart';

/// قاعدة جديدة فارغة في الذاكرة لكل اختبار.
AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

/// ينشئ حسابًا ويعيد معرّفه.
Future<String> addAccount(
  AppDatabase db, {
  String name = 'الصندوق',
  int opening = 0,
}) async {
  final id = 'acc-$name';
  await db.accountsDao.insertAccount(
    AccountsCompanion.insert(
      id: Value(id),
      name: name,
      type: AccountType.cash,
      openingBalance: Value(opening),
    ),
  );
  return id;
}

/// ينشئ منتجًا ويعيد معرّفه.
Future<String> addProduct(
  AppDatabase db, {
  String name = 'منتج',
  String? barcode,
}) async {
  final id = 'prod-$name';
  await db.productsDao.insertProduct(
    ProductsCompanion.insert(
      id: Value(id),
      name: name,
      barcode: Value(barcode),
    ),
  );
  return id;
}

/// ينشئ جهة اتصال ويعيد معرّفها.
Future<String> addContact(
  AppDatabase db, {
  String name = 'أحمد',
  ContactKind kind = ContactKind.customer,
}) async {
  final id = 'con-$name';
  await db.contactsDao.insertContact(
    ContactsCompanion.insert(id: Value(id), name: name, kind: kind),
  );
  return id;
}