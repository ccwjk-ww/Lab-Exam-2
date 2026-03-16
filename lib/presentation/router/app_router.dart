import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';

import '../../domain/entities/expense.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../pages/expense_list/expense_list_page.dart';
import '../pages/add_edit_expense/add_edit_expense_page.dart';
import '../pages/scan_receipt/scan_receipt_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/ai_insign_page/ai_insights_page.dart';

part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: DashboardRoute.page, initial: true),
        AutoRoute(page: ExpenseListRoute.page),
        AutoRoute(page: AddEditExpenseRoute.page),
        AutoRoute(page: ScanReceiptRoute.page),
        AutoRoute(page: SettingsRoute.page),
        AutoRoute(page: AiInsightsRoute.page),
      ];
}
