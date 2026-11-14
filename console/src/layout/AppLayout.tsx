import { Outlet } from 'react-router-dom';
import { ExploreProvider } from '../components/explore/ExploreContext';
import ExploreHost from '../components/explore/ExploreHost';
import RecordDrawer from '../components/record/RecordDrawer';
import { RecordDrawerProvider } from '../components/record/drawerContext';
import Sidebar from './Sidebar';

// 顶栏（全局検索）は廃止: 検索は各ページの筛选栏で、対象範囲を明示して行う。
// 探索の画布（iframe）はここで 1 つだけ保持し、資料庫の照片云・色彩、主题、関係画布の
// 枠の上に重ねる（ページを行き来しても読み直さない —— 位置・条件・関係画布が残る）。
// 記録の详情（抽屉）も 1 つだけ。どの画面から開いても同じものを使う。
export default function AppLayout() {
  return (
    <RecordDrawerProvider>
      <ExploreProvider>
        <div className="app">
          <Sidebar />
          <div className="main">
            <main className="content">
              <Outlet />
            </main>
          </div>
        </div>
        <ExploreHost />
        <RecordDrawer />
      </ExploreProvider>
    </RecordDrawerProvider>
  );
}
