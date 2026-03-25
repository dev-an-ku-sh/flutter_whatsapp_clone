import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

// Cubit for theme (simple state)
class ThemeCubit extends Cubit<bool> {
  ThemeCubit() : super(true); // true = dark mode

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(AppConstants.themeKey) ?? true;
    emit(isDark);
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.themeKey, !state);
    emit(!state);
  }
}
