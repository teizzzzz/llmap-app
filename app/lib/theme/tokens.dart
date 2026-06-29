/// LLMap デザイントークン（Figma「Lingscape」準拠）。
/// 全画面・全部品はここを参照する。色・角丸・影・余白・タイポを各画面に散らさない。
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 配色（theme.css の :root を意味的名称で再定義）。
class AppColors {
  static const backgroundWarm = Color(0xFFF3EADC); // 画面背景（暖色オートミール）
  static const surfaceIvory = Color(0xFFFFFAF0); // カード/サーフェス
  static const textPrimary = Color(0xFF2F3032); // 主要文字（チャコール）
  static const textSecondary = Color(0xFF7C766F); // 補助文字
  static const borderSubtle = Color(0x24463E32); // rgba(70,62,50,.14)
  static const outline = Color(0xFF8C806F); // 縁取り（やや濃い）

  static const accentBlue = Color(0xFF3B7FBA);
  static const accentMustard = Color(0xFFF4C64D);
  static const accentTerracotta = Color(0xFFE97545); // 主アクション
  static const accentViolet = Color(0xFF8A78C8);

  static const success = Color(0xFF4C9A77);
  static const warning = Color(0xFFD9923B);
  static const danger = Color(0xFFBE4B43);

  static const muted = Color(0xFFEEE4D4); // 弱い面（プレースホルダ等）
}

/// 余白スケール。
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// 角丸スケール。
class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

/// 影。
class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x142F3032), blurRadius: 14, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x242F3032), blurRadius: 22, offset: Offset(0, 10)),
  ];
}

/// タイポグラフィ（見出し=Fraunces / 本文=Nunito）。
class AppText {
  static TextStyle appTitle() => GoogleFonts.fraunces(
      fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle pageTitle() => GoogleFonts.fraunces(
      fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle sectionTitle() => GoogleFonts.fraunces(
      fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle body() => GoogleFonts.nunito(
      fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary);
  static TextStyle caption() => GoogleFonts.nunito(
      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary);
  static TextStyle button() =>
      GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800);
}

/// `#RRGGBB` / `#AARRGGBB` → Color。地図の言語別色などで共用。
Color parseHexColor(String h) {
  h = h.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}
