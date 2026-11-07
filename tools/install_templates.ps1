# Godot エクスポートテンプレート(.tpz)を %APPDATA%\Godot\export_templates\4.7.2.stable\ へ展開。
# ローカルで build_web.ps1 を使うとき初回だけ必要（CI 側は毎回ランナーに取得するので不要）。
#   1. ブラウザで取得（この PC は HTTPS が proxy 再署名されるためブラウザ推奨）:
#      https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
#   2. tools\install_templates.ps1 -Tpz "<落としたパス>"
param([Parameter(Mandatory)][string]$Tpz)
$ErrorActionPreference = "Stop"

$dest = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable"
$tmp = Join-Path $env:TEMP ("godot_tpl_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force $tmp | Out-Null

$zip = Join-Path $tmp "t.zip"
Copy-Item $Tpz $zip
Expand-Archive $zip -DestinationPath $tmp -Force

$src = Join-Path $tmp "templates"
if (-not (Test-Path $src)) { throw "'.tpz' の中に templates/ が見つからない: $Tpz" }

New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item (Join-Path $src "*") $dest -Recurse -Force
Remove-Item $tmp -Recurse -Force

Write-Host "installed -> $dest"
