// Console の UI 言語（Step 11）。翻訳するのは**表示層のみ** —
// データの字段キー・CSV ヘッダー・backend API・内部状態値
// （raw / verified / quick 等）は一切変更しない。
//
// 言語の決定順: localStorage（ユーザー設定）→ ブラウザ言語 → ja-JP（既定）。
// 日本の大学での運用が主のため、既定は日本語。
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import enUS from './locales/en-US.json';
import jaJP from './locales/ja-JP.json';
import zhCN from './locales/zh-CN.json';

export const SUPPORTED_LANGUAGES = [
  { code: 'ja-JP', label: '日本語' },
  { code: 'zh-CN', label: '简体中文' },
  { code: 'en-US', label: 'English' },
] as const;

export type LanguageCode = (typeof SUPPORTED_LANGUAGES)[number]['code'];

const STORAGE_KEY = 'llmap.console.language';

const isSupported = (v: string | null): v is LanguageCode =>
  SUPPORTED_LANGUAGES.some((l) => l.code === v);

function detectLanguage(): LanguageCode {
  try {
    const saved = window.localStorage.getItem(STORAGE_KEY);
    if (isSupported(saved)) return saved;
  } catch {
    // localStorage 不可（プライベートモード等）でも既定言語で起動を続ける
  }
  const nav = (typeof navigator !== 'undefined' && navigator.language
    ? navigator.language
    : ''
  ).toLowerCase();
  if (nav.startsWith('zh')) return 'zh-CN';
  if (nav.startsWith('en')) return 'en-US';
  return 'ja-JP';
}

void i18n.use(initReactI18next).init({
  resources: {
    'ja-JP': { translation: jaJP },
    'zh-CN': { translation: zhCN },
    'en-US': { translation: enUS },
  },
  lng: detectLanguage(),
  fallbackLng: 'ja-JP',
  interpolation: { escapeValue: false }, // React 側でエスケープされる
  returnEmptyString: false,
});

/** 言語を即時切替し、次回起動用に localStorage へ保存する（Settings から使用）。 */
export function setLanguage(code: LanguageCode): void {
  void i18n.changeLanguage(code);
  try {
    window.localStorage.setItem(STORAGE_KEY, code);
  } catch {
    // 保存できなくても切替自体は有効（セッション内のみ）
  }
  document.documentElement.lang = code;
}

document.documentElement.lang = i18n.language;

export default i18n;
