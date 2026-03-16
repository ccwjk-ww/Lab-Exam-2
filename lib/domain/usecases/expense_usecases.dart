import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/expense.dart';
import '../repositories/expense_repository.dart';
import '../../data/datasources/remote/gemini_datasource.dart';

// ─── CRUD Use Cases ───────────────────────────────────────────────────────────

class GetAllExpensesUseCase {
  final ExpenseRepository repository;
  GetAllExpensesUseCase(this.repository);
  Future<Either<Failure, List<Expense>>> call() => repository.getAllExpenses();
}

class SaveExpenseUseCase {
  final ExpenseRepository repository;
  SaveExpenseUseCase(this.repository);
  Future<Either<Failure, int>> call(Expense expense) =>
      repository.saveExpense(expense);
}

class UpdateExpenseUseCase {
  final ExpenseRepository repository;
  UpdateExpenseUseCase(this.repository);
  Future<Either<Failure, bool>> call(Expense expense) =>
      repository.updateExpense(expense);
}

class DeleteExpenseUseCase {
  final ExpenseRepository repository;
  DeleteExpenseUseCase(this.repository);
  Future<Either<Failure, bool>> call(int id) => repository.deleteExpense(id);
}

class GetExpenseSummaryUseCase {
  final ExpenseRepository repository;
  GetExpenseSummaryUseCase(this.repository);
  Future<Either<Failure, ExpenseSummary>> call(DateTime from, DateTime to) =>
      repository.getSummary(from, to);
}

// ─── AI Use Cases: เดิม ───────────────────────────────────────────────────────

class CategorizeWithAiUseCase {
  final ExpenseRepository repository;
  CategorizeWithAiUseCase(this.repository);
  Future<Either<Failure, String>> call(String ocrText) =>
      repository.categorizeWithAi(ocrText);
}

class SummarizeWithAiUseCase {
  final ExpenseRepository repository;
  SummarizeWithAiUseCase(this.repository);
  Future<Either<Failure, String>> call(String ocrText) =>
      repository.summarizeWithAi(ocrText);
}

// ─── AI Use Cases: ใหม่ ───────────────────────────────────────────────────────

/// ดึงข้อมูลจากใบเสร็จแบบ structured (ชื่อร้าน, ยอด, วันที่, รายการสินค้า)
/// ใช้สำหรับ auto-fill ฟอร์ม Add Expense
class ExtractReceiptDataUseCase {
  final ExpenseRepository repository;
  ExtractReceiptDataUseCase(this.repository);
  Future<Either<Failure, ExtractedReceiptData>> call(String ocrText) =>
      repository.extractReceiptData(ocrText);
}

/// วิเคราะห์พฤติกรรมการใช้จ่าย → insights + คำเตือน + คำแนะนำ
/// ใช้สำหรับหน้า AI Insights
class AnalyzeSpendingPatternUseCase {
  final ExpenseRepository repository;
  AnalyzeSpendingPatternUseCase(this.repository);
  Future<Either<Failure, SpendingAnalysis>> call(DateTime from, DateTime to) =>
      repository.analyzeSpendingPattern(from, to);
}

/// แนะนำงบประมาณรายเดือนและแต่ละหมวดหมู่
/// ใช้สำหรับหน้า Budget Planner
class GenerateBudgetAdviceUseCase {
  final ExpenseRepository repository;
  GenerateBudgetAdviceUseCase(this.repository);
  Future<Either<Failure, BudgetAdvice>> call(DateTime from, DateTime to) =>
      repository.generateBudgetAdvice(from, to);
}

/// ตรวจจับรายจ่ายผิดปกติ: ซ้ำ, สูงเกิน, หมวดหมู่แปลก
/// ใช้สำหรับ widget แจ้งเตือนบน Dashboard
class DetectAnomaliesUseCase {
  final ExpenseRepository repository;
  DetectAnomaliesUseCase(this.repository);
  Future<Either<Failure, AnomalyResult>> call(DateTime from, DateTime to) =>
      repository.detectAnomalies(from, to);
}