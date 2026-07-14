import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const sidebar = Color(0xFF181D2C);
  static const primary = Color(0xFFC62828);
  static const bg = Color(0xFFF4F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EF);
  static const text1 = Color(0xFF111827);
  static const text2 = Color(0xFF6B7280);
  static const text3 = Color(0xFF9CA3AF);
  static const green = Color(0xFF16A34A);
  static const orange = Color(0xFFD97706);
  static const blue = Color(0xFF2563EB);
  static const red = Color(0xFFDC2626);
  static const purple = Color(0xFF7C3AED);
  static const teal = Color(0xFF0891B2);
  static const emerald = Color(0xFF059669);
  static const indigo = Color(0xFF4F46E5);

  // Background tints
  static const greenBg = Color(0xFFF0FDF4);
  static const orangeBg = Color(0xFFFFFBEB);
  static const blueBg = Color(0xFFEFF6FF);
  static const redBg = Color(0xFFFEF2F2);
  static const purpleBg = Color(0xFFF5F3FF);
  static const grayBg = Color(0xFFF3F4F6);
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      useMaterial3: true,
    );
    return base.copyWith(
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme),
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Color(0xFFD1D5DB)),
        thickness: WidgetStatePropertyAll(5),
        radius: Radius.circular(4),
      ),
    );
  }

  // Text styles
  static TextStyle h1 = GoogleFonts.dmSans(
    fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text1,
    letterSpacing: -0.3,
  );
  static TextStyle h2 = GoogleFonts.dmSans(
    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text1,
  );
  static TextStyle label = GoogleFonts.dmSans(
    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text3,
    letterSpacing: 0.8, height: 1,
  );
  static TextStyle body = GoogleFonts.dmSans(
    fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.text2,
  );
  static TextStyle bodyBold = GoogleFonts.dmSans(
    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1,
  );
}
