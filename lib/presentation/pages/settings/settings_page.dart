import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/settings/settings_cubit.dart';

@RoutePage()
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ ตั้งค่า')),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final isDark = state.themeMode == ThemeMode.dark;
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('โหมดมืด (Dark Mode)'),
                subtitle: const Text('สลับธีมสว่าง/มืด'),
                secondary: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    key: ValueKey(isDark),
                  ),
                ),
                value: isDark,
                onChanged: (_) =>
                    context.read<SettingsCubit>().toggleTheme(),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('เวอร์ชัน'),
                trailing: const Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('AI Expense Tracker'),
                subtitle: const Text('Enterprise Flutter App'),
              ),
            ],
          );
        },
      ),
    );
  }
}
