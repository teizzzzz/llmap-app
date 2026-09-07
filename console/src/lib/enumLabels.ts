import type { TFunction } from 'i18next';
import i18n from '../i18n';
import { LANGUAGE_LIST } from './languageList';

// 選択肢値の表示ラベル。データ層は常に正準値（v6 の中文値・言語名は日本語値）の
// まま、表示だけを UI 言語へ訳す（字段名 fields.* / 状態値 status.* と同じ方針）。
// キーは値そのもの（enum.<正準値>）。現状、同じ正準値が字段によって別訳になる
// ことは無い。訳の無い値は言語表（languageList）を第2辞書として引き、それでも
// 無ければ原文のまま表示する（自由追加値・将来の新選択肢）。
// 注意: fallbackLng=ja のため、locale 3 つすべてが完全な対照表を持つこと
// （欠けると zh/en 画面で日本語訳へ誤フォールバックする）。

const MISS = ' '; // t() が「訳なし」を返したことを判別する哨兵値

const LANG_BY_JA = new Map(LANGUAGE_LIST.map((l) => [l.ja, l]));

/** 検索追加された言語（enum.* に無い）のローカル名。 */
const languageListLabel = (value: string): string | null => {
  const lang = LANG_BY_JA.get(value);
  if (!lang) return null;
  const ui = i18n.language;
  return ui.startsWith('zh') ? lang.zh : ui.startsWith('en') ? lang.en : lang.ja;
};

/** 単一の選択肢値の表示ラベル。空値・「—」はそのまま返す。 */
export function enumLabel(t: TFunction, value: string): string {
  if (!value || value === '—') return value;
  const hit = t(`enum.${value}`, { defaultValue: MISS });
  if (hit !== MISS) return hit;
  return languageListLabel(value) ?? value;
}

/** 「/」等で併記された複数値（主要言語等）を値ごとに訳して「/」で結ぶ。 */
export function multiEnumLabel(t: TFunction, value: string): string {
  if (!value || value === '—') return value;
  // 値全体に訳があればそれを優先（「・」を含む単一値を誤分割しない）
  const whole = t(`enum.${value}`, { defaultValue: MISS });
  if (whole !== MISS) return whole;
  const parts = value.split(/[/・、,]/).map((s) => s.trim()).filter(Boolean);
  return parts.length ? parts.map((p) => enumLabel(t, p)).join('/') : value;
}
