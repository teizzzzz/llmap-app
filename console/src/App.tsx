import { HashRouter, Route, Routes } from 'react-router-dom';
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
export default function App() {
  return (
    <HashRouter>
      <SharedFiltersProvider>
      <Routes>
        <Route element={<AppLayout />}>
          <Route index element={<DashboardPage />} />
          <Route path="database" element={<DatabasePage />} />
          <Route path="map" element={<MapPage />} />
          <Route path="review" element={<ReviewPage />} />
          <Route path="ai" element={<AiProcessingPage />} />
          <Route path="export" element={<ExportPage />} />
          <Route path="settings" element={<SettingsPage />} />
        </Route>
      </Routes>
      </SharedFiltersProvider>
    </HashRouter>
  );
}
