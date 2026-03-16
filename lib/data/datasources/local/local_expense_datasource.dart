
import 'app_database.dart';

abstract class LocalExpenseDataSource {
  Future<List<ExpenseRecord>> getAllExpenses();
  Future<ExpenseRecord?> getExpenseById(int id);
  Future<int> saveExpense(ExpenseRecordsCompanion entry);
  Future<bool> updateExpense(ExpenseRecordsCompanion entry);
  Future<int> deleteExpense(int id);
  Future<List<ExpenseRecord>> getExpensesByCategory(String category);
  Future<List<ExpenseRecord>> getExpensesByDateRange(DateTime from, DateTime to);
}

class LocalExpenseDataSourceImpl implements LocalExpenseDataSource {
  final AppDatabase db;

  LocalExpenseDataSourceImpl(this.db);

  @override
  Future<List<ExpenseRecord>> getAllExpenses() => db.getAllExpenses();

  @override
  Future<ExpenseRecord?> getExpenseById(int id) => db.getExpenseById(id);

  @override
  Future<int> saveExpense(ExpenseRecordsCompanion entry) => db.insertExpense(entry);

  @override
  Future<bool> updateExpense(ExpenseRecordsCompanion entry) => db.updateExpenseById(entry);

  @override
  Future<int> deleteExpense(int id) => db.deleteExpenseById(id);

  @override
  Future<List<ExpenseRecord>> getExpensesByCategory(String category) =>
      db.getExpensesByCategory(category);

  @override
  Future<List<ExpenseRecord>> getExpensesByDateRange(DateTime from, DateTime to) =>
      db.getExpensesByDateRange(from, to);
}
