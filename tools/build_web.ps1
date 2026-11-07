# ローカルで Web 書き出し（本番は GitHub Actions が自動でやる。これは確認用）。
$ErrorActionPreference = "Stop"

# 書き出しは「標準版」Godot を使う（mono 版は Web 書き出し不可）
$godot = "C:\Users\PC_User\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
$proj = Split-Path $PSScriptRoot -Parent
$buildDir = Join-Path $proj "build"
$out = Join-Path $buildDir "web"

if (Test-Path $buildDir) { Remove-Item $buildDir -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null
New-Item -ItemType File -Force (Join-Path $buildDir ".gdignore") | Out-Null

& $godot --headless --path $proj --export-release "Web" "build/web/index.html"
if ($LASTEXITCODE -ne 0) { throw "エクスポート失敗 (exit $LASTEXITCODE)。テンプレート未インストールなら tools\install_templates.ps1" }

New-Item -ItemType File -Force (Join-Path $out ".nojekyll") | Out-Null
$idx = Join-Path $out "index.html"
(Get-Content $idx -Raw) -replace '</head>', "  <meta name=`"robots`" content=`"noindex`">`n</head>" |
	Set-Content -NoNewline -Encoding utf8 $idx

Write-Host "done -> $out   (python tools\serve_web.py で確認)"
