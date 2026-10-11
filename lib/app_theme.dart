import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bgDark = Color(0xFF051F20);
  static const bgMid = Color(0xFF0B2B26);
  static const card = Color(0xFF163832);
  static const cardLight = Color(0xFF235347);
  static const sage = Color(0xFF8EB69B);
  static const mint = Color(0xFFDAF1DE);
}

ThemeData derevariumTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.sage,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.sage,
        onPrimary: AppColors.bgDark,
        primaryContainer: AppColors.cardLight,
        onPrimaryContainer: AppColors.mint,
        secondary: AppColors.sage,
        onSecondary: AppColors.bgDark,
        secondaryContainer: AppColors.cardLight,
        onSecondaryContainer: AppColors.mint,
        tertiary: AppColors.mint,
        onTertiary: AppColors.bgDark,
        tertiaryContainer: AppColors.card,
        onTertiaryContainer: AppColors.mint,
        surface: AppColors.bgDark,
        onSurface: AppColors.mint,
        onSurfaceVariant: AppColors.sage,
        surfaceContainerLowest: AppColors.bgDark,
        surfaceContainerLow: AppColors.bgMid,
        surfaceContainer: AppColors.card,
        surfaceContainerHigh: AppColors.card,
        surfaceContainerHighest: AppColors.cardLight,
        outline: AppColors.sage,
        outlineVariant: AppColors.cardLight,
        inverseSurface: AppColors.mint,
        onInverseSurface: AppColors.bgDark,
        inversePrimary: AppColors.cardLight,
        surfaceTint: Colors.transparent,
        shadow: AppColors.bgDark,
        scrim: AppColors.bgDark,
      );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    borderSide: BorderSide(color: AppColors.cardLight),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bgDark,
    canvasColor: AppColors.bgMid,
    iconTheme: const IconThemeData(color: AppColors.sage, size: 22),
    textTheme: base.textTheme.copyWith(
      headlineLarge: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppColors.mint,
        height: 1.15,
      ),
      headlineMedium: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.mint,
        height: 1.2,
      ),
      titleLarge: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.mint,
      ),
      titleMedium: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.mint,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        color: AppColors.mint,
        height: 1.5,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        color: AppColors.mint,
        height: 1.5,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        color: AppColors.sage,
        height: 1.4,
      ),
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: AppColors.bgDark,
      foregroundColor: AppColors.mint,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: AppColors.mint,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape,
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.card,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.sage, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: TextStyle(color: AppColors.sage),
      hintStyle: TextStyle(color: AppColors.sage, fontSize: 14),
      prefixIconColor: AppColors.sage,
      suffixIconColor: AppColors.sage,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.sage,
        foregroundColor: AppColors.bgDark,
        minimumSize: const Size(48, 52),
        shape: shape,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.mint,
        minimumSize: const Size(48, 52),
        side: const BorderSide(color: AppColors.cardLight),
        shape: shape,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.sage,
        minimumSize: const Size(44, 44),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.bgMid,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 80,
      indicatorColor: AppColors.cardLight,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.mint
              : AppColors.sage,
          size: 24,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? AppColors.mint
              : AppColors.sage,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.bgMid,
      selectedColor: AppColors.cardLight,
      checkmarkColor: AppColors.mint,
      labelStyle: const TextStyle(color: AppColors.mint, fontSize: 13),
      side: const BorderSide(color: AppColors.cardLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.bgMid,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.bgMid,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: AppColors.bgMid,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.cardLight,
      contentTextStyle: const TextStyle(color: AppColors.mint, fontSize: 14),
      actionTextColor: AppColors.mint,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.sage,
      linearTrackColor: AppColors.bgMid,
      circularTrackColor: AppColors.cardLight,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.sage,
      textColor: AppColors.mint,
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: shape,
      textStyle: const TextStyle(color: AppColors.mint),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.bgMid,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.card,
      headerForegroundColor: AppColors.mint,
      shape: shape,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.cardLight, space: 24),
  );
}
