// 言語色。UV 印刷板と同じ CMY 体系（ja=M, en=C, zh=Y, ko=C+M, vi=C+Y, ne=M+Y）。
// データの正準値（日本語の言語名）から引く。主要 6 言語以外は other（灰）。
// 色は「データ」の印にだけ使い、ボタン等の界面には使わない。

export type LangCode = 'ja' | 'en' | 'zh' | 'ko' | 'vi' | 'ne' | 'other';

export const LANG_COLOR: Record<LangCode, string> = {
  ja: '#E4007F',
  en: '#00A0E9',
  zh: '#FFC800',
  ko: '#7A2E9D',
  vi: '#009944',
  ne: '#EA5504',
  other: '#8E8C86',
};

/** 主要 6 言語の表示順（凡例・分図・分布）。 */
export const MAIN_LANGS: Exclude<LangCode, 'other'>[] = ['ja', 'en', 'zh', 'vi', 'ne', 'ko'];

const CODE_BY_CANONICAL: Record<string, LangCode> = {
  日本語: 'ja',
  英語: 'en',
  中国語: 'zh',
  韓国語: 'ko',
  ベトナム語: 'vi',
  ネパール語: 'ne',
};

/** 主要 6 言語の正準値（code → 日本語名）。筛选値として API に渡す。 */
export const CANONICAL_BY_CODE: Record<string, string> = Object.fromEntries(
  Object.entries(CODE_BY_CANONICAL).map(([k, v]) => [v, k]),
);

/** 「日本語/英語」等の併記値を個々の正準値へ分割する（「—」は空）。 */
export const splitLangs = (v: string | null | undefined): string[] =>
  (v ?? '').split(/[/・、,]/).map((s) => s.trim()).filter((s) => s && s !== '—');

export const langCode = (canonical: string): LangCode =>
  CODE_BY_CANONICAL[canonical] ?? 'other';

export const langColor = (canonical: string): string => LANG_COLOR[langCode(canonical)];

/** 併記値は先頭言語で代表させる（地図の点の色。モバイル版と同じ規則）。 */
export const primaryLangCode = (v: string): LangCode => {
  const first = splitLangs(v)[0];
  return first ? langCode(first) : 'other';
};
