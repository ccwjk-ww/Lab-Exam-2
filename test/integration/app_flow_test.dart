import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_expense_tracker/domain/entities/expense.dart';
import 'package:ai_expense_tracker/domain/usecases/expense_usecases.dart';
import 'package:ai_expense_tracker/presentation/blocs/expense/expense_bloc.dart';
import 'package:ai_expense_tracker/presentation/pages/add_edit_expense/add_edit_expense_page.dart';

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

class FakeExpense extends Fake implements Expense {}

ExpenseBloc buildBloc({MockSaveExpense? save}) {
  return ExpenseBloc(
    getAllExpenses: MockGetAllExpenses(),
    saveExpense: save ?? MockSaveExpense(),
    updateExpense: MockUpdateExpense(),
    deleteExpense: MockDeleteExpense(),
    getSummary: MockGetSummary(),
    categorizeWithAi: MockCategorizeAi(),
    summarizeWithAi: MockSummarizeAi(),
    extractReceiptData: MockExtractReceipt(),
    analyzeSpending: MockAnalyzeSpending(),
    generateBudget: MockGenerateBudget(),
    detectAnomalies: MockDetectAnomalies(),
  );
}

Future<void> tapSave(WidgetTester tester) async {
  final btn = find.text('บันทึก');
  await tester.ensureVisible(btn);
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    registerFallbackValue(FakeExpense());
    await initializeDateFormatting('th', null);
  });

  testWidgets('Fill form and save', (tester) async {
    final mockSave = MockSaveExpense();

    when(() => mockSave(any()))
        .thenAnswer((_) async => const Right(1));

    final bloc = buildBloc(save: mockSave);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: const AddEditExpensePage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'ข้าวมันไก่');
    await tester.enterText(find.byType(TextFormField).at(1), 'ร้าน A');
    await tester.enterText(find.byType(TextFormField).at(2), '55');

    await tapSave(tester);

    verify(() => mockSave(any())).called(1);
  });
}