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

/// 用户数据目录（desktop-offline-design.md §5 の標準目录）:
///   macOS   ~/Library/Application Support/LLMap
///   Windows %APPDATA%\LLMap
///   Linux   ~/.local/share/LLMap
/// identifier ベースの app_data_dir ではなく OS の data dir + "LLMap" を使う。
/// developer launcher（10B）と同一パスなので、launcher で作ったデータを
/// そのまま桌面 App でも開ける。取得不能時は .llmap-desktop-data/ に fallback
/// （TODO: 正式版では fallback を廃止しエラー画面にする）。
fn resolve_data_dir(app: &tauri::AppHandle) -> PathBuf {
    match app.path().data_dir() {
        Ok(dir) => dir.join("LLMap"),
        Err(_) => PathBuf::from(".llmap-desktop-data"),
    }
}

/// backend sidecar binary を探す。
/// 優先順: ① 環境変数 LLMAP_BACKEND_BIN（開発時の明示指定）
///        ② App 実行ファイルと同じ目录（Tauri externalBin の実体配置先。
///           Windows/Linux は exe 隣、素の名前と target-triple 付きの両方を試す）
///        ③ Tauri resource dir
///        ④ リポジトリ内 backend/dist/llmap-backend（prototype 開発時 fallback）
fn find_backend_binary(app: &tauri::AppHandle) -> Option<PathBuf> {
    let ext = if cfg!(windows) { ".exe" } else { "" };
    let plain = format!("llmap-backend{ext}");
    // build.rs が cargo:rustc-env で埋め込む（Tauri externalBin の命名規則:
    // 例 llmap-backend-x86_64-pc-windows-msvc.exe）
    let with_triple = format!("llmap-backend-{}{ext}", env!("LLMAP_TARGET_TRIPLE"));

    if let Ok(p) = std::env::var("LLMAP_BACKEND_BIN") {
        let p = PathBuf::from(p);
        if p.is_file() {
            return Some(p);
        }
    }
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            for name in [&plain, &with_triple] {
                let p = dir.join(name);
                if p.is_file() {
                    return Some(p);
                }
            }
        }
    }
    if let Ok(res) = app.path().resource_dir() {
        for name in [&plain, &with_triple] {
            let p = res.join(name);
            if p.is_file() {
                return Some(p);
            }
        }
    }
    // prototype: desktop/src-tauri から見た相対と、カレントからの相対を試す
    for base in ["../../backend/dist", "../backend/dist", "backend/dist"] {
        let p = PathBuf::from(base).join(&plain);
        if p.is_file() {
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
    var tries = 0, wasDown = false;
    var timer = setInterval(function () {{
      tries++;
      fetch(api + '/health').then(function (r) {{
        if (!r.ok) return;
        clearInterval(timer);
        if (wasDown) location.reload();
        else el.remove();
      }}).catch(function () {{ wasDown = true; }});
      if (tries > 75) {{ clearInterval(timer); fail('Backend did not become ready within 15s.'); }}
    }}, 200);
  }});
}})();
"#
    )
}

fn main() {
    tauri::Builder::default()
        .manage(BackendChild(Mutex::new(None)))
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
                for _ in 0..75 {
                    if health_ok(port) {
                        println!("[llmap-desktop] backend ready on 127.0.0.1:{port}");
                        return;
                    }
                    std::thread::sleep(Duration::from_millis(200));
                }
                eprintln!("[llmap-desktop] backend did not become ready within 15s");
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
                    event: WindowEvent::CloseRequested { .. },
                    ..
                } => shutdown_backend(app),
                RunEvent::ExitRequested { .. } | RunEvent::Exit => shutdown_backend(app),
                _ => {}
            }
        });
}
