// LLMap Desktop shell prototype (Step 10D)。
// 職責は「包装」だけ: 用户数据目录の用意 → llmap-backend sidecar の起動 →
// /health 待機（窗口内オーバーレイ）→ Console(React) の表示 → 終了時の回収。
// Console は console/、backend は backend/ の職責のまま変更しない。
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::fs;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::Mutex;
use std::time::Duration;

use tauri::{Manager, RunEvent, WebviewUrl, WebviewWindowBuilder, WindowEvent};

/// 終了時に kill するため backend 子プロセスを保持する。
struct BackendChild(Mutex<Option<Child>>);

/// backend を**プロセスグループごと**終了させる。
/// PyInstaller onefile は「bootloader 親＋server 子」の2プロセスで動くため、
/// Child::kill() だけでは server 子プロセスが残留する（実測で確認）。
fn kill_backend(mut child: Child) {
    #[cfg(unix)]
    unsafe {
        // spawn 時に process_group(0) で独立グループにしてある。
        libc::kill(-(child.id() as i32), libc::SIGTERM);
        std::thread::sleep(Duration::from_millis(300));
        libc::kill(-(child.id() as i32), libc::SIGKILL);
    }
    #[cfg(windows)]
    {
        // /T で子プロセスツリーごと終了させる。
        let _ = Command::new("taskkill")
            .args(["/PID", &child.id().to_string(), "/T", "/F"])
            .output();
    }
    let _ = child.kill();
    let _ = child.wait();
    println!("[llmap-desktop] backend stopped.");
}

/// 窓を閉じる前に研究台へ未保存の確認を求めるための状態。
/// allowed: 研究台が「閉じてよい」と返した。last_ask: 直前に尋ねた時刻
/// （4 秒以内にもう一度 × を押したら、応答の無い画面でも閉じられるようにする）。
#[derive(Default)]
struct CloseGate {
    allowed: std::sync::atomic::AtomicBool,
    last_ask: Mutex<Option<std::time::Instant>>,
}

/// 研究台（console）から: 未保存の確認が済んだので窓を閉じる。
#[tauri::command]
fn llmap_confirm_close(app: tauri::AppHandle, window: tauri::Window) {
    app.state::<CloseGate>().allowed.store(true, std::sync::atomic::Ordering::SeqCst);
    let _ = window.close();
}

/// state から backend を取り出して回収する（多重呼び出しは no-op）。
fn shutdown_backend(app: &tauri::AppHandle) {
    if let Some(child) = app.state::<BackendChild>().0.lock().unwrap().take() {
        kill_backend(child);
    }
}

/// 8000 から順に空き端口を探す（見つからなければ 8000 のまま試す）。
fn find_free_port() -> u16 {
    for port in 8000u16..8020 {
        if TcpListener::bind(("127.0.0.1", port)).is_ok() {
            return port;
        }
    }
    8000
}

/// 用户数据目录。決定順（Step 17 で①を追加）:
///   ① 設定ファイル <OS config dir>/LLMap/config.json の {"dataDir": "..."}
///      — 写真データを D: や外付けへ置きたいユーザー向け。編集後は再起動で反映。
///      Console の Settings > ストレージ に現在の実効パスが表示される。
///      （UI からの変更＋既存データ移行ウィザードは別 Step。）
///   ② 既定: OS data dir + "LLMap"
///      macOS   ~/Library/Application Support/LLMap
///      Windows %APPDATA%\LLMap
///      Linux   ~/.local/share/LLMap
///      identifier ベースの app_data_dir ではなく OS data dir + "LLMap"
///      （developer launcher 10B と同一パス）。
///   ③ 取得不能時は .llmap-desktop-data/ に fallback
///      （TODO: 正式版では fallback を廃止しエラー画面にする）。
fn resolve_data_dir(app: &tauri::AppHandle) -> PathBuf {
    if let Ok(cfg_base) = app.path().config_dir() {
        let cfg = cfg_base.join("LLMap").join("config.json");
        if let Ok(text) = fs::read_to_string(&cfg) {
            match serde_json::from_str::<serde_json::Value>(&text) {
                Ok(v) => {
                    if let Some(dir) =
                        v.get("dataDir").and_then(|d| d.as_str())
                    {
                        let dir = dir.trim();
                        if !dir.is_empty() {
                            println!(
                                "[llmap-desktop] data dir from config: {dir}");
                            return PathBuf::from(dir);
                        }
                    }
                }
                Err(e) => eprintln!(
                    "[llmap-desktop] config.json parse error (ignored): {e}"),
            }
        }
    }
    match app.path().data_dir() {
        Ok(dir) => dir.join("LLMap"),
        Err(_) => PathBuf::from(".llmap-desktop-data"),
    }
}

