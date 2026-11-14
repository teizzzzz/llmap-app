import { HashRouter, Navigate, Route, Routes } from 'react-router-dom';
import { SharedFiltersProvider } from './hooks/useSharedFilters';
import AppLayout from './layout/AppLayout';
import AiProcessingPage from './pages/AiProcessingPage';
import DashboardPage from './pages/DashboardPage';
import DatabasePage from './pages/DatabasePage';
import ExportPage from './pages/ExportPage';
import MapPage from './pages/MapPage';
import ReviewPage from './pages/ReviewPage';
import SettingsPage from './pages/SettingsPage';

// HashRouter: 静的サーバ/file:// でもリロードで 404 にならない（ローカル運用前提）。
// 既定の入口は資料庫（写真）。旧来の概覧（仪表盘）は /overview に移した。
// 旧 `#/` の深いリンクは資料庫へ届く（概覧は侧栏から常に辿れる）。
export default function App() {
  return (
    <HashRouter>
      <SharedFiltersProvider>
        <Routes>
          <Route element={<AppLayout />}>
            <Route index element={<Navigate to="/database" replace />} />
            <Route path="database" element={<DatabasePage />} />
            <Route path="review" element={<ReviewPage />} />
            <Route path="map" element={<MapPage />} />
            <Route path="export" element={<ExportPage />} />
            <Route path="ai" element={<AiProcessingPage />} />
            <Route path="overview" element={<DashboardPage />} />
            {/* 探索区の本体は AppLayout が保持する（ここは経路だけ）。 */}
            <Route path="explore" element={null} />
            <Route path="settings" element={<SettingsPage />} />
            <Route path="*" element={<Navigate to="/database" replace />} />
          </Route>
        </Routes>
      </SharedFiltersProvider>
    </HashRouter>
  );
}
