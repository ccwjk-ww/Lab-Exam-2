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
import 'package:auto_route/auto_route.dart';

// ─── Mocks ─────────────────────────────────────────────────────
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

// ─── Helper ───────────────────────────────────────────────────
ExpenseBloc _buildBloc({MockSaveExpense? save}) => ExpenseBloc(
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

Widget _buildTestWidget(ExpenseBloc bloc, {Expense? expense}) {
  return MaterialApp(
    home: AutoRouter(
      builder: (context, child) {
        return BlocProvider.value(
          value: bloc,
          child: AddEditExpensePage(expense: expense),
        );
      },
    ),
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

  late ExpenseBloc bloc;

  setUp(() {
    bloc = _buildBloc();
  });

  tearDown(() => bloc.close());

  group('Form fields are present', () {
    testWidgets('Add mode shows all required fields and save button',
            (tester) async {
          await tester.pumpWidget(_buildTestWidget(bloc));
          await tester.pumpAndSettle();


          expect(find.text('ชื่อรายการ *'), findsOneWidget);
          expect(find.text('ชื่อร้าน *'), findsOneWidget);
          expect(find.text('จำนวนเงิน (บาท) *'), findsOneWidget);
          expect(find.text('หมวดหมู่'), findsOneWidget);
          expect(find.text('วันที่'), findsOneWidget);
          expect(find.text('บันทึก'), findsOneWidget);
        });

    testWidgets('Edit mode shows update button', (tester) async {
      final existing = Expense(
        id: 1,
        title: 'ข้าวมันไก่',
        storeName: 'ร้านA',
        amount: 55.0,
        category: 'อาหาร',
        date: DateTime(2024, 1, 15),
      );

      await tester.pumpWidget(_buildTestWidget(bloc, expense: existing));
      await tester.pumpAndSettle();

      expect(find.text('อัปเดต'), findsOneWidget);
      expect(find.text('บันทึก'), findsNothing);
    });


  });

  group('Form validation', () {
    testWidgets('title empty', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pumpAndSettle();

      await tapSave(tester);

      expect(find.text('กรุณากรอกชื่อรายการ'), findsOneWidget);
    });

    testWidgets('amount 0', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'ชื่อรายการ *'), 'ทดสอบ');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'ชื่อร้าน *'), 'ร้านA');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'จำนวนเงิน (บาท) *'), '0');

      await tapSave(tester);

      expect(find.text('จำนวนเงินต้องมากกว่า 0'), findsOneWidget);
    });


  });

  group('Form submit', () {
    testWidgets('valid form dispatches SaveExpenseEvent', (tester) async {
      final mockSave = MockSaveExpense();


      when(() => mockSave(any())).thenAnswer((_) async => const Right(1));

      final testBloc = _buildBloc(save: mockSave);

      await tester.pumpWidget(_buildTestWidget(testBloc));
      await tester.pumpAndSettle();

      await tester.enterText(
      find.widgetWithText(TextFormField, 'ชื่อรายการ *'), 'ข้าวมันไก่');
      await tester.enterText(
      find.widgetWithText(TextFormField, 'ชื่อร้าน *'), 'ร้านอาหาร A');
      await tester.enterText(
      find.widgetWithText(TextFormField, 'จำนวนเงิน (บาท) *'), '55');

      await tapSave(tester);

      verify(() => mockSave(any())).called(1);

      await testBloc.close();
    });


  });

  group('Initial Values from ScanReceipt', () {
    testWidgets('pre-fills title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AutoRouter(
            builder: (context, child) {
              return BlocProvider.value(
                value: bloc,
                child: const AddEditExpensePage(
                  initialOcrText: 'ข้าวมันไก่ 55 บาท',
                  initialCategory: 'อาหาร',
                  initialSummary: 'ซื้อข้าวมันไก่',
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'ชื่อรายการ *'),
      );

      expect(field.controller!.text, 'ซื้อข้าวมันไก่');
    });

  });
}