/// backend sidecar binary を探す。
/// 優先順: ① 環境変数 LLMAP_BACKEND_BIN（開発時の明示指定）
///        ② App 実行ファイルと同じ目录（Tauri externalBin の実体配置先。
///           Windows/Linux は exe 隣、素の名前と target-triple 付きの両方を試す）
///        ③ Tauri resource dir（macOS one-dir は
///           Resources/llmap-backend/llmap-backend に置かれる）
///        ④ リポジトリ内 backend/dist（prototype 開発時 fallback）
/// 各目录では 3 つの形を試す:
///   llmap-backend（素の名前）/ llmap-backend-<triple>（externalBin 規則）/
///   llmap-backend/llmap-backend（one-dir 配布。macOS — Step 10E 実測で
///   one-file は起動毎に 15〜25 秒かかるため one-dir を使う）
fn find_backend_binary(app: &tauri::AppHandle) -> Option<PathBuf> {
    let ext = if cfg!(windows) { ".exe" } else { "" };
    let plain = format!("llmap-backend{ext}");
    // build.rs が cargo:rustc-env で埋め込む（Tauri externalBin の命名規則:
    // 例 llmap-backend-x86_64-pc-windows-msvc.exe）
    let with_triple = format!("llmap-backend-{}{ext}", env!("LLMAP_TARGET_TRIPLE"));
    let candidates = [
        PathBuf::from(&plain),
        PathBuf::from(&with_triple),
        PathBuf::from("llmap-backend").join(&plain),
    ];
    let find_in = |dir: &std::path::Path| -> Option<PathBuf> {
        candidates.iter().map(|rel| dir.join(rel)).find(|p| p.is_file())
    };

    if let Ok(p) = std::env::var("LLMAP_BACKEND_BIN") {
        let p = PathBuf::from(p);
        if p.is_file() {
            return Some(p);
        }
    }
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            if let Some(p) = find_in(dir) {
                return Some(p);
            }
        }
    }
    if let Ok(res) = app.path().resource_dir() {
        if let Some(p) = find_in(&res) {
            return Some(p);
        }
    }
    // prototype: desktop/src-tauri から見た相対と、カレントからの相対を試す
    for base in ["../../backend/dist", "../backend/dist", "backend/dist"] {
        if let Some(p) = find_in(std::path::Path::new(base)) {
            return Some(p.canonicalize().unwrap_or(p));
        }
    }
    None
}

/// 依存クレート無しの最小 HTTP GET /health（200 なら true）。
fn health_ok(port: u16) -> bool {
    let addr = std::net::SocketAddr::from(([127, 0, 0, 1], port));
    let Ok(mut stream) = TcpStream::connect_timeout(&addr, Duration::from_millis(500)) else {
        return false;
    };
    let _ = stream.set_read_timeout(Some(Duration::from_millis(800)));
    if stream
        .write_all(b"GET /health HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n")
        .is_err()
    {
        return false;
    }
    let mut buf = [0u8; 64];
    match stream.read(&mut buf) {
        Ok(n) => String::from_utf8_lossy(&buf[..n]).contains("200"),
        Err(_) => false,
    }
}

