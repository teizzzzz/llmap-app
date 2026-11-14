/// LLMap デザイントークン（v2: llmap-view / Research Console と同じ設計言語）。
/// 黒・白・灰が基本で、彩色は内容（写真・言語色）から来るものだけ。
/// 例外は「要対応」の赤と、状態を示す控えめな緑・琥珀。
/// ボタン・チップは胶囊、カードは白に 1px の淡い縁、影は浮いている要素だけ。
/// 全画面・全部品はここを参照する（色・角丸・影・余白・タイポを各画面に散らさない）。
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 配色（llmap-view style.css の :root と同じ値）。
class AppColors {
  static const background = Color(0xFFF4F4F4); // 画面背景（--bg）
  static const surface = Color(0xFFFFFFFF); // カード/サーフェス（--surface）
  static const textPrimary = Color(0xFF0F0F0E); // 主要文字（--ink）
  static const textSecondary = Color(0xFF6F6F6F); // 補助文字（--muted を可読性のため少し濃く）
  static const borderSubtle = Color(0x140F0F0E); // 淡い縁（--line, 8%）
  static const outline = Color(0xFFC6C6C6); // やや濃い縁（--faint）

  static const primary = Color(0xFF0F0F0E); // 主アクション（黒の胶囊）
  static const link = Color(0xFF3D3C39); // 文字リンク・補助操作（--ink-2）
  static const selected = Color(0xFF0F0F0E); // 選択中（黒地に白文字）
  static const charcoal = Color(0xFF3A3A3C); // 選択中の別状態（衛星など）

  static const success = Color(0xFF2E7D4F); // 完了・取得済み（控えめな緑）
  static const warning = Color(0xFFC77C12); // 注意
  static const danger = Color(0xFFE2402F); // 削除・要対応（--badge-red）

  static const muted = Color(0xFFE8E8E8); // 弱い面・プレースホルダ（--track）
  static const hover = Color(0x0A000000); // 押下・ホバーの面（4%）
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

/// 角丸スケール（thumb 12 / card 16 / panel 22 / sheet 28）。
class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

/// 影。カードはほぼ影なし（縁で区切る）、浮いている要素だけ柔らかい影。
class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x14000000), blurRadius: 40, offset: Offset(0, 10)),
  ];
}

/// タイポグラフィ（Inter。見出しは 600・字間を詰める。和文は端末のフォント）。
class AppText {
  static TextStyle appTitle() => GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      color: AppColors.textPrimary);
  static TextStyle pageTitle() => GoogleFonts.inter(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.0,
      height: 1.15,
      color: AppColors.textPrimary);
  static TextStyle sectionTitle() => GoogleFonts.inter(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: AppColors.textPrimary);
  static TextStyle body() => GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: AppColors.textPrimary);
  static TextStyle caption() => GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary);
  static TextStyle button() =>
      GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600);
}

/// `#RRGGBB` / `#AARRGGBB` → Color。地図の言語別色などで共用。
Color parseHexColor(String h) {
  h = h.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}
