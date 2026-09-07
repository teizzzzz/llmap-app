// 「＋その他の言語」検索用の言語表。UI 内部キーは ISO 639-1（無いものは 639-3）、
// **保存されるのは ja（日本語名の正準値）のみ** — 現行データ契約（言語名を
// 「/」区切りで保存）は一切変えない。ISO 码は検索・去重・キーボード操作の
// 内部キーとしてだけ使う。zh/en/native は検索の別名（中文界面で「法语」、
// 英語界面で「French」と打っても命中させる）。
export interface LanguageEntry {
  code: string;   // ISO 639-1（無ければ 639-3）。UI 内部キー
  ja: string;     // 正準値（保存される値。既存データと同じ日本語名）
  zh: string;
  en: string;
  native: string; // 本族語名（表示補助・検索別名）
}

// v6 予設 6 言語も含める（去重・検索の一貫性のため）。
export const LANGUAGE_LIST: LanguageEntry[] = [
  { code: 'ja', ja: '日本語', zh: '日语', en: 'Japanese', native: '日本語' },
  { code: 'ko', ja: '韓国語', zh: '韩语', en: 'Korean', native: '한국어' },
  { code: 'zh', ja: '中国語', zh: '中文', en: 'Chinese', native: '中文' },
  { code: 'vi', ja: 'ベトナム語', zh: '越南语', en: 'Vietnamese', native: 'Tiếng Việt' },
  { code: 'ne', ja: 'ネパール語', zh: '尼泊尔语', en: 'Nepali', native: 'नेपाली' },
  { code: 'en', ja: '英語', zh: '英语', en: 'English', native: 'English' },
  { code: 'yue', ja: '広東語', zh: '粤语', en: 'Cantonese', native: '廣東話' },
  { code: 'es', ja: 'スペイン語', zh: '西班牙语', en: 'Spanish', native: 'español' },
  { code: 'fr', ja: 'フランス語', zh: '法语', en: 'French', native: 'français' },
  { code: 'de', ja: 'ドイツ語', zh: '德语', en: 'German', native: 'Deutsch' },
  { code: 'it', ja: 'イタリア語', zh: '意大利语', en: 'Italian', native: 'italiano' },
  { code: 'pt', ja: 'ポルトガル語', zh: '葡萄牙语', en: 'Portuguese', native: 'português' },
  { code: 'ru', ja: 'ロシア語', zh: '俄语', en: 'Russian', native: 'русский' },
  { code: 'ar', ja: 'アラビア語', zh: '阿拉伯语', en: 'Arabic', native: 'العربية' },
  { code: 'th', ja: 'タイ語', zh: '泰语', en: 'Thai', native: 'ไทย' },
  { code: 'id', ja: 'インドネシア語', zh: '印尼语', en: 'Indonesian', native: 'Bahasa Indonesia' },
  { code: 'ms', ja: 'マレー語', zh: '马来语', en: 'Malay', native: 'Bahasa Melayu' },
  { code: 'fil', ja: 'フィリピン語', zh: '菲律宾语', en: 'Filipino', native: 'Filipino' },
  { code: 'my', ja: 'ミャンマー語', zh: '缅甸语', en: 'Burmese', native: 'မြန်မာ' },
  { code: 'km', ja: 'クメール語', zh: '高棉语', en: 'Khmer', native: 'ខ្មែរ' },
  { code: 'lo', ja: 'ラオス語', zh: '老挝语', en: 'Lao', native: 'ລາວ' },
  { code: 'hi', ja: 'ヒンディー語', zh: '印地语', en: 'Hindi', native: 'हिन्दी' },
  { code: 'ur', ja: 'ウルドゥー語', zh: '乌尔都语', en: 'Urdu', native: 'اردو' },
  { code: 'bn', ja: 'ベンガル語', zh: '孟加拉语', en: 'Bengali', native: 'বাংলা' },
  { code: 'ta', ja: 'タミル語', zh: '泰米尔语', en: 'Tamil', native: 'தமிழ்' },
  { code: 'si', ja: 'シンハラ語', zh: '僧伽罗语', en: 'Sinhala', native: 'සිංහල' },
  { code: 'mn', ja: 'モンゴル語', zh: '蒙古语', en: 'Mongolian', native: 'Монгол' },
  { code: 'tr', ja: 'トルコ語', zh: '土耳其语', en: 'Turkish', native: 'Türkçe' },
  { code: 'fa', ja: 'ペルシア語', zh: '波斯语', en: 'Persian', native: 'فارسی' },
  { code: 'he', ja: 'ヘブライ語', zh: '希伯来语', en: 'Hebrew', native: 'עברית' },
  { code: 'el', ja: 'ギリシア語', zh: '希腊语', en: 'Greek', native: 'Ελληνικά' },
  { code: 'nl', ja: 'オランダ語', zh: '荷兰语', en: 'Dutch', native: 'Nederlands' },
  { code: 'sv', ja: 'スウェーデン語', zh: '瑞典语', en: 'Swedish', native: 'svenska' },
  { code: 'no', ja: 'ノルウェー語', zh: '挪威语', en: 'Norwegian', native: 'norsk' },
  { code: 'da', ja: 'デンマーク語', zh: '丹麦语', en: 'Danish', native: 'dansk' },
  { code: 'fi', ja: 'フィンランド語', zh: '芬兰语', en: 'Finnish', native: 'suomi' },
  { code: 'pl', ja: 'ポーランド語', zh: '波兰语', en: 'Polish', native: 'polski' },
  { code: 'cs', ja: 'チェコ語', zh: '捷克语', en: 'Czech', native: 'čeština' },
  { code: 'uk', ja: 'ウクライナ語', zh: '乌克兰语', en: 'Ukrainian', native: 'українська' },
  { code: 'ro', ja: 'ルーマニア語', zh: '罗马尼亚语', en: 'Romanian', native: 'română' },
  { code: 'hu', ja: 'ハンガリー語', zh: '匈牙利语', en: 'Hungarian', native: 'magyar' },
  { code: 'bg', ja: 'ブルガリア語', zh: '保加利亚语', en: 'Bulgarian', native: 'български' },
  { code: 'sr', ja: 'セルビア語', zh: '塞尔维亚语', en: 'Serbian', native: 'српски' },
  { code: 'hr', ja: 'クロアチア語', zh: '克罗地亚语', en: 'Croatian', native: 'hrvatski' },
  { code: 'sk', ja: 'スロバキア語', zh: '斯洛伐克语', en: 'Slovak', native: 'slovenčina' },
  { code: 'sw', ja: 'スワヒリ語', zh: '斯瓦希里语', en: 'Swahili', native: 'Kiswahili' },
  { code: 'am', ja: 'アムハラ語', zh: '阿姆哈拉语', en: 'Amharic', native: 'አማርኛ' },
  { code: 'uz', ja: 'ウズベク語', zh: '乌兹别克语', en: 'Uzbek', native: "o'zbekcha" },
  { code: 'kk', ja: 'カザフ語', zh: '哈萨克语', en: 'Kazakh', native: 'қазақша' },
  { code: 'ky', ja: 'キルギス語', zh: '吉尔吉斯语', en: 'Kyrgyz', native: 'кыргызча' },
  { code: 'hy', ja: 'アルメニア語', zh: '亚美尼亚语', en: 'Armenian', native: 'հայերեն' },
  { code: 'ka', ja: 'ジョージア語', zh: '格鲁吉亚语', en: 'Georgian', native: 'ქართული' },
  { code: 'az', ja: 'アゼルバイジャン語', zh: '阿塞拜疆语', en: 'Azerbaijani', native: 'azərbaycanca' },
  { code: 'et', ja: 'エストニア語', zh: '爱沙尼亚语', en: 'Estonian', native: 'eesti' },
  { code: 'lv', ja: 'ラトビア語', zh: '拉脱维亚语', en: 'Latvian', native: 'latviešu' },
  { code: 'lt', ja: 'リトアニア語', zh: '立陶宛语', en: 'Lithuanian', native: 'lietuvių' },
];

