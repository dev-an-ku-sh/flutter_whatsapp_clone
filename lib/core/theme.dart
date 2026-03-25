import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // WhatsApp colors
  static const Color whatsappGreen = Color(0xFF00A884);
  static const Color whatsappDarkGreen = Color(0xFF008069);
  static const Color whatsappTealGreen = Color(0xFF075E54);
  static const Color whatsappLightGreen = Color(0xFFDCF8C6);
  static const Color whatsappBlue = Color(0xFF53BDEB);

  // Dark theme colors
  static const Color darkBg = Color(0xFF111B21);
  static const Color darkPanel = Color(0xFF1F2C34);
  static const Color darkHeader = Color(0xFF202C33);
  static const Color darkInput = Color(0xFF2A3942);
  static const Color darkBubbleOut = Color(0xFF005C4B);
  static const Color darkBubbleIn = Color(0xFF202C33);
  static const Color darkDivider = Color(0xFF2A3942);
  static const Color darkTextPrimary = Color(0xFFE9EDEF);
  static const Color darkTextSecondary = Color(0xFF8696A0);
  static const Color darkIcon = Color(0xFFAEBAC1);
  static const Color darkSearchBg = Color(0xFF202C33);
  static const Color darkChatBg = Color(0xFF0B141A);
  static const Color darkUnreadBadge = Color(0xFF00A884);

  // Light theme colors
  static const Color lightBg = Color(0xFFF0F2F5);
  static const Color lightPanel = Color(0xFFFFFFFF);
  static const Color lightHeader = Color(0xFF008069);
  static const Color lightInput = Color(0xFFF0F2F5);
  static const Color lightBubbleOut = Color(0xFFD9FDD3);
  static const Color lightBubbleIn = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE9EDEF);
  static const Color lightTextPrimary = Color(0xFF111B21);
  static const Color lightTextSecondary = Color(0xFF667781);
  static const Color lightIcon = Color(0xFF54656F);
  static const Color lightSearchBg = Color(0xFFF0F2F5);
  static const Color lightChatBg = Color(0xFFEFE7DE);
  static const Color lightUnreadBadge = Color(0xFF25D366);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: whatsappGreen,
      colorScheme: const ColorScheme.dark(
        primary: whatsappGreen,
        secondary: whatsappBlue,
        surface: darkPanel,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTextPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkHeader,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: darkTextSecondary),
      ),
      dividerColor: darkDivider,
      iconTheme: const IconThemeData(color: darkIcon),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: whatsappGreen,
      colorScheme: const ColorScheme.light(
        primary: whatsappGreen,
        secondary: whatsappBlue,
        surface: lightPanel,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightHeader,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: lightTextSecondary),
      ),
      dividerColor: lightDivider,
      iconTheme: const IconThemeData(color: lightIcon),
    );
  }
}