/// 起動オーバーレイ＋API 注入スクリプト。ページ読込前に実行される。
/// backend が ready になるまで「Starting…」を表示し、ready になった瞬間に
/// 一度だけ reload（初回描画時の offline 表示を消すため）。失敗時は原因を列挙。
///
/// TODO(i18n): Desktop native loading/error overlay i18n is deferred.
/// この overlay は Console(React) が読み込まれる**前**に出る素の注入スクリプト
/// なので、Console 側の i18next（Step 11: ja/zh/en）には乗れない。当面は英語の
/// まま維持し、対応する場合は localStorage の 'llmap.console.language' を読んで
/// ここで文言を出し分ける。
fn boot_script(port: u16, boot_error: Option<&str>) -> String {
    let err_js = match boot_error {
        Some(e) => format!("window.__LLMAP_BOOT_ERROR__ = {};", serde_json::to_string(e).unwrap()),
        None => String::new(),
    };
    format!(
        r#"
window.__LLMAP_API_BASE_URL__ = 'http://127.0.0.1:{port}';
{err_js}
(function () {{
  function ready(cb) {{
    if (document.body) cb();
    else document.addEventListener('DOMContentLoaded', cb);
  }}
  ready(function () {{
    var api = window.__LLMAP_API_BASE_URL__;
    var el = document.createElement('div');
    el.style.cssText = 'position:fixed;inset:0;background:#f7f4ee;z-index:99999;' +
      'display:flex;flex-direction:column;align-items:center;justify-content:center;' +
      'gap:10px;font-family:system-ui,sans-serif;color:#2b2723';
    el.innerHTML = '<div style="font-weight:800;font-size:22px">LLMap</div>' +
      '<div id="__llmap_boot_msg">Starting LLMap local backend…</div>';
    document.body.appendChild(el);
    function fail(reason) {{
      document.getElementById('__llmap_boot_msg').innerHTML =
        '<b>Failed to start LLMap backend.</b><br><br>' + reason +
        '<br><br>Possible causes: backend binary missing · port in use · ' +
        'data directory not writable.<br>Logs: LLMap data dir /logs/backend.log';
    }}
    if (window.__LLMAP_BOOT_ERROR__) {{ fail(window.__LLMAP_BOOT_ERROR__); return; }}
    var tries = 0, wasDown = false, busy = false, lastErr = '';
    // 1 回の確認は 1.5 秒で打ち切る（応答の無い fetch が残り続けて、以後の確認が
    // 永久に届かず「起動中」のまま固まるのを防ぐ）。
    function check() {{
      if (busy) return;
      busy = true;
      var ctl = window.AbortController ? new AbortController() : null;
      var to = setTimeout(function () {{ if (ctl) ctl.abort(); }}, 1500);
      fetch(api + '/health', ctl ? {{ signal: ctl.signal, cache: 'no-store' }} : {{ cache: 'no-store' }})
        .then(function (r) {{
          if (!r.ok) {{ lastErr = 'HTTP ' + r.status; return; }}
          clearInterval(timer);
          if (wasDown) location.reload();
          else el.remove();
        }})
        .catch(function (e) {{ wasDown = true; lastErr = String(e && e.message || e); }})
        .then(function () {{ clearTimeout(to); busy = false; }});
    }}
    var timer = setInterval(function () {{
      tries++;
      check();
      // 初回起動は OS のコード署名検証（macOS）や杀毒扫描（Windows）で
      // 数十秒かかることがあるため 60 秒まで待つ。10 秒過ぎたら文言で案内し、
      // 再読込ボタンと最後のエラーを出す（開発中の再読込で固まった場合の逃げ道）。
      if (tries === 50) {{
        var m = document.getElementById('__llmap_boot_msg');
        m.innerHTML = 'Still starting… the first launch can take up to a minute.' +
          '<div id="__llmap_boot_err" style="margin-top:8px;font-size:12px;color:#8e8e8e"></div>' +
          '<button id="__llmap_boot_reload" style="margin-top:12px;padding:6px 14px;' +
          'border:0;border-radius:999px;background:#0f0f0e;color:#fff;cursor:pointer">Reload</button>';
        document.getElementById('__llmap_boot_reload').onclick = function () {{ location.reload(); }};
      }}
      if (tries >= 50 && lastErr) {{
        var er = document.getElementById('__llmap_boot_err');
        if (er) er.textContent = 'Last check: ' + lastErr + ' · ' + api;
      }}
      if (tries > 300) {{ clearInterval(timer); fail('Backend did not become ready within 60s. Last check: ' + lastErr); }}
    }}, 200);
  }});
}})();
"#
    )
}

