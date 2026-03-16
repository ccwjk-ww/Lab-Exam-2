import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ─── Table Definition ─────────────────────────────────────────────────────────
// ตั้งชื่อ Table ว่า ExpenseRecords เพื่อไม่ให้ชนกับ Domain Expense entity
class ExpenseRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get storeName => text().withLength(min: 1, max: 200)();
  RealColumn get amount => real()();
  TextColumn get category => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get rawOcrText => text().nullable()();
  TextColumn get aiSummary => text().nullable()();
}

// ─── Database ─────────────────────────────────────────────────────────────────
@DriftDatabase(tables: [ExpenseRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<List<ExpenseRecord>> getAllExpenses() =>
      (select(expenseRecords)
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<ExpenseRecord?> getExpenseById(int id) =>
      (select(expenseRecords)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertExpense(ExpenseRecordsCompanion entry) =>
      into(expenseRecords).insert(entry);

  Future<bool> updateExpenseById(ExpenseRecordsCompanion entry) =>
      update(expenseRecords).replace(entry);

  Future<int> deleteExpenseById(int id) =>
      (delete(expenseRecords)..where((t) => t.id.equals(id))).go();

  Future<List<ExpenseRecord>> getExpensesByCategory(String category) =>
      (select(expenseRecords)..where((t) => t.category.equals(category))).get();

  Future<List<ExpenseRecord>> getExpensesByDateRange(DateTime from, DateTime to) =>
      (select(expenseRecords)
            ..where((t) => t.date.isBetweenValues(from, to))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'expenses.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
