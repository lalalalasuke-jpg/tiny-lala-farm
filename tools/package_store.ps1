# 投稿サイト（itch.io / PLiCy など）用の zip を作る。
# 使い方: powershell -File tools\package_store.ps1
# 出力: build\tiny-lala-farm-web.zip（zip の一番上に index.html がある形。サイトの「ブラウザで遊ぶ」にそのまま上げられる）
# GitHub Pages 用（tools\build_web.ps1）と違って、書き出し設定「Web (store)」を使う:
#   PWA（Service Worker）なし（PLiCy は禁止）、WebGL の preserveDrawingBuffer を true（PLiCy の決まり）。
# noindex は付けず、クレジットとライセンスの文書を同梱する。
$ErrorActionPreference = "Stop"

$godot = "C:\Users\PC_User\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
$proj = Split-Path $PSScriptRoot -Parent
$buildDir = Join-Path $proj "build"
$out = Join-Path $buildDir "store"
$zip = Join-Path $buildDir "tiny-lala-farm-web.zip"

if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null
New-Item -ItemType File -Force (Join-Path $buildDir ".gdignore") | Out-Null

& $godot --headless --path $proj --export-release "Web (store)" "build/store/index.html"
if ($LASTEXITCODE -ne 0) { throw "エクスポート失敗 (exit $LASTEXITCODE)。テンプレート未インストールなら tools\install_templates.ps1" }

Copy-Item (Join-Path $proj "docs\store\CREDITS.txt") $out
Copy-Item (Join-Path $proj "docs\store\LICENSE-godot.txt") $out
Copy-Item (Join-Path $proj "fonts\OFL.txt") $out
Copy-Item (Join-Path $proj "sfx\kenney\LICENSE-rpg.txt") (Join-Path $out "LICENSE-kenney-rpg.txt")
Copy-Item (Join-Path $proj "sfx\kenney\LICENSE-interface.txt") (Join-Path $out "LICENSE-kenney-interface.txt")

if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $out "*") -DestinationPath $zip
$mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host "done -> $zip ($mb MB)"
