import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final ThemeMode themeMode;
  const SettingsState({this.themeMode = ThemeMode.light});
  SettingsState copyWith({ThemeMode? themeMode}) =>
      SettingsState(themeMode: themeMode ?? this.themeMode);
}

class SettingsCubit extends Cubit<SettingsState> {
  static const _themeKey = 'theme_mode';

  SettingsCubit() : super(const SettingsState()) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey) ?? false;
    emit(state.copyWith(
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light));
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = state.themeMode == ThemeMode.dark;
    await prefs.setBool(_themeKey, !isDark);
    emit(state.copyWith(
        themeMode: !isDark ? ThemeMode.dark : ThemeMode.light));
  }
}