/** 語種判別不能の正準値（v6.1 追補）。従来「その他」に混在していた
    「認識できない文字」を分離した専用値。具体言語と併存可（"日本語/不明"）、
    「無（—）」とだけ互斥。 */
export const UNKNOWN_LANGUAGE = '不明';

/** 筛选下拉用: 予設言語＋不明。旧値「その他」も予設に含まれたまま
    （旧データが筛选できなくなるのを防ぐ）。 */
export const languageFilterValues = (presets: string[] | undefined): string[] =>
  [...(presets ?? []), UNKNOWN_LANGUAGE];

/** 検索: code / ja / zh / en / native のどれでも部分一致（大文字小文字無視）。 */
export function searchLanguages(query: string, exclude: Set<string>): LanguageEntry[] {
  const q = query.trim().toLowerCase();
  if (!q) return [];
  return LANGUAGE_LIST.filter(
    (l) =>
      !exclude.has(l.ja) &&
      (l.code.toLowerCase().startsWith(q) ||
        l.ja.toLowerCase().includes(q) ||
        l.zh.toLowerCase().includes(q) ||
        l.en.toLowerCase().includes(q) ||
        l.native.toLowerCase().includes(q)),
  ).slice(0, 8);
}

/** 提案行の表示名: UI 言語のローカル名（本族語名）。保存は常に ja。 */
export function displayName(l: LanguageEntry, uiLang: string): string {
  const local = uiLang.startsWith('zh') ? l.zh : uiLang.startsWith('en') ? l.en : l.ja;
  return local === l.native ? local : `${local}（${l.native}）`;
}
