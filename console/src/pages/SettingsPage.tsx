import { API_BASE_URL } from '../api/client';

export default function SettingsPage() {
  return (
    <>
      <div className="page-header">
        <h1>Settings</h1>
        <p>Console configuration. Kept minimal — no accounts, no permissions.</p>
      </div>
      <div className="card">
        <h3 style={{ marginTop: 0 }}>Backend URL</h3>
        <p>
          Current: <code>{API_BASE_URL}</code>
        </p>
        <p className="muted">
          To change it, create <code>console/.env</code> with{' '}
          <code>VITE_API_BASE_URL=http://host:port</code> (see <code>.env.example</code>) and
          restart <code>npm run dev</code>. An in-app switcher is planned for a later step.
        </p>
      </div>
    </>
  );
}
