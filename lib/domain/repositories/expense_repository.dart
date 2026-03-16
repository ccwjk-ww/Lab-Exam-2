import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/expense.dart';
import '../../data/datasources/remote/gemini_datasource.dart';

abstract class ExpenseRepository {
  // ── CRUD ──────────────────────────────────────────────────────────────────
  Future<Either<Failure, List<Expense>>> getAllExpenses();
  Future<Either<Failure, Expense>> getExpenseById(int id);
  Future<Either<Failure, int>> saveExpense(Expense expense);
  Future<Either<Failure, bool>> updateExpense(Expense expense);
  Future<Either<Failure, bool>> deleteExpense(int id);
  Future<Either<Failure, ExpenseSummary>> getSummary(DateTime from, DateTime to);

  // ── AI: เดิม ──────────────────────────────────────────────────────────────
  Future<Either<Failure, String>> categorizeWithAi(String ocrText);
  Future<Either<Failure, String>> summarizeWithAi(String ocrText);

  // ── AI: ใหม่ ──────────────────────────────────────────────────────────────

  /// ดึงข้อมูลจากใบเสร็จแบบ structured → ใช้ auto-fill ฟอร์ม Add Expense
  Future<Either<Failure, ExtractedReceiptData>> extractReceiptData(
      String ocrText);

  /// วิเคราะห์พฤติกรรมการใช้จ่ายโดยรวม + insights + คำแนะนำ
  Future<Either<Failure, SpendingAnalysis>> analyzeSpendingPattern(
      DateTime from, DateTime to);

  /// แนะนำงบประมาณรายเดือนที่เหมาะสมตามประวัติการใช้จ่าย
  Future<Either<Failure, BudgetAdvice>> generateBudgetAdvice(
      DateTime from, DateTime to);

  /// ตรวจจับรายจ่ายผิดปกติ: ซ้ำ, สูงเกิน, หมวดหมู่แปลก
  Future<Either<Failure, AnomalyResult>> detectAnomalies(
      DateTime from, DateTime to);
}