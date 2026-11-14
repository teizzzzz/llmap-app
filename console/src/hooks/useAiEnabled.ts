import { useCallback, useEffect, useState } from 'react';

// AI 機能を使うかどうか（この端末の表示の好み）。後端の設定・鍵・既存の AI 結果・
// 実行中のジョブには一切触れない —— 切ると AI の操作入口を隠すだけ。
// 既定は「使う」（従来どおりの表示）。
const KEY = 'llmap.aiEnabled';
const EVENT = 'llmap-ai-pref';

function read(): boolean {
  try {
    return localStorage.getItem(KEY) !== '0';
  } catch {
    return true;
  }
}

/** [AI を使うか, 変更する]。変更は同じ画面の他の部品にもすぐ反映される。 */
export default function useAiEnabled(): [boolean, (on: boolean) => void] {
  const [on, setOn] = useState(read);
  useEffect(() => {
    const sync = () => setOn(read());
    window.addEventListener(EVENT, sync);
    window.addEventListener('storage', sync);
    return () => {
      window.removeEventListener(EVENT, sync);
      window.removeEventListener('storage', sync);
    };
  }, []);
  const set = useCallback((v: boolean) => {
    try { localStorage.setItem(KEY, v ? '1' : '0'); } catch { /* 表示だけは切り替える */ }
    setOn(v);
    window.dispatchEvent(new Event(EVENT));
  }, []);
  return [on, set];
}
