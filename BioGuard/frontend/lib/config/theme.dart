import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// BioGuard — Color palette
/// Built around two brand colors: Sky Mint (#B8F7E4) and Graphite (#25272C).
/// Everything else is derived from those two, plus semantic status colors.
class AppColors {
  AppColors._();

  // Brand
  static const skyMint = Color(0xFFB8F7E4);
  static const graphite = Color(0xFF25272C);

  // Derived shades
  static const mintDeep = Color(0xFF5FD4B4);
  static const graphiteDeep = Color(0xFF18191D);
  static const graphiteLight = Color(0xFF30333A);

  // Text on graphite
  static const textPrimary = Color(0xFFF2FBF8);
  static const textSecondary = Color(0xB3F2FBF8);
  static const textMuted = Color(0x80F2FBF8);

  // Status
  static const success = skyMint;
  static const warning = Color(0xFFFFC978);
  static const danger = Color(0xFFFF7A85);

  // Glass surfaces
  static const glassFill = Color(0x14FFFFFF);
  static const glassBorder = Color(0x24FFFFFF);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.skyMint,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.skyMint,
          onPrimary: AppColors.graphite,
          secondary: AppColors.mintDeep,
          onSecondary: AppColors.graphite,
          surface: AppColors.graphite,
          onSurface: AppColors.textPrimary,
          error: AppColors.danger,
          onError: AppColors.graphite,
        );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.glassBorder),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.graphite,
      dividerColor: Colors.white.withValues(alpha: 0.08),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.skyMint),
        prefixIconColor: AppColors.textMuted,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.skyMint, width: 1.4),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        errorStyle: const TextStyle(color: AppColors.danger),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.skyMint,
          foregroundColor: AppColors.graphite,
          disabledBackgroundColor: AppColors.skyMint.withValues(alpha: 0.4),
          disabledForegroundColor: AppColors.graphite.withValues(alpha: 0.7),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.skyMint),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.skyMint
                : AppColors.glassFill,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.graphite
                : AppColors.textSecondary,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.glassBorder),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.skyMint,
        refreshBackgroundColor: AppColors.graphiteLight,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.graphiteLight,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.graphiteLight,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: AppColors.textPrimary),
      ),
    );
  }
}
