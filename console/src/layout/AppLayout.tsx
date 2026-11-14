import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';

// 顶栏（全局検索）は廃止: 検索は各ページの筛选栏で、対象範囲を明示して行う
// （資料庫の検索と重複していたため）。縦の余白も 1 段ぶん広がる。
export default function AppLayout() {
  return (
    <div className="app">
      <Sidebar />
      <div className="main">
        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
