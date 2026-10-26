import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router-dom';
import useSharedFilters from '../hooks/useSharedFilters';

/** 顶部栏: 全局検索だけ。Enter で数据库へ移動し、関键词を共有筛选に入れる。 */
export default function Topbar() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { patch } = useSharedFilters();
  const [q, setQ] = useState('');
  return (
    <header className="topbar">
      <span className="spacer" />
      <form
        className="topbar-search"
        onSubmit={(e) => {
          e.preventDefault();
          patch({ q: q.trim() || undefined });
          navigate('/database');
        }}
      >
        <input placeholder={t('topbar.search')} value={q} onChange={(e) => setQ(e.target.value)} />
      </form>
    </header>
  );
}
