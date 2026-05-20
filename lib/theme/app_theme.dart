import 'package:flutter/material.dart';

class AppColors {
  // Banco do Brasil brand colors
  static const Color primary = Color(0xFF0038A8);    // BB Blue
  static const Color accent = Color(0xFFFCDF00);     // BB Yellow
  static const Color surface = Color(0xFFF8F9FA);
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);

  // Status colors (matching Figma)
  static const Color statusMinhaCarteira = Color(0xFF2563EB);  // 🔵
  static const Color statusOutraCarteira = Color(0xFFD97706);  // 🟡
  static const Color statusConcorrente = Color(0xFFDC2626);    // 🔴
  static const Color statusNovaEmpresa = Color(0xFF7C3AED);    // 🟣
  static const Color statusLeadFrio = Color(0xFF9CA3AF);       // ⚪

  // Score colors
  static const Color scoreHigh = Color(0xFF16A34A);
  static const Color scoreMid = Color(0xFFD97706);
  static const Color scoreLow = Color(0xFFDC2626);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  static Color statusColor(String status) {
    switch (status) {
      case 'clienteBB_Minha': return AppColors.statusMinhaCarteira;
      case 'clienteBB_Outra': return AppColors.statusOutraCarteira;
      case 'concorrente': return AppColors.statusConcorrente;
      case 'novaOportunidade': return AppColors.statusNovaEmpresa;
      default: return AppColors.statusLeadFrio;
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'clienteBB_Minha': return 'Minha Carteira';
      case 'clienteBB_Outra': return 'Outra Carteira BB';
      case 'concorrente': return 'Concorrente';
      case 'novaOportunidade': return 'Nova Empresa';
      default: return 'Lead Frio';
    }
  }

  static Color scoreColor(double score) {
    if (score >= 75) return AppColors.scoreHigh;
    if (score >= 45) return AppColors.scoreMid;
    return AppColors.scoreLow;
  }
}
