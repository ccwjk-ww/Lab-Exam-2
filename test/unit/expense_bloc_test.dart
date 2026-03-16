import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_expense_tracker/core/error/failures.dart';
import 'package:ai_expense_tracker/data/datasources/remote/gemini_datasource.dart';
import 'package:ai_expense_tracker/domain/entities/expense.dart';
import 'package:ai_expense_tracker/domain/usecases/expense_usecases.dart';
import 'package:ai_expense_tracker/presentation/blocs/expense/expense_bloc.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────
class MockGetAllExpenses extends Mock implements GetAllExpensesUseCase {}
class MockSaveExpense extends Mock implements SaveExpenseUseCase {}
class MockUpdateExpense extends Mock implements UpdateExpenseUseCase {}
class MockDeleteExpense extends Mock implements DeleteExpenseUseCase {}
class MockGetSummary extends Mock implements GetExpenseSummaryUseCase {}
class MockCategorizeAi extends Mock implements CategorizeWithAiUseCase {}
class MockSummarizeAi extends Mock implements SummarizeWithAiUseCase {}
class MockExtractReceipt extends Mock implements ExtractReceiptDataUseCase {}
class MockAnalyzeSpending extends Mock implements AnalyzeSpendingPatternUseCase {}
class MockGenerateBudget extends Mock implements GenerateBudgetAdviceUseCase {}
class MockDetectAnomalies extends Mock implements DetectAnomaliesUseCase {}

// Fake สำหรับ registerFallbackValue
class FakeExpense extends Fake implements Expense {}

