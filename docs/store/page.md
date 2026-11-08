# 投稿ページの素材（itch.io / PLiCy 共通）

画像: `docs/store/images/`（`tools/screenshot.gd` の cover / showcase / title / howto / result で作り直せる）
- cover.png … 表紙 630×500（itch.io の Cover image）
- showcase.png・howto.png・result.png・title.png … スクショ 720×1280

投稿用 zip: `powershell -File tools\package_store.ps1` → `build\tiny-lala-farm-web.zip`

## 基本情報

- タイトル: Tiny Lala Farm
- 種類: HTML（ブラウザで遊ぶ）／ 縦画面 720×1280（itch.io の埋め込みサイズは 360×640 か 450×800 で、フルスクリーンボタンあり）
- 対応: PC・スマホのブラウザ（タップ／マウス。PC は矢印キー＋スペースも可）
- 価格: 無料
- ジャンル: シミュレーション（農業・のんびり）

## 紹介文（日本語）

畑を耕して、種をまいて、毎日お水をあげて。
育った野菜を出荷して、お金をためる、小さな農園ゲームです。

- 畑をタップすると、ららすけが歩いていって作業します
- 2つのモード: 決まった日数でいくら稼げる？「日数チャレンジ」／目標金額を何日でためられる？「金額チャレンジ」
- 水やりを忘れると枯れやすく、毎日お世話すると「★品質」や「2個とれる」当たりが出やすくなります
- カブ・トマト・イチゴをそろえて出荷すると「野菜セット」のボーナス
- 稼いだお金で売り地を買って、畑を広げよう（チャレンジの長さで、買うべきかが変わります）

1回 5〜15分くらい。ベスト記録はブラウザに保存されます。

### AI の利用について
このゲームは、ららすけ（企画・ゲームデザイン）と AI（Anthropic の Claude）がいっしょに作りました。
ルールやアイデアはららすけが考え、プログラム・絵（コードで描いた図形）・効果音（コードで作った音）・ゲーム内の文章は AI が作っています。
効果音の「素材」セットは Kenney さんの CC0 素材です。

## Description (English)

Till the soil, plant seeds, and water your crops every day.
Ship your harvest and save up money in this tiny, cozy farming game.
(The in-game text is Japanese only for now.)

- Tap a field and Lala walks over to do the work
- Two modes: how much can you earn in a set number of days? / how fast can you reach a money goal?
- Forget to water and crops may wither; care for them every day for better odds of ★quality or double harvests
- Ship a turnip, a tomato and a strawberry together for a "veggie set" bonus
- Spend your money on new land — whether it pays off depends on the challenge length

About 5–15 minutes per run. Best scores are saved in your browser.

### About AI use
Made together by lalasuke (concept & game design) and an AI, Anthropic's Claude.
lalasuke came up with the rules and ideas; the AI wrote the code, the art (shapes drawn in code), the sound effects (generated in code) and the in-game text.
The alternative "asset" sound set is by Kenney (CC0).

## itch.io の設定メモ

- Kind of project: HTML ／ zip をアップして「This file will be played in the browser」にチェック
- Embed options: Viewport 450×800（縦）／ Mobile friendly にチェック（Orientation: Portrait）／ Fullscreen button にチェック
- SharedArrayBuffer support: チェック不要（スレッドなしの書き出し）
- Genre: Simulation ／ Tags: farming, cozy, casual, cute, short, japanese
- **AI generation disclosure: 「Yes」→ 使ったもの: Code・Graphics・Sound・Text**（正直に全部）
- Language: Japanese（英語の説明文は付ける）
- Visibility: 最初は Draft（下書き）→ 動作確認してから Public

## タグ（PLiCy 向け・日本語）
農業, 育成, のんびり, ほのぼの, 短編, スマホ対応, AI
