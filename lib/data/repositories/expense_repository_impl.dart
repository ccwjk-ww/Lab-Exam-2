import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/expense.dart' as domain;
import '../../domain/repositories/expense_repository.dart';
import '../datasources/local/app_database.dart';
import '../datasources/local/hive_cache_datasource.dart';
import '../datasources/local/local_expense_datasource.dart';
import '../datasources/remote/gemini_datasource.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final LocalExpenseDataSource _localDs;
  final RemoteAiDataSource _remoteDs;
  final CacheDataSource _cacheDs;

  ExpenseRepositoryImpl(this._localDs, this._remoteDs, this._cacheDs);

  domain.Expense _toEntity(ExpenseRecord row) => domain.Expense(
    id: row.id,
    title: row.title,
    storeName: row.storeName,
    amount: row.amount,
    category: row.category,
    date: row.date,
    imagePath: row.imagePath,
    rawOcrText: row.rawOcrText,
    aiSummary: row.aiSummary,
  );

  ExpenseRecordsCompanion _toCompanion(domain.Expense e) =>
      ExpenseRecordsCompanion(
        id: e.id != null ? Value(e.id!) : const Value.absent(),
        title: Value(e.title),
        storeName: Value(e.storeName),
        amount: Value(e.amount),
        category: Value(e.category),
        date: Value(e.date),
        imagePath: Value(e.imagePath),
        rawOcrText: Value(e.rawOcrText),
        aiSummary: Value(e.aiSummary),
      );

  Map<String, dynamic> _toAiMap(domain.Expense e) => {
    'date': e.date.toIso8601String().substring(0, 10),
    'title': e.title,
    'store_name': e.storeName,
    'category': e.category,
    'amount': e.amount,
  };

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<domain.Expense>>> getAllExpenses() async {
    try {
      final rows = await _localDs.getAllExpenses();
      return Right(rows.map(_toEntity).toList());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, domain.Expense>> getExpenseById(int id) async {
    try {
      final row = await _localDs.getExpenseById(id);
      if (row == null) return const Left(DatabaseFailure('Not found'));
      return Right(_toEntity(row));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> saveExpense(domain.Expense expense) async {
    try {
      final id = await _localDs.saveExpense(_toCompanion(expense));
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> updateExpense(domain.Expense expense) async {
    try {
      final result = await _localDs.updateExpense(_toCompanion(expense));
      return Right(result);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteExpense(int id) async {
    try {
      await _localDs.deleteExpense(id);
      return const Right(true);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, domain.ExpenseSummary>> getSummary(
      DateTime from, DateTime to) async {
    try {
      final rows = await _localDs.getExpensesByDateRange(from, to);
      final expenses = rows.map(_toEntity).toList();
      final Map<String, double> categoryTotals = {};
      for (final e in expenses) {
        categoryTotals[e.category] =
            (categoryTotals[e.category] ?? 0) + e.amount;
      }
      final total = expenses.fold<double>(0.0, (s, e) => s + e.amount);
      return Right(domain.ExpenseSummary(
        categoryTotals: categoryTotals,
        totalAmount: total,
        totalCount: expenses.length,
        periodStart: from,
        periodEnd: to,
      ));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  // ─── AI: เดิม ─────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, String>> categorizeWithAi(String ocrText) async {
    final cacheKey = 'cat_${ocrText.hashCode}';
    final cached = await _cacheDs.getCachedAiResult(cacheKey);
    if (cached != null) return Right(cached);
    final result = await _remoteDs.categorizeExpense(ocrText);
    result.fold((_) {}, (v) => _cacheDs.cacheAiResult(cacheKey, v));
    return result;
  }

  @override
  Future<Either<Failure, String>> summarizeWithAi(String ocrText) async {
    final cacheKey = 'sum_${ocrText.hashCode}';
    final cached = await _cacheDs.getCachedAiResult(cacheKey);
    if (cached != null) return Right(cached);
    final result = await _remoteDs.summarizeExpense(ocrText);
    result.fold((_) {}, (v) => _cacheDs.cacheAiResult(cacheKey, v));
    return result;
  }

  // ─── AI: ใหม่ ─────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, ExtractedReceiptData>> extractReceiptData(
      String ocrText) async {
    return _remoteDs.extractReceiptData(ocrText);
  }

  @override
  Future<Either<Failure, SpendingAnalysis>> analyzeSpendingPattern(
      DateTime from, DateTime to) async {
    try {
      final rows = await _localDs.getExpensesByDateRange(from, to);
      if (rows.isEmpty) {
        return const Left(DatabaseFailure('ไม่มีข้อมูลรายจ่ายในช่วงเวลานี้'));
      }
      final expensesJson = rows.map(_toEntity).map(_toAiMap).toList();
      return _remoteDs.analyzeSpendingPattern(expensesJson);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BudgetAdvice>> generateBudgetAdvice(
      DateTime from, DateTime to) async {
    try {
      final rows = await _localDs.getExpensesByDateRange(from, to);
      if (rows.isEmpty) {
        return const Left(DatabaseFailure('ไม่มีข้อมูลรายจ่ายในช่วงเวลานี้'));
      }
      final expenses = rows.map(_toEntity).toList();
      final expensesJson = expenses.map(_toAiMap).toList();
      final total = expenses.fold<double>(0.0, (s, e) => s + e.amount);
      return _remoteDs.generateBudgetAdvice(expensesJson, total);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AnomalyResult>> detectAnomalies(
      DateTime from, DateTime to) async {
    try {
      final rows = await _localDs.getExpensesByDateRange(from, to);
      if (rows.isEmpty) {
        return Right(AnomalyResult(
            anomalies: const [], summary: 'ไม่มีข้อมูลให้ตรวจสอบ'));
      }
      final expensesJson = rows.map(_toEntity).map(_toAiMap).toList();
      return _remoteDs.detectAnomalies(expensesJson);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}