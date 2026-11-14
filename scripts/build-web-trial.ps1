# LLMap Web 試用版（手機アプリのブラウザ版）をビルドし、NAS に置ける形にまとめる。
#   .\scripts\build-web-trial.ps1 [-BaseHref /] [-ExploreData <dir>]
# 出力: dist\llmap-trial-nas\（web・docker-compose.yml・nginx.conf・README）と dist\llmap-trial-nas.zip
# 注意: flutter は必ず大文字ドライブ（F:\）の経路で実行する。小文字の経路だと
#       生成済みの l10n ファイルが消えることがある（消えたら git から戻す）。
param(
    [string]$BaseHref = '/',
    # 見本の探索データ（data/data.js・data/atlas.webp・thumbs/）。scripts/make_trial_explore_data.py で作る。
    [string]$ExploreData = ''
)
$ErrorActionPreference = 'Stop'
$RepoRoot = (Split-Path -Parent $PSScriptRoot)
$RepoRoot = $RepoRoot.Substring(0, 1).ToUpper() + $RepoRoot.Substring(1)
$App = Join-Path $RepoRoot 'app'
$Out = Join-Path $RepoRoot 'dist\llmap-trial-nas'

Push-Location $App
try {
    # flutter は警告を stderr に出す。それで止まらないよう、ここだけ継続にして終了コードで判定する。
    $ErrorActionPreference = 'Continue'
    & flutter build web --release --no-wasm-dry-run --base-href $BaseHref
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($code -ne 0) { throw 'flutter build web failed' }
}
finally {
    Pop-Location
    # ビルドで生成 l10n が書き換わる／消えることがあるので、リポジトリの版に戻す。
    & git -C $RepoRoot checkout -- app/lib/l10n
}

if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
New-Item -ItemType Directory -Force -Path $Out | Out-Null
Copy-Item -Recurse (Join-Path $App 'build\web') (Join-Path $Out 'web')
Copy-Item (Join-Path $RepoRoot 'deploy\nas-trial\*') $Out

# 古い版が CDN・ブラウザのキャッシュに残らないよう、スクリプトの URL にビルド時刻を付ける
# （index.html はキャッシュされないので、開くたびに新しい URL を指す）。
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$f = Join-Path $Out 'web\index.html'
$s = [IO.File]::ReadAllText($f, $utf8).Replace('src="flutter_bootstrap.js"', "src=`"flutter_bootstrap.js?v=$stamp`"")
[IO.File]::WriteAllText($f, $s, $utf8)
$f = Join-Path $Out 'web\flutter_bootstrap.js'
$s = [IO.File]::ReadAllText($f, $utf8).Replace('"mainJsPath":"main.dart.js"', "`"mainJsPath`":`"main.dart.js?v=$stamp`"")
[IO.File]::WriteAllText($f, $s, $utf8)

if ($ExploreData -and (Test-Path $ExploreData)) {
    Copy-Item -Recurse $ExploreData (Join-Path $Out 'web\explore-data')
    Write-Host "[trial] explore data: $ExploreData"
} else {
    Write-Host '[trial] 見本の探索データなし（-ExploreData で指定。探索タブは空になります）' -ForegroundColor Yellow
}

$Zip = Join-Path $RepoRoot 'dist\llmap-trial-nas.zip'
if (Test-Path $Zip) { Remove-Item -Force $Zip }
# コピー直後はウイルス対策ソフトなどがファイルを掴んでいることがある。少し待って数回やり直す。
$done = $false
foreach ($try in 1..4) {
    Start-Sleep -Seconds 3
    try {
        Compress-Archive -Path (Join-Path $Out '*') -DestinationPath $Zip -Force -ErrorAction Stop
        $done = $true
        break
    } catch {
        Write-Host "[trial] zip retry $try ..."
    }
}
if (-not $done) { throw 'zip の作成に失敗しました（dist\llmap-trial-nas はできています）' }
Write-Host "[trial] done: $Out"
Write-Host "[trial] zip : $Zip"
