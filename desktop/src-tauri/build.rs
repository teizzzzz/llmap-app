fn main() {
    // sidecar（externalBin）の実体名は llmap-backend-<target triple> のため、
    // 実行時の探索用にコンパイル対象の triple を埋め込む。
    println!(
        "cargo:rustc-env=LLMAP_TARGET_TRIPLE={}",
        std::env::var("TARGET").unwrap_or_default()
    );
    tauri_build::build()
}
