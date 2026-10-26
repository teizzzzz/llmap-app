import { useEffect, useMemo, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { enumLabel } from '../../lib/enumLabels';
import { langCode, langColor } from '../../lib/langColors';
import {
  displayName, searchLanguages, UNKNOWN_LANGUAGE,
  type LanguageEntry,
} from '../../lib/languageList';

// B 言語 3 字段（主要言語/補助言語/装飾の言語）専用の入力器。
// **データ契約は不変**: 値は従来どおり日本語名の「/」区切り文字列
// （無は「—」）。ISO 码・検索・不明の分離は UI 内部だけの話で、
// 保存形式・地図・筛选・CSV・旧データには一切影響しない。
//
// 状態モデル（v6.1 追補）:
//   - 具体言語: 複数選択（予設 chip ＋検索追加）。
//   - 不明: 語種判別不能の専用値。具体言語と**併存可**（"日本語/不明"）—
//     従来「その他」に混在していた用法を分離した。採集從寬。
//   - 無（—）: この役割の言語が無い。allowNone の字段のみ。他の全てと互斥。
//   - 「その他」は今後 UI から産出しない（旧データの値は削除可能 chip で表示）。

const splitMulti = (v: string) =>
  v.split(/[/・、,]/).map((s) => s.trim()).filter((s) => s && s !== '—');

export default function LanguageRoleSelector({
  field,
  value,
  presets,
  allowNone,
  disabled,
  onChange,
}: {
  field: string;
  value: string;
  /** schema.enums[field]（正準の予設言語。「その他」はここで除外して表示） */
  presets: string[];
  /** 「無（—）」を許すか（主要言語のみ false） */
  allowNone: boolean;
  /** 文字性が「文字」以外のとき親が true を渡す */
  disabled?: boolean;
  onChange: (v: string) => void;
}) {
  const { t, i18n } = useTranslation();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [active, setActive] = useState(0);
  const [announce, setAnnounce] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);
  const listId = `langsel-list-${field}`;

  const isNone = value.trim() === '—';
  const tokens = useMemo(() => splitMulti(value), [value]);
  const shownPresets = useMemo(
    () => presets.filter((p) => p !== 'その他'), [presets]);
  // 予設外の値（検索追加分＋旧データの自由値・「その他」）。クリックで削除。
  const customTokens = tokens.filter(
    (tk) => !shownPresets.includes(tk) && tk !== UNKNOWN_LANGUAGE);
  const unknownOn = tokens.includes(UNKNOWN_LANGUAGE);

  useEffect(() => {
    if (open) inputRef.current?.focus();
  }, [open]);

  const commit = (next: string[]) => onChange(next.join('/'));

  const toggleToken = (tk: string) => {
    // 「無」選択中に言語を選んだら無を解除して置き換える
    const base = isNone ? [] : tokens;
    commit(base.includes(tk) ? base.filter((x) => x !== tk) : [...base, tk]);
  };

  const toggleNone = () => {
    if (isNone) { onChange(''); return; }
    if (tokens.length > 0) {
      setAnnounce(t('langSel.cleared', { n: tokens.length }));
    }
    onChange('—');
  };

  const suggestions = useMemo(
    () => (open ? searchLanguages(query, new Set(tokens)) : []),
    [open, query, tokens]);
  useEffect(() => setActive(0), [query]);

  const addEntry = (entry: LanguageEntry) => {
    if (!tokens.includes(entry.ja)) commit([...(isNone ? [] : tokens), entry.ja]);
    // 追加後も入力框は開いたまま — 続けて追加できる（要件）。
    setQuery('');
    inputRef.current?.focus();
  };

  const onKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    // IME 組立中の Enter は変換確定であり選択ではない（日中韓の入力で必須）。
    if (e.nativeEvent.isComposing) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActive((a) => Math.min(a + 1, suggestions.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActive((a) => Math.max(a - 1, 0));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (suggestions[active]) addEntry(suggestions[active]);
    } else if (e.key === 'Escape') {
      // 何も追加せず閉じても選択状態は一切変わらない（要件）。
      setOpen(false);
      setQuery('');
    }
  };

  const chip = (
    key: string,
    label: string,
    on: boolean,
    onClick: () => void,
    extra?: { title?: string; removable?: boolean; dashed?: boolean; color?: string },
  ) => (
    <button
      key={key}
      type="button"
      role="checkbox"
      aria-checked={on}
      className={`chip${on ? ' on' : ''}${extra?.dashed ? ' lang-sel-dashed' : ''}`}
      disabled={disabled}
      title={extra?.title}
      onClick={onClick}
    >
      {extra?.color && <i className="sw" style={{ background: extra.color }} />}
      {label}
      {extra?.removable && <span className="lang-sel-x" aria-hidden="true"> ✕</span>}
    </button>
  );

  return (
    <div className="lang-sel">
      <div className="chip-row" role="group" aria-label={t(`fields.${field}`, { defaultValue: field })}>
        {shownPresets.map((p) =>
          chip(p, enumLabel(t, p), !isNone && tokens.includes(p), () => toggleToken(p),
            langCode(p) !== 'other' ? { color: langColor(p) } : undefined))}
        {customTokens.map((tk) =>
          chip(tk, enumLabel(t, tk), true, () => toggleToken(tk),
            { title: t('langSel.remove'), removable: true }))}
        {chip(UNKNOWN_LANGUAGE, enumLabel(t, UNKNOWN_LANGUAGE), unknownOn && !isNone,
          () => toggleToken(UNKNOWN_LANGUAGE),
          { title: t('langSel.unknownHint'), dashed: true })}
        {/* 「＋その他の言語」は選択肢ではなく検索を開く操作ボタン */}
        <button
          type="button"
          className="chip lang-sel-dashed"
          aria-expanded={open}
          disabled={disabled}
          onClick={() => { setOpen((v) => !v); setQuery(''); }}
        >
          {open ? t('langSel.close') : t('langSel.addOther')}
        </button>
      </div>

      {open && !disabled && (
        <div className="lang-sel-search">
          <input
            ref={inputRef}
            role="combobox"
            aria-expanded={suggestions.length > 0}
            aria-controls={listId}
            aria-activedescendant={
              suggestions[active] ? `${listId}-${suggestions[active].code}` : undefined}
            aria-autocomplete="list"
            placeholder={t('langSel.searchPlaceholder')}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={onKeyDown}
          />
          {suggestions.length > 0 && (
            <ul className="lang-sel-list" role="listbox" id={listId}>
              {suggestions.map((s, i) => (
                <li
                  key={s.code}
                  id={`${listId}-${s.code}`}
                  role="option"
                  aria-selected={i === active}
                  className={i === active ? 'active' : ''}
                  onMouseEnter={() => setActive(i)}
                  // click より先に input の blur が走らないよう mousedown で確定
                  onMouseDown={(e) => { e.preventDefault(); addEntry(s); }}
                >
                  {displayName(s, i18n.language)}
                  <span className="muted mono"> {s.code}</span>
                </li>
              ))}
            </ul>
          )}
          {query.trim() !== '' && suggestions.length === 0 && (
            <div className="muted lang-sel-hint">{t('langSel.noMatch')}</div>
          )}
        </div>
      )}

      {allowNone && (
        <div className="chip-row">
          {chip('—', t('langSel.none'), isNone, toggleNone, { title: t('langSel.noneHint') })}
        </div>
      )}

      {disabled && (
        <div className="muted lang-sel-hint">{t('langSel.disabledByTextType')}</div>
      )}
      {/* 互斥による自動クリアは視覚以外にも伝える（読み上げ） */}
      <div aria-live="polite" className="sr-only">{announce}</div>
    </div>
  );
}