fn main() {
    tauri::Builder::default()
        .manage(BackendChild(Mutex::new(None)))
        .manage(CloseGate::default())
        .invoke_handler(tauri::generate_handler![llmap_confirm_close])
        .setup(|app| {
            let handle = app.handle();
            let port = find_free_port();

            // 1) 用户数据目录（logs/ も先に作る）
            let data_dir = resolve_data_dir(handle);
            let mut boot_error: Option<String> = None;
            if let Err(e) = fs::create_dir_all(data_dir.join("logs")) {
                boot_error = Some(format!("data directory not writable: {e}"));
            }

            // 2) backend sidecar 起動
            if boot_error.is_none() {
                match find_backend_binary(handle) {
                    Some(bin) => {
                        let log = fs::File::create(data_dir.join("logs/backend.log"));
                        let mut cmd = Command::new(&bin);
                        cmd.env("LLMAP_DATA_DIR", &data_dir)
                            .env("LLMAP_HOST", "127.0.0.1")
                            .env("LLMAP_PORT", port.to_string())
                            .args(["--host", "127.0.0.1", "--port", &port.to_string()]);
                        // 独立プロセスグループにして、終了時にグループごと回収できる
                        // ようにする（PyInstaller onefile の親子プロセス対策）。
                        #[cfg(unix)]
                        {
                            use std::os::unix::process::CommandExt;
                            cmd.process_group(0);
                        }
                        match log {
                            Ok(f) => {
                                let f2 = f.try_clone().ok();
                                cmd.stdout(Stdio::from(f));
                                if let Some(f2) = f2 {
                                    cmd.stderr(Stdio::from(f2));
                                }
                            }
                            Err(_) => {
                                cmd.stdout(Stdio::null()).stderr(Stdio::null());
                            }
                        }
                        match cmd.spawn() {
                            Ok(child) => {
                                println!("[llmap-desktop] backend: {} (port {port})", bin.display());
                                println!("[llmap-desktop] data dir: {}", data_dir.display());
                                *app.state::<BackendChild>().0.lock().unwrap() = Some(child);
                            }
                            Err(e) => boot_error = Some(format!("failed to spawn backend: {e}")),
                        }
                    }
                    None => {
                        boot_error = Some(
                            "backend binary missing (build it: ./scripts/build-backend-binary.sh, \
                             or set LLMAP_BACKEND_BIN)".into(),
                        )
                    }
                }
            }

            // 3) 窗口作成（注入スクリプトが API URL 設定＋起動オーバーレイを担当）
            WebviewWindowBuilder::new(app, "main", WebviewUrl::App("index.html".into()))
                .title("LLMap Research Console")
                .inner_size(1440.0, 900.0)
                .initialization_script(&boot_script(port, boot_error.as_deref()))
                .build()?;

            // 4) 参考ログ: health ready をコンソールにも出す（UI はオーバーレイが担当）
            std::thread::spawn(move || {
                for _ in 0..300 {
                    if health_ok(port) {
                        println!("[llmap-desktop] backend ready on 127.0.0.1:{port}");
                        return;
                    }
                    std::thread::sleep(Duration::from_millis(200));
                }
                eprintln!("[llmap-desktop] backend did not become ready within 60s");
            });

            // 開発/ヘッドレステスト用: 指定 ms 後に正常終了する
            // （通常終了と同じ経路で backend 回収が走ることを CI で検証できる）。
            if let Ok(ms) = std::env::var("LLMAP_AUTOEXIT_MS") {
                if let Ok(ms) = ms.parse::<u64>() {
                    let h = app.handle().clone();
                    std::thread::spawn(move || {
                        std::thread::sleep(Duration::from_millis(ms));
                        println!("[llmap-desktop] LLMAP_AUTOEXIT_MS reached, exiting");
                        h.exit(0);
                    });
                }
            }

            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building LLMap desktop shell")
        .run(|app, event| {
            // 5) 終了時に backend を回収する。窗口が閉じられた時点（CloseRequested）
            //    でも先に回収しておく — その後の描画層の異常終了でも残留させない。
            match event {
                RunEvent::WindowEvent {
                    label,
                    event: WindowEvent::CloseRequested { api, .. },
                    ..
                } => {
                    // 研究台に未保存の変更があれば先に確認する（保存して閉じる／破棄／キャンセル）。
                    // 研究台は確認後に llmap_confirm_close を呼ぶ。古い画面・応答の無い画面でも
                    // 閉じられるよう、4 秒以内の 2 回目の × はそのまま閉じる。
                    let gate = app.state::<CloseGate>();
                    let now = std::time::Instant::now();
                    let mut last = gate.last_ask.lock().unwrap();
                    let again = last.map_or(false, |t| now.duration_since(t) < Duration::from_secs(4));
                    if !gate.allowed.load(std::sync::atomic::Ordering::SeqCst) && !again {
                        if let Some(w) = app.get_webview_window(&label) {
                            *last = Some(now);
                            api.prevent_close();
                            let _ = w.eval(
                                "(window.__llmapRequestClose ? window.__llmapRequestClose()                                  : window.__TAURI_INTERNALS__ && window.__TAURI_INTERNALS__.invoke('llmap_confirm_close'))",
                            );
                            return;
                        }
                    }
                    drop(last);
                    shutdown_backend(app)
                }
                RunEvent::ExitRequested { .. } | RunEvent::Exit => shutdown_backend(app),
                _ => {}
            }
        });
}
