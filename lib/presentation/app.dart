import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import 'blocs/expense/expense_bloc.dart';
import 'blocs/settings/settings_cubit.dart';
import 'pages/dashboard/dashboard_page.dart'; // import AppRouteObserver
import 'router/app_router.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _router = AppRouter();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SettingsCubit>()),
        BlocProvider(create: (_) => sl<ExpenseBloc>()),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          return MaterialApp.router(
            title: 'AI Expense Tracker',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6C63FF),
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6C63FF),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            // ✅ Register RouteObserver เพื่อให้ didPopNext() ทำงานได้
            routerConfig: _router.config(
              navigatorObservers: () => [AppRouteObserver.instance],
            ),
          );
        },
      ),
    );
  }
}