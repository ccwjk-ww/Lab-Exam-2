import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../data/datasources/remote/gemini_datasource.dart';
import '../../../domain/entities/expense.dart';
import '../../../domain/usecases/expense_usecases.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class ExpenseEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadExpensesEvent extends ExpenseEvent {}

class SaveExpenseEvent extends ExpenseEvent {
  final Expense expense;
  SaveExpenseEvent(this.expense);
  @override List<Object?> get props => [expense];
}

class UpdateExpenseEvent extends ExpenseEvent {
  final Expense expense;
  UpdateExpenseEvent(this.expense);
  @override List<Object?> get props => [expense];
}

class DeleteExpenseEvent extends ExpenseEvent {
  final int id;
  DeleteExpenseEvent(this.id);
  @override List<Object?> get props => [id];
}

class LoadSummaryEvent extends ExpenseEvent {
  final DateTime from;
  final DateTime to;
  LoadSummaryEvent({required this.from, required this.to});
  @override List<Object?> get props => [from, to];
}

// AI เดิม
class CategorizeWithAiEvent extends ExpenseEvent {
  final String ocrText;
  CategorizeWithAiEvent(this.ocrText);
  @override List<Object?> get props => [ocrText];
}

class SummarizeWithAiEvent extends ExpenseEvent {
  final String ocrText;
  SummarizeWithAiEvent(this.ocrText);
  @override List<Object?> get props => [ocrText];
}

// AI ใหม่
class ExtractReceiptDataEvent extends ExpenseEvent {
  final String ocrText;
  ExtractReceiptDataEvent(this.ocrText);
  @override List<Object?> get props => [ocrText];
}

class AnalyzeSpendingEvent extends ExpenseEvent {
  final DateTime from;
  final DateTime to;
  AnalyzeSpendingEvent({required this.from, required this.to});
  @override List<Object?> get props => [from, to];
}

class GenerateBudgetAdviceEvent extends ExpenseEvent {
  final DateTime from;
  final DateTime to;
  GenerateBudgetAdviceEvent({required this.from, required this.to});
  @override List<Object?> get props => [from, to];
}

class DetectAnomaliesEvent extends ExpenseEvent {
  final DateTime from;
  final DateTime to;
  DetectAnomaliesEvent({required this.from, required this.to});
  @override List<Object?> get props => [from, to];
}

// ─── Unified State ────────────────────────────────────────────────────────────

class ExpenseState extends Equatable {
  final List<Expense> expenses;
  final ExpenseSummary? summary;
  final bool isLoading;
  final bool isSummaryLoading;
  final String? errorMessage;
  final int? lastSavedId;
  final bool justDeleted;

  // AI เดิม
  final String? aiCategory;
  final String? aiSummary;
  final bool isAiLoading;

  // AI ใหม่
  final ExtractedReceiptData? extractedReceipt;
  final SpendingAnalysis? spendingAnalysis;
  final BudgetAdvice? budgetAdvice;
  final AnomalyResult? anomalyResult;
  final bool isAnalysisLoading;

  const ExpenseState({
    this.expenses = const [],
    this.summary,
    this.isLoading = false,
    this.isSummaryLoading = false,
    this.errorMessage,
    this.lastSavedId,
    this.justDeleted = false,
    this.aiCategory,
    this.aiSummary,
    this.isAiLoading = false,
    this.extractedReceipt,
    this.spendingAnalysis,
    this.budgetAdvice,
    this.anomalyResult,
    this.isAnalysisLoading = false,
  });

