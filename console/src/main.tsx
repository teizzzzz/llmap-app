import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './i18n'; // UI 言語の初期化（既定 ja-JP）。App より先に読み込む。
import App from './App';
import './styles/global.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
