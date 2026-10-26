import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta do ReTool desktop (`src/index.css`, `:root`).
class AppColors {
  AppColors._();
  static const red00 = Color(0xFFE40D2C);
  static const red01 = Color(0xFF8C1A17);
  static const red02 = Color(0xFFFF798D);
  static const red03 = Color(0xFFFCC4CC);
  static const gray00 = Color(0xFF4A4A4A);
  static const gray01 = Color(0xFF808080);
  static const gray02 = Color(0xFFD6D6D6);
  static const gray03 = Color(0xFFE8E7E7);
  static const black00 = Color(0xFF000000);
  static const black01 = Color(0xFF2F2F2F);
  static const white00 = Color(0xFFFFFFFE);
  static const success00 = Color(0xFF00762E);
  static const success01 = Color(0xFF018D37);
  static const various00 = Color(0xFF9E3D45);
  static const various01 = Color(0xFFEB593B);
  static const various02 = Color(0xFF785994);
  static const various03 = Color(0xFF334F5C);
  static const various04 = Color(0xFFF5A32B);

  // Mapeamento semântico
  static const primary = red00;
  static const primaryHover = red01;
  static const textTitle = red00;
  static const textBody = gray00;
  static const textDark = black01;
  static const textMuted = Color(0xFF9CA3AF);
  static const textSubtle = Color(0xFF6B7280);
  static const surface = white00;
  static const surfaceAlt = Color(0xFFF9FAFB);
  static const border = gray02;
  static const hover = gray03;
  static const danger = red00;
  static const success = success00;

  /// Fundo translúcido vermelho dos cartões da Home (`rgba(228, 13, 44, 0.1)`).
  static const primarySoft = Color(0x1AE40D2C);

  // Caixas/badges
  static const pinkBg = red03;
  static const pinkText = red01;
  static const tealBg = gray03;
  static const tealText = various03;
  static const yellowBg = Color(0x26F5A32B);
  static const yellowText = various04;
  static const blueBg = Color(0x26785994);
  static const blueText = various02;

  // Feedback
  static const erroBg = Color(0xFFFEE2E2);
  static const erroText = Color(0xFFB91C1C);
  static const avisoBg = Color(0xFFFEF3C7);
  static const avisoText = Color(0xFFB45309);
  static const sucessoBg = Color(0xFFDCFCE7);
  static const sucessoText = Color(0xFF15803D);
  static const infoBg = Color(0xFFF8FAFC);
  static const infoBorder = Color(0xFFE2E8F0);
  static const infoText = Color(0xFF475569);
  static const toastBg = Color(0xFF1F2937);
  static const slate900 = Color(0xFF0F172A);
}

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const x2l = 48.0;
}

class AppRadius {
  AppRadius._();
  static const sm = 6.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 50.0;
}

class AppShadows {
  AppShadows._();
  static const sm = [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))];
  static const md = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 4), spreadRadius: -1),
    BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2), spreadRadius: -1),
  ];
  static const lg = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 15, offset: Offset(0, 10), spreadRadius: -3),
    BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 4), spreadRadius: -2),
  ];
  static const primaryGlow = [BoxShadow(color: Color(0x4DE40D2C), blurRadius: 12, offset: Offset(0, 4))];
}

class AppTheme {
  AppTheme._();

  /// `fontesRemotas: false` nos testes (sem rede para baixar a Inter).
  static ThemeData build({bool fontesRemotas = true}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textDark,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      splashFactory: InkSparkle.splashFactory,
    );
    final textTheme = (fontesRemotas ? GoogleFonts.interTextTheme(base.textTheme) : base.textTheme).apply(
      bodyColor: AppColors.textBody,
      displayColor: AppColors.textDark,
    );
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textDark),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: borda,
        enabledBorder: borda,
        focusedBorder: borda.copyWith(borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: borda.copyWith(borderSide: const BorderSide(color: AppColors.danger)),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIconColor: AppColors.textSubtle,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        side: const BorderSide(color: AppColors.border),
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.toastBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSubtle,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.border,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
