import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  // Brand Colors - Warm, energetic palette for a POS app
  static const Color primary = Color(0xFFFF6B35);       // Vibrant orange
  static const Color primaryDark = Color(0xFFE55A25);
  static const Color primaryLight = Color(0xFFFF8C5A);
  static const Color secondary = Color(0xFF2D3250);      // Deep navy
  static const Color accent = Color(0xFF4CAF50);         // Success green
  static const Color warning = Color(0xFFFFB300);        // Amber
  static const Color danger = Color(0xFFE53935);         // Red
  static const Color surface = Color(0xFFF8F9FA);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color lowStockColor = Color(0xFFFFF3E0);
  static const Color outOfStockColor = Color(0xFFFFEBEE);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: danger,
      ),
      scaffoldBackgroundColor: surface,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),

      // Cards
      cardTheme: CardThemeData( // <-- Change this line
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: Size(double.infinity, 52.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          textStyle: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        hintStyle: TextStyle(
          color: textSecondary,
          fontSize: 14.sp,
          fontFamily: 'Poppins',
        ),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBg,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // Text styles
  static TextStyle get heading1 => TextStyle(
    fontSize: 24.sp,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    fontFamily: 'Poppins',
  );

  static TextStyle get heading2 => TextStyle(
    fontSize: 20.sp,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    fontFamily: 'Poppins',
  );

  static TextStyle get heading3 => TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    fontFamily: 'Poppins',
  );

  static TextStyle get body => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    fontFamily: 'Poppins',
  );

  static TextStyle get caption => TextStyle(
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    fontFamily: 'Poppins',
  );

  static TextStyle get price => TextStyle(
    fontSize: 18.sp,
    fontWeight: FontWeight.w700,
    color: primary,
    fontFamily: 'Poppins',
  );
}
