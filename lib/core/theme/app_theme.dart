import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const cream = Color(0xFFF5F0E8);
  static const paper = Color(0xFFEDE8DC);
  static const inkBlack = Color(0xFF1A1A1A);
  static const inkBlue = Color(0xFF1B3A6B);
  static const inkRed = Color(0xFFBF2020);
  static const stampBorder = Color(0xFFCCC5B5);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B6459);
  static const error = Color(0xFFBF2020);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.cream,
        colorScheme: ColorScheme.light(
          primary: AppColors.inkBlack,
          secondary: AppColors.inkBlue,
          error: AppColors.error,
          surface: AppColors.paper,
        ),
        textTheme: GoogleFonts.instrumentSansTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.cream,
          foregroundColor: AppColors.inkBlack,
          elevation: 0,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.paper,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.stampBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.stampBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide:
                const BorderSide(color: AppColors.inkBlack, width: 1.5),
          ),
          labelStyle:
              const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.inkBlack,
            foregroundColor: AppColors.cream,
            minimumSize: const Size(double.infinity, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            textStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.2),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.inkBlue),
        ),
        dividerTheme: const DividerThemeData(color: AppColors.stampBorder),
      );
}
