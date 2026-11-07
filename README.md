# godot-web-game-template

Godot 4.7 の 2D ゲームを **GitHub Pages に自動デプロイ**するスターターテンプレ。
`main` に push すると GitHub Actions が Web 書き出しして本番反映する ＝ **PC 不要でスマホからでも更新できる**。

作った経緯・ハマりどころは memory の `web-game-deploy` / `godot-notes`、実例は `suika-game`。

## 新しいゲームを始める

### A. 出先 / スマホ / クラウドの Claude セッションから

```
gh repo create MYGAME --template lalalalasuke-jpg/godot-web-game-template --public --clone
cd MYGAME
gh api -X PUT "repos/{owner}/MYGAME/pages" -f build_type=workflow
# project.godot の config/name を "MYGAME" に変えて
git commit -am "name" && git push
```

数分で `https://lalalalasuke-jpg.github.io/MYGAME/` が立つ（まだ "It works!" の画面）。
あとはコードを push するたび自動で反映。

### B. PC でローカルから

```
tools\new_game.ps1 -Name MYGAME
```

（隣に `MYGAME/` を作って repo 作成・push・Pages 設定までやる）

## 中身

| パス | 役割 |
|---|---|
| `project.godot` | Godot 設定。`config/name` を変えること。720x1280 縦・gl_compatibility・タッチのマウス擬似オフ |
| `export_presets.cfg` | Web プリセット。`thread_support=false`（nothreads）＝ COOP/COEP 不要 |
| `scenes/main.tscn` `main.gd` | 起点。ここから作る |
| `.github/workflows/deploy.yml` | push → Godot ビルド → Pages。`GODOT_VERSION` を変えれば別バージョン |
| `tools/build_web.ps1` | ローカルで書き出し（確認用）。標準版 Godot が必要 |
| `tools/serve_web.py` | `http://127.0.0.1:8099` でローカル確認 |
| `tools/install_templates.ps1` | ローカル書き出しの初回だけ要るエクスポートテンプレを展開 |

## 約束ごと

- **UI 文字列は ASCII のみ**（標準フォントに日本語グリフが無く Web で豆腐になる）。日本語を出すなら日本語フォントを同梱してテーマに設定。
- 書き出しは **標準版 Godot**（mono 版は Web 不可）。エディタは mono でもよいが、開くと `project.godot` に `[dotnet]` が足されるので標準版で書き出す前に消す。
- `index.wasm` が大きい（約38MB）。Cloudflare Pages（25MB/file 制限）は不可、GitHub Pages（100MB/file）を使う。