// ─── Helper ───────────────────────────────────────────────────────────────────
ExpenseBloc _buildBloc({
  MockGetAllExpenses? getAll,
  MockSaveExpense? save,
  MockUpdateExpense? update,
  MockDeleteExpense? delete,
  MockGetSummary? getSummary,
  MockCategorizeAi? categorize,
  MockSummarizeAi? summarize,
  MockExtractReceipt? extract,
  MockAnalyzeSpending? analyze,
  MockGenerateBudget? budget,
  MockDetectAnomalies? anomalies,
}) {
  return ExpenseBloc(
    getAllExpenses: getAll ?? MockGetAllExpenses(),
    saveExpense: save ?? MockSaveExpense(),
    updateExpense: update ?? MockUpdateExpense(),
    deleteExpense: delete ?? MockDeleteExpense(),
    getSummary: getSummary ?? MockGetSummary(),
    categorizeWithAi: categorize ?? MockCategorizeAi(),
    summarizeWithAi: summarize ?? MockSummarizeAi(),
    extractReceiptData: extract ?? MockExtractReceipt(),
    analyzeSpending: analyze ?? MockAnalyzeSpending(),
    generateBudget: budget ?? MockGenerateBudget(),
    detectAnomalies: anomalies ?? MockDetectAnomalies(),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeExpense());
  });

  // ─── Test data ──────────────────────────────────────────────────────────────
  final tExpense = Expense(
    id: 1,
    title: 'ข้าวผัด',
    storeName: 'ร้านอาหาร A',
    amount: 60.0,
    category: 'อาหาร',
    date: DateTime(2024, 1, 15),
  );

  final tExpense2 = Expense(
    id: 2,
    title: 'ชาเย็น',
    storeName: 'ร้านชา',
    amount: 30.0,
    category: 'อาหาร',
    date: DateTime(2024, 1, 15),
  );

  // ─── Initial State ──────────────────────────────────────────────────────────
  group('Initial state', () {
    test('initial state is ExpenseState with all defaults', () {
      final bloc = _buildBloc();
      expect(bloc.state, const ExpenseState());
      expect(bloc.state.isLoading, false);
      expect(bloc.state.expenses, isEmpty);
      expect(bloc.state.errorMessage, isNull);
      bloc.close();
    });
  });

  // ─── LoadExpensesEvent ──────────────────────────────────────────────────────
  group('LoadExpensesEvent', () {
    blocTest<ExpenseBloc, ExpenseState>(
      'emits loading=true then expenses when successful',
      build: () {
        final mock = MockGetAllExpenses();
        when(() => mock()).thenAnswer((_) async => Right([tExpense]));
        return _buildBloc(getAll: mock);
      },
      act: (b) => b.add(LoadExpensesEvent()),
      expect: () => [
        isA<ExpenseState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ExpenseState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.expenses, 'expenses', [tExpense]),
      ],
    );

    blocTest<ExpenseBloc, ExpenseState>(
      'emits errorMessage when database failure',
      build: () {
        final mock = MockGetAllExpenses();
        when(() => mock()).thenAnswer(
                (_) async => const Left(DatabaseFailure('DB error')));
        return _buildBloc(getAll: mock);
      },
      act: (b) => b.add(LoadExpensesEvent()),
      expect: () => [
        isA<ExpenseState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ExpenseState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.errorMessage, 'errorMessage', 'DB error'),
      ],
    );

    blocTest<ExpenseBloc, ExpenseState>(
      'emits empty list when no expenses',
      build: () {
        final mock = MockGetAllExpenses();
        when(() => mock()).thenAnswer((_) async => const Right([]));
        return _buildBloc(getAll: mock);
      },
      act: (b) => b.add(LoadExpensesEvent()),
      expect: () => [
        isA<ExpenseState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ExpenseState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.expenses, 'expenses', isEmpty),
      ],
    );
  });

  // ─── SaveExpenseEvent ───────────────────────────────────────────────────────
  group('SaveExpenseEvent', () {
    blocTest<ExpenseBloc, ExpenseState>(
      'emits lastSavedId=1 when save succeeds',
      build: () {
        final mock = MockSaveExpense();
        when(() => mock(tExpense)).thenAnswer((_) async => const Right(1));
        return _buildBloc(save: mock);
      },
      act: (b) => b.add(SaveExpenseEvent(tExpense)),
      expect: () => [
        isA<ExpenseState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ExpenseState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.lastSavedId, 'lastSavedId', 1),
      ],
    );

    blocTest<ExpenseBloc, ExpenseState>(
      'emits errorMessage when save fails',
      build: () {
        final mock = MockSaveExpense();
        when(() => mock(tExpense)).thenAnswer(
                (_) async => const Left(DatabaseFailure('Save failed')));
        return _buildBloc(save: mock);
      },
      act: (b) => b.add(SaveExpenseEvent(tExpense)),
      expect: () => [
        isA<ExpenseState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ExpenseState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.errorMessage, 'errorMessage', 'Save failed'),
      ],
    );
  });

  // ─── UpdateExpenseEvent ─────────────────────────────────────────────────────
  group('UpdateExpenseEvent', () {
    blocTest<ExpenseBloc, ExpenseState>(
      'emits lastSavedId = expense.id when update succeeds',
      build: () {
        final mock = MockUpdateExpense();
        when(() => mock(tExpense)).thenAnswer((_) async => const Right(true));
        return _buildBloc(update: mock);
      },
      act: (b) => b.add(UpdateExpenseEvent(tExpense)),
      expect: () => [
        isA<ExpenseState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ExpenseState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.lastSavedId, 'lastSavedId', tExpense.id),
      ],
    );
  });

  // ─── DeleteExpenseEvent ─────────────────────────────────────────────────────
  group('DeleteExpenseEvent', () {
    blocTest<ExpenseBloc, ExpenseState>(
      'removes expense from list on success',
      build: () {
        final mockDelete = MockDeleteExpense();
        final mockGetAll = MockGetAllExpenses();
        when(() => mockGetAll())
            .thenAnswer((_) async => Right([tExpense, tExpense2]));
        when(() => mockDelete(1)).thenAnswer((_) async => const Right(true));

        final bloc = _buildBloc(getAll: mockGetAll, delete: mockDelete);
        bloc.add(LoadExpensesEvent());
        return bloc;
      },
      act: (b) async {
        await Future.delayed(const Duration(milliseconds: 50));
        b.add(DeleteExpenseEvent(1));
      },
      skip: 2, // ข้าม 2 states จาก LoadExpensesEvent
      expect: () => [
        isA<ExpenseState>()
            .having((s) => s.justDeleted, 'justDeleted', true)
            .having(
              (s) => s.expenses.map((e) => e.id).toList(),
          'remaining ids',
          [2],
        ),
      ],
    );

    blocTest<ExpenseBloc, ExpenseState>(
      'emits errorMessage when delete fails',
      build: () {
        final mock = MockDeleteExpense();
        when(() => mock(1)).thenAnswer(
                (_) async => const Left(DatabaseFailure('Delete failed')));
        return _buildBloc(delete: mock);
      },
      act: (b) => b.add(DeleteExpenseEvent(1)),
      // ✅ bloc emit 2 states:
      //   1. copyWith(clearDeleted: true, clearError: true) → state ไม่เปลี่ยน props
      //   2. copyWith(errorMessage: 'Delete failed')
      // เราต้อง expect ทั้ง 2 states
      expect: () => [
        isA<ExpenseState>().having((s) => s.errorMessage, 'no error yet', isNull),
        isA<ExpenseState>()
            .having((s) => s.errorMessage, 'errorMessage', 'Delete failed'),
      ],
    );
  });

  // ─── LoadSummaryEvent ───────────────────────────────────────────────────────
  group('LoadSummaryEvent', () {
    final from = DateTime(2024, 1, 1);
    final to = DateTime(2024, 1, 31);
    final tSummary = ExpenseSummary(
      categoryTotals: {'อาหาร': 200.0},
      totalAmount: 200.0,
      totalCount: 2,
      periodStart: from,
      periodEnd: to,
    );

    blocTest<ExpenseBloc, ExpenseState>(
      'emits summary when successful',
      build: () {
        final mock = MockGetSummary();
        when(() => mock(from, to)).thenAnswer((_) async => Right(tSummary));
        return _buildBloc(getSummary: mock);
      },
      act: (b) => b.add(LoadSummaryEvent(from: from, to: to)),
      expect: () => [
        isA<ExpenseState>()
            .having((s) => s.isSummaryLoading, 'isSummaryLoading', true),
        isA<ExpenseState>()
            .having((s) => s.isSummaryLoading, 'isSummaryLoading', false)
            .having((s) => s.summary, 'summary', tSummary),
      ],
    );
  });

  // ─── CategorizeWithAiEvent ──────────────────────────────────────────────────
  group('CategorizeWithAiEvent', () {
    blocTest<ExpenseBloc, ExpenseState>(
      'emits aiCategory when AI succeeds',
      build: () {
        final mock = MockCategorizeAi();
        when(() => mock('ข้าวมันไก่ 55 บาท'))
            .thenAnswer((_) async => const Right('อาหาร'));
        return _buildBloc(categorize: mock);
      },
      act: (b) => b.add(CategorizeWithAiEvent('ข้าวมันไก่ 55 บาท')),
      expect: () => [
        isA<ExpenseState>().having((s) => s.isAiLoading, 'isAiLoading', true),
        isA<ExpenseState>()
            .having((s) => s.isAiLoading, 'isAiLoading', false)
            .having((s) => s.aiCategory, 'aiCategory', 'อาหาร'),
      ],
    );

    blocTest<ExpenseBloc, ExpenseState>(
      'emits errorMessage when AI fails',
      build: () {
        final mock = MockCategorizeAi();
        when(() => mock(any())).thenAnswer(
                (_) async => const Left(ServerFailure('AI error')));
        return _buildBloc(categorize: mock);
      },
      act: (b) => b.add(CategorizeWithAiEvent('test')),
      expect: () => [
        isA<ExpenseState>().having((s) => s.isAiLoading, 'isAiLoading', true),
        isA<ExpenseState>()
            .having((s) => s.isAiLoading, 'isAiLoading', false)
            .having((s) => s.errorMessage, 'errorMessage', 'AI error'),
      ],
    );
  });

  // ─── SummarizeWithAiEvent ───────────────────────────────────────────────────
  group('SummarizeWithAiEvent', () {
    blocTest<ExpenseBloc, ExpenseState>(
      'emits aiSummary when successful',
      build: () {
        final mock = MockSummarizeAi();
        when(() => mock('receipt text'))
            .thenAnswer((_) async => const Right('ร้าน A ยอดรวม 55 บาท'));
        return _buildBloc(summarize: mock);
      },
      act: (b) => b.add(SummarizeWithAiEvent('receipt text')),
      expect: () => [
        isA<ExpenseState>().having((s) => s.isAiLoading, 'isAiLoading', true),
        isA<ExpenseState>()
            .having((s) => s.isAiLoading, 'isAiLoading', false)
            .having((s) => s.aiSummary, 'aiSummary', 'ร้าน A ยอดรวม 55 บาท'),
      ],
    );
  });

  // ─── ExtractReceiptDataEvent ────────────────────────────────────────────────
  group('ExtractReceiptDataEvent', () {
    final tExtracted = ExtractedReceiptData(
      storeName: 'ร้านข้าวมันไก่',
      totalAmount: 55.0,
      suggestedTitle: 'ข้าวมันไก่',
      suggestedCategory: 'อาหาร',
      items: [],
    );

    blocTest<ExpenseBloc, ExpenseState>(
      'emits extractedReceipt when successful',
      build: () {
        final mock = MockExtractReceipt();
        when(() => mock('ocr text'))
            .thenAnswer((_) async => Right(tExtracted));
        return _buildBloc(extract: mock);
      },
      act: (b) => b.add(ExtractReceiptDataEvent('ocr text')),
      expect: () => [
        isA<ExpenseState>().having((s) => s.isAiLoading, 'isAiLoading', true),
        isA<ExpenseState>()
            .having((s) => s.isAiLoading, 'isAiLoading', false)
            .having((s) => s.extractedReceipt, 'extractedReceipt', tExtracted),
      ],
    );
  });

  // ─── State isolation ────────────────────────────────────────────────────────
  group('State isolation', () {
    blocTest<ExpenseBloc, ExpenseState>(
      'loading expenses does not clear summary',
      build: () {
        final mockGetAll = MockGetAllExpenses();
        final mockSummary = MockGetSummary();
        final from = DateTime(2024, 1, 1);
        final to = DateTime(2024, 1, 31);
        final tSummary = ExpenseSummary(
          categoryTotals: {'อาหาร': 100.0},
          totalAmount: 100.0,
          totalCount: 1,
          periodStart: from,
          periodEnd: to,
        );
        when(() => mockGetAll()).thenAnswer((_) async => Right([tExpense]));
        when(() => mockSummary(from, to))
            .thenAnswer((_) async => Right(tSummary));

        final bloc = _buildBloc(getAll: mockGetAll, getSummary: mockSummary);
        bloc.add(LoadSummaryEvent(from: from, to: to));
        return bloc;
      },
      act: (b) async {
        await Future.delayed(const Duration(milliseconds: 50));
        b.add(LoadExpensesEvent());
      },
      skip: 2,
      expect: () => [
        isA<ExpenseState>()
            .having((s) => s.isLoading, 'isLoading', true)
            .having((s) => s.summary, 'summary still present', isNotNull),
        isA<ExpenseState>()
            .having((s) => s.expenses, 'expenses', [tExpense])
            .having((s) => s.summary, 'summary still present', isNotNull),
      ],
    );
  });
}