  ExpenseState copyWith({
    List<Expense>? expenses,
    ExpenseSummary? summary,
    bool? isLoading,
    bool? isSummaryLoading,
    String? errorMessage,
    int? lastSavedId,
    bool? justDeleted,
    String? aiCategory,
    String? aiSummary,
    bool? isAiLoading,
    ExtractedReceiptData? extractedReceipt,
    SpendingAnalysis? spendingAnalysis,
    BudgetAdvice? budgetAdvice,
    AnomalyResult? anomalyResult,
    bool? isAnalysisLoading,
    bool clearError = false,
    bool clearSaved = false,
    bool clearDeleted = false,
    bool clearAi = false,
    bool clearExtracted = false,
  }) {
    return ExpenseState(
      expenses: expenses ?? this.expenses,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastSavedId: clearSaved ? null : (lastSavedId ?? this.lastSavedId),
      justDeleted: clearDeleted ? false : (justDeleted ?? this.justDeleted),
      aiCategory: clearAi ? null : (aiCategory ?? this.aiCategory),
      aiSummary: clearAi ? null : (aiSummary ?? this.aiSummary),
      isAiLoading: isAiLoading ?? this.isAiLoading,
      extractedReceipt: clearExtracted ? null : (extractedReceipt ?? this.extractedReceipt),
      spendingAnalysis: spendingAnalysis ?? this.spendingAnalysis,
      budgetAdvice: budgetAdvice ?? this.budgetAdvice,
      anomalyResult: anomalyResult ?? this.anomalyResult,
      isAnalysisLoading: isAnalysisLoading ?? this.isAnalysisLoading,
    );
  }

  @override
  List<Object?> get props => [
    expenses, summary, isLoading, isSummaryLoading,
    errorMessage, lastSavedId, justDeleted,
    aiCategory, aiSummary, isAiLoading,
    extractedReceipt, spendingAnalysis, budgetAdvice,
    anomalyResult, isAnalysisLoading,
  ];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final GetAllExpensesUseCase getAllExpenses;
  final SaveExpenseUseCase saveExpense;
  final UpdateExpenseUseCase updateExpense;
  final DeleteExpenseUseCase deleteExpense;
  final GetExpenseSummaryUseCase getSummary;
  final CategorizeWithAiUseCase categorizeWithAi;
  final SummarizeWithAiUseCase summarizeWithAi;
  final ExtractReceiptDataUseCase extractReceiptData;
  final AnalyzeSpendingPatternUseCase analyzeSpending;
  final GenerateBudgetAdviceUseCase generateBudget;
  final DetectAnomaliesUseCase detectAnomalies;

  ExpenseBloc({
    required this.getAllExpenses,
    required this.saveExpense,
    required this.updateExpense,
    required this.deleteExpense,
    required this.getSummary,
    required this.categorizeWithAi,
    required this.summarizeWithAi,
    required this.extractReceiptData,
    required this.analyzeSpending,
    required this.generateBudget,
    required this.detectAnomalies,
  }) : super(const ExpenseState()) {
    on<LoadExpensesEvent>(_onLoad);
    on<SaveExpenseEvent>(_onSave);
    on<UpdateExpenseEvent>(_onUpdate);
    on<DeleteExpenseEvent>(_onDelete);
    on<LoadSummaryEvent>(_onLoadSummary);
    on<CategorizeWithAiEvent>(_onCategorize);
    on<SummarizeWithAiEvent>(_onSummarize);
    on<ExtractReceiptDataEvent>(_onExtractReceipt);
    on<AnalyzeSpendingEvent>(_onAnalyzeSpending);
    on<GenerateBudgetAdviceEvent>(_onGenerateBudget);
    on<DetectAnomaliesEvent>(_onDetectAnomalies);
  }

  Future<void> _onLoad(LoadExpensesEvent e, Emitter<ExpenseState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    final r = await getAllExpenses();
    r.fold(
          (f) => emit(state.copyWith(isLoading: false, errorMessage: f.message)),
          (list) => emit(state.copyWith(isLoading: false, expenses: list)),
    );
  }

