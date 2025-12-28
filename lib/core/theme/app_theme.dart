import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Pastel Palette (Light)
  static const Color creamBackground = Color(0xFFFDFCF8);
  static const Color softBlue = Color(0xFFA2D2FF);
  static const Color softPink = Color(0xFFFFC8DD);
  static const Color softPurple = Color(0xFFCDB4DB);
  static const Color textDark = Color(0xFF2B2D42);
  static const Color textLight = Color(0xFF8D99AE);

  // Dark Palette
  static const Color darkBackground = Color(0xFF1A1B26); // Deep blue-grey
  static const Color darkSurface = Color(0xFF24283B);
  static const Color neonBlue = Color(0xFF7AA2F7);
  static const Color neonPink = Color(0xFFBB9AF7);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: creamBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: softBlue,
        brightness: Brightness.light,
        surface: creamBackground,
        onSurface: textDark,
        primary: softBlue,
        secondary: softPink,
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(bodyColor: textDark, displayColor: textDark),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: textDark),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: neonBlue,
        brightness: Brightness.dark,
        surface: darkSurface,
        onSurface: Colors.white,
        primary: neonBlue,
        secondary: neonPink,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: darkSurface.withValues(alpha: 0.8),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1))
        ),
      ),
    );
  }
}
