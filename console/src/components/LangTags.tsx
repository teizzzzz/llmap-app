import { useTranslation } from 'react-i18next';
import { enumLabel } from '../lib/enumLabels';
import { LANG_COLOR, langCode, splitLangs } from '../lib/langColors';

/** 言語の値（「日本語/英語」）を色つき小方块＋コード（JA EN）で並べる。
    主要 6 言語以外は灰色の方块＋表示名。空・「—」は「—」。 */
export default function LangTags({ value }: { value: string | null | undefined }) {
  const { t } = useTranslation();
  const langs = splitLangs(value);
  if (!langs.length) return <span className="muted">—</span>;
  return (
    <span className="lang-tags">
      {langs.map((l) => {
        const code = langCode(l);
        return (
          <span key={l} className="lang-tag" title={enumLabel(t, l)}>
            <i style={{ background: LANG_COLOR[code] }} />
            {code === 'other' ? enumLabel(t, l) : code.toUpperCase()}
          </span>
        );
      })}
    </span>
  );
}
