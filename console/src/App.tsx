import { HashRouter, Navigate, Route, Routes } from 'react-router-dom';
import { SharedFiltersProvider } from './hooks/useSharedFilters';
import { UnsavedGuardProvider } from './lib/unsavedGuard';
import AppLayout from './layout/AppLayout';
import AiProcessingPage from './pages/AiProcessingPage';
import DashboardPage from './pages/DashboardPage';
import DatabasePage from './pages/DatabasePage';
import ExportPage from './pages/ExportPage';
import CanvasPage from './pages/CanvasPage';
import ReviewPage from './pages/ReviewPage';
import SettingsPage from './pages/SettingsPage';

// HashRouter: 静的サーバ/file:// でもリロードで 404 にならない（ローカル運用前提）。
// 既定の入口は資料庫（写真）。旧来の概覧（仪表盘）は /overview に移した。
// 旧 `#/` の深いリンクは資料庫へ届く（概覧は侧栏から常に辿れる）。
export default function App() {
  return (
    <HashRouter>
      <SharedFiltersProvider>
        <UnsavedGuardProvider>
        <Routes>
          <Route element={<AppLayout />}>
            {/* 入口は首页（概要＋主题）。旧い /overview・/themes も首页へ。 */}
            <Route index element={<Navigate to="/home" replace />} />
            <Route path="home" element={<DashboardPage />} />
            <Route path="database" element={<DatabasePage />} />
            <Route path="review" element={<ReviewPage />} />
            {/* 地図・探索は資料庫の視図に入った。旧い深いリンクは対応する視図へ。 */}
            <Route path="map" element={<Navigate to="/database?view=map" replace />} />
            <Route path="explore" element={<Navigate to="/database?view=cloud" replace />} />
            <Route path="themes" element={<Navigate to="/home" replace />} />
            <Route path="canvas" element={<CanvasPage />} />
            <Route path="export" element={<ExportPage />} />
            <Route path="ai" element={<AiProcessingPage />} />
            <Route path="overview" element={<Navigate to="/home" replace />} />
            <Route path="settings" element={<SettingsPage />} />
            <Route path="*" element={<Navigate to="/database" replace />} />
          </Route>
        </Routes>
        </UnsavedGuardProvider>
      </SharedFiltersProvider>
    </HashRouter>
  );
}
