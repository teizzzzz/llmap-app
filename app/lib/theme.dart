/// Lingscape デザインシステム（Figma参照）の Flutter テーマ。
/// 暖色クリーム背景・テラコッタ橙の主アクション・大きな角丸カード・
/// Fraunces(セリフ見出し)/Nunito(本文) のエディトリアル調を全画面に適用する。
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/tokens.dart';

// ── 後方互換エイリアス（既存画面は llXxx を使用）。実体は AppColors。 ──
const llBackground = AppColors.backgroundWarm;
const llForeground = AppColors.textPrimary;
const llCard = AppColors.surfaceIvory;
const llPrimary = AppColors.accentTerracotta;
const llAccent = AppColors.accentBlue;
const llYellow = AppColors.accentMustard;
const llPurple = AppColors.accentViolet;
const llMuted = AppColors.muted;
const llMutedFg = AppColors.textSecondary;
const llDestructive = AppColors.danger;
const llBorder = AppColors.borderSubtle;

/// 採集状態（_status）の色。全画面で共通利用する。
Color statusColor(String status) =>
    {
      'pending': AppColors.textSecondary,
      'ai': AppColors.accentBlue,
      'human-reviewed': AppColors.accentTerracotta,
      'final': AppColors.success,
    }[status] ??
    AppColors.textSecondary;

/// 状態バッジ（チップ）。一覧・フォーム・地図詳情で共用。
/// [label] は表示文言（field_labels.statusLabel の本地化済みラベルを渡す。
/// null なら内部値をそのまま表示）。色分けキーは常に内部値 [status] で引く。
Widget statusBadge(String status, {String? label}) {
  final c = statusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.14),
      border: Border.all(color: c.withValues(alpha: 0.55)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label ?? status,
        style: TextStyle(
            fontSize: 11, color: c, fontWeight: FontWeight.w700)),
  );
}

ThemeData lingscapeTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: llPrimary,
    onPrimary: llCard,
    secondary: llAccent,
    onSecondary: llCard,
    tertiary: llYellow,
    onTertiary: llForeground,
    error: llDestructive,
    onError: llCard,
    surface: llCard,
    onSurface: llForeground,
    surfaceContainerHighest: llMuted,
    onSurfaceVariant: llMutedFg,
    outline: Color(0xFF8C806F),
    outlineVariant: llBorder,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final body = GoogleFonts.nunitoTextTheme(base.textTheme);
  // 見出しは Fraunces(セリフ)、本文は Nunito。
  final text = body.copyWith(
    displayLarge: GoogleFonts.fraunces(textStyle: body.displayLarge, fontWeight: FontWeight.w600),
    displayMedium: GoogleFonts.fraunces(textStyle: body.displayMedium, fontWeight: FontWeight.w600),
    displaySmall: GoogleFonts.fraunces(textStyle: body.displaySmall, fontWeight: FontWeight.w600),
    headlineMedium: GoogleFonts.fraunces(textStyle: body.headlineMedium, fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.fraunces(textStyle: body.headlineSmall, fontWeight: FontWeight.w600),
    titleLarge: GoogleFonts.fraunces(textStyle: body.titleLarge, fontWeight: FontWeight.w600),
  ).apply(bodyColor: llForeground, displayColor: llForeground);

  const cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(26)));
  const btnShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(22)));

  return base.copyWith(
    scaffoldBackgroundColor: llBackground,
    textTheme: text,
    dividerColor: llBorder,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: llBackground,
      foregroundColor: llForeground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22, fontWeight: FontWeight.w600, color: llForeground),
    ),
    cardTheme: const CardThemeData(
      color: llCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
      shadowColor: Color(0x1A2F3032),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: llPrimary,
        foregroundColor: llCard,
        shape: btnShape,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
        textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: llForeground,
        side: const BorderSide(color: Color(0xFF8C806F)),
        shape: btnShape,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: llAccent,
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: llPrimary,
      foregroundColor: llCard,
      elevation: 2,
      extendedTextStyle:
          GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: llCard,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: llBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: llBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: llAccent, width: 1.6)),
      labelStyle: const TextStyle(color: llMutedFg),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: llCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: llMuted,
      side: const BorderSide(color: llBorder),
      shape: const StadiumBorder(),
      labelStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: llCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28))),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: llCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: llForeground,
      contentTextStyle: GoogleFonts.nunito(color: llCard),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: llPrimary),
    listTileTheme: const ListTileThemeData(iconColor: llMutedFg),
  );
}
