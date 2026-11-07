# このテンプレから新しい Godot Web ゲームのリポジトリを作る（PC でのローカル手順）。
# 出先/スマホからは README の「gh repo create --template」ワンライナーを使う。
#
#   tools\new_game.ps1 -Name my-cool-game
#
# やること: 隣に <Name> フォルダを作ってテンプレ内容を展開 → config/name 差替え →
#           git init → GitHub に public リポジトリ作成 & push → Pages を Actions 方式に。
param([Parameter(Mandatory)][string]$Name)
$ErrorActionPreference = "Stop"

$tpl = Split-Path $PSScriptRoot -Parent
$dest = Join-Path (Split-Path $tpl -Parent) $Name
if (Test-Path $dest) { throw "already exists: $dest" }

# コミット済みファイルだけを取り出す（.git / build / .godot は含まれない）
$tar = Join-Path $env:TEMP "$Name.tar"
git -C $tpl archive -o $tar HEAD
New-Item -ItemType Directory -Force $dest | Out-Null
tar -x -f $tar -C $dest
Remove-Item $tar

# config/name を差し替え
$pg = Join-Path $dest "project.godot"
(Get-Content $pg -Raw) -replace 'config/name=".*?"', ('config/name="' + $Name + '"') |
	Set-Content -NoNewline -Encoding utf8 $pg

Push-Location $dest
try {
	git init -b main -q
	git add -A
	git commit -q -m "init from godot-web-game-template"
	gh repo create $Name --source=. --remote=origin --push --public
	gh api -X PUT "repos/{owner}/$Name/pages" -f build_type=workflow | Out-Null
} finally { Pop-Location }

$me = gh api user -q .login
Write-Host ""
Write-Host "done. CI がビルド中 -> https://$me.github.io/$Name/"
Write-Host "ローカルは: cd $dest ; code ."