  Future<void> _onSave(SaveExpenseEvent e, Emitter<ExpenseState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSaved: true));
    final r = await saveExpense(e.expense);
    r.fold(
          (f) => emit(state.copyWith(isLoading: false, errorMessage: f.message)),
          (id) => emit(state.copyWith(isLoading: false, lastSavedId: id)),
    );
  }

  Future<void> _onUpdate(UpdateExpenseEvent e, Emitter<ExpenseState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSaved: true));
    final r = await updateExpense(e.expense);
    r.fold(
          (f) => emit(state.copyWith(isLoading: false, errorMessage: f.message)),
          (_) => emit(state.copyWith(isLoading: false, lastSavedId: e.expense.id)),
    );
  }

  Future<void> _onDelete(DeleteExpenseEvent e, Emitter<ExpenseState> emit) async {
    emit(state.copyWith(clearDeleted: true, clearError: true));
    final r = await deleteExpense(e.id);
    r.fold(
          (f) => emit(state.copyWith(errorMessage: f.message)),
          (_) {
        final updated = state.expenses.where((exp) => exp.id != e.id).toList();
        emit(state.copyWith(expenses: updated, justDeleted: true));
      },
    );
  }

  Future<void> _onLoadSummary(LoadSummaryEvent e, Emitter<ExpenseState> emit) async {
    emit(state.copyWith(isSummaryLoading: true, clearError: true));
    final r = await getSummary(e.from, e.to);
    r.fold(
          (f) => emit(state.copyWith(isSummaryLoading: false, errorMessage: f.message)),
          (s) => emit(state.copyWith(isSummaryLoading: false, summary: s)),
    );
  }

  Future<void> _onCategorize(CategorizeWithAiEvent e, Emitter<ExpenseState> emit) async {
    emit(state.copyWith(isAiLoading: true, clearError: true, clearAi: true));
    final r = await categorizeWithAi(e.ocrText);
    r.fold(
          (f) => emit(state.copyWith(isAiLoading: false, errorMessage: f.message)),
          (cat) => emit(state.copyWith(isAiLoading: false, aiCategory: cat)),
    );
  }

  Future<void> _onSummarize(SummarizeWithAiEvent e, Emitter<ExpenseState> emit) async {
    emit(state.copyWith(isAiLoading: true, clearError: true));
    final r = await summarizeWithAi(e.ocrText);
    r.fold(
          (f) => emit(state.copyWith(isAiLoading: false, errorMessage: f.message)),
          (s) => emit(state.copyWith(isAiLoading: false, aiSummary: s)),
    );
  }

  Future<void> _onExtractReceipt(ExtractReceiptDataEvent e, Emitter<ExpenseState> emit) async {
    emit(state.copyWith(isAiLoading: true, clearError: true, clearExtracted: true));
    final r = await extractReceiptData(e.ocrText);
    r.fold(
          (f) => emit(state.copyWith(isAiLoading: false, errorMessage: f.message)),
          (data) => emit(state.copyWith(isAiLoading: false, extractedReceipt: data)),
    );
  }

  Future<void> _onAnalyzeSpending(AnalyzeSpendingEvent e, Emitter<ExpenseState> emit) async {
    emit(state.copyWith(isAnalysisLoading: true, clearError: true));
    final r = await analyzeSpending(e.from, e.to);
    r.fold(
          (f) => emit(state.copyWith(isAnalysisLoading: false, errorMessage: f.message)),
          (analysis) => emit(state.copyWith(isAnalysisLoading: false, spendingAnalysis: analysis)),
    );
  }

  Future<void> _onGenerateBudget(GenerateBudgetAdviceEvent e, Emitter<ExpenseState> emit) async {
    emit(state.copyWith(isAnalysisLoading: true, clearError: true));
    final r = await generateBudget(e.from, e.to);
    r.fold(
          (f) => emit(state.copyWith(isAnalysisLoading: false, errorMessage: f.message)),
          (advice) => emit(state.copyWith(isAnalysisLoading: false, budgetAdvice: advice)),
    );
  }

  Future<void> _onDetectAnomalies(DetectAnomaliesEvent e, Emitter<ExpenseState> emit) async {
    emit(state.copyWith(isAnalysisLoading: true, clearError: true));
    final r = await detectAnomalies(e.from, e.to);
    r.fold(
          (f) => emit(state.copyWith(isAnalysisLoading: false, errorMessage: f.message)),
          (result) => emit(state.copyWith(isAnalysisLoading: false, anomalyResult: result)),
    );
  }
}