// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Paleta clara con carácter ────────────────────────────────────────────────
  // Fondo: blanco con toque frío muy sutil
  static const Color bgLight    = Color(0xFFF5F6FA);
  static const Color bgDark     = bgLight;
  // Cards: blanco puro con sombra visible
  static const Color cardColor  = Color(0xFFFFFFFF);
  // Borde: gris visible, no invisible
  static const Color cardBorder = Color(0xFFDDE1EE);

  // Colores de acción — saturados, no pasteles
  static const Color primaryColor = Color(0xFF4F46E5); // índigo sólido
  static const Color accentColor  = Color(0xFFEC4899); // rosa saturado
  static const Color goldColor    = Color(0xFFF59E0B); // ámbar cálido
  static const Color greenColor   = Color(0xFF10B981); // esmeralda vivo
  static const Color orangeColor  = Color(0xFFF97316); // naranja intenso

  // Texto — contraste alto
  static const Color textPrimary   = Color(0xFF111827); // casi negro
  static const Color textSecondary = Color(0xFF6B7280); // gris medio legible

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness:  Brightness.light,
      primary:     primaryColor,
      onPrimary:   Colors.white,
      secondary:   goldColor,
      onSecondary: Colors.white,
      surface:     cardColor,
      onSurface:   textPrimary,
      error:       Color(0xFFEF4444),
      onError:     Colors.white,
    );

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgLight,
      primaryColor: primaryColor,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: bgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: textSecondary, size: 22),
        actionsIconTheme: const IconThemeData(color: textSecondary, size: 22),
      ),

      // ── Cards: sombra real, visible ───────────────────────────────────────
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 3,
        shadowColor: const Color(0x1A4F46E5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: cardBorder),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Tipografía ────────────────────────────────────────────────────────
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).copyWith(
        bodyLarge:   GoogleFonts.poppins(fontSize: 14, color: textPrimary),
        bodyMedium:  GoogleFonts.poppins(fontSize: 13, color: textPrimary),
        bodySmall:   GoogleFonts.poppins(fontSize: 11, color: textSecondary),
        labelSmall:  GoogleFonts.poppins(fontSize: 10, color: textSecondary, letterSpacing: 0.3),
        titleMedium: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
        titleSmall:  GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary),
      ),

      // ── Botones ───────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEEF2FF),
        selectedColor: primaryColor.withOpacity(0.15),
        labelStyle: GoogleFonts.poppins(fontSize: 11, color: textSecondary),
        side: const BorderSide(color: cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      ),

      // ── Inputs ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: textSecondary),
        labelStyle: GoogleFonts.poppins(fontSize: 13, color: textSecondary),
      ),

      // ── TabBar ────────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: cardBorder,
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(color: cardBorder, space: 1, thickness: 1),

      // ── ProgressIndicator ─────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primaryColor),

      useMaterial3: true,
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
