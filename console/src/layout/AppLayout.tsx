import { useEffect, useState } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import { ExploreProvider } from '../components/explore/ExploreContext';
import ExploreHost from '../components/explore/ExploreHost';
import Sidebar from './Sidebar';

// 顶栏（全局検索）は廃止: 検索は各ページの筛选栏で、対象範囲を明示して行う
// （資料庫の検索と重複していたため）。縦の余白も 1 段ぶん広がる。
// 探索区（/explore）は一度開いたら隠すだけで保持する —— 研究のページと
// 行き来しても、探索の閲覧位置・範囲・接龙の画板がそのまま残る。
export default function AppLayout() {
  const { pathname } = useLocation();
  const exploring = pathname.startsWith('/explore');
  const [exploreMounted, setExploreMounted] = useState(exploring);
  useEffect(() => { if (exploring) setExploreMounted(true); }, [exploring]);

  return (
    <ExploreProvider>
    <div className="app">
      <Sidebar />
      <div className="main">
        {!exploring && (
          <main className="content">
            <Outlet />
          </main>
        )}
        {exploreMounted && <ExploreHost />}
      </div>
    </div>
    </ExploreProvider>
  );
}
