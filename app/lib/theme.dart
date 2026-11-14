/// LLMap の Flutter テーマ（v2: llmap-view / Research Console と同じ設計言語）。
/// 淡灰の背景・白いカード・黒の胶囊ボタン・Inter。写真が主役になるよう、
/// 面板や装飾の色は黒白灰に抑える。値はすべて theme/tokens.dart から引く。
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/tokens.dart';

/// 採集状態（_status）の色。黒白灰の濃淡で段階を示す（確定だけ緑）。
Color statusColor(String status) =>
    {
      'pending': AppColors.textSecondary,
      'ai': AppColors.link,
      'human-reviewed': AppColors.textPrimary,
      'final': AppColors.success,
    }[status] ??
    AppColors.textSecondary;

/// 状態バッジ（小さな胶囊）。一覧・フォーム・地図詳情で共用。
/// [label] は表示文言（field_labels.statusLabel の本地化済みラベルを渡す。
/// null なら内部値をそのまま表示）。色分けキーは常に内部値 [status] で引く。
Widget statusBadge(String status, {String? label}) {
  final c = statusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(label ?? status,
        style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
  );
}

ThemeData llmapTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.surface,
    secondary: AppColors.link,
    onSecondary: AppColors.surface,
    tertiary: AppColors.charcoal,
    onTertiary: AppColors.surface,
    error: AppColors.danger,
    onError: AppColors.surface,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.muted,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.outline,
    outlineVariant: AppColors.borderSubtle,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = GoogleFonts.interTextTheme(base.textTheme)
      .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);

  const pill = StadiumBorder();
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: const BorderSide(color: AppColors.borderSubtle),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: text,
    dividerColor: AppColors.borderSubtle,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.appTitle(),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        shape: pill,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        textStyle: AppText.button(),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.borderSubtle),
        shape: pill,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        textStyle: AppText.button(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        shape: pill,
        textStyle: AppText.button().copyWith(fontSize: 14),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.surface,
      elevation: 2,
      extendedTextStyle: AppText.button(),
      shape: pill,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.textPrimary, width: 1.4)),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: fieldBorder,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.selected,
      secondarySelectedColor: AppColors.selected,
      checkmarkColor: AppColors.surface,
      side: const BorderSide(color: AppColors.borderSubtle),
      shape: pill,
      labelStyle: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary),
      secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.surface),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.surface : null),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.primary : null),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textSecondary),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.primary : null),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.textPrimary,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg))),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      textStyle: AppText.body(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: GoogleFonts.inter(color: AppColors.surface),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.primary),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.textSecondary),
  );
}
