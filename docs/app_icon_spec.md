# Novelmark アイコン仕様書

## コンセプト
しおり（bookmark）の形状をベースに「N」のモノグラムを配置。  
ブランド名 Novelmark のBOOKMARK由来を視覚的に表現する。

---

## 形状

- **ベース形状**: 縦長角丸矩形（比率 約 5:7）
  - 上辺・左辺・右辺: 角丸（radius 約 16%）
  - 下辺: V字カット（中央に三角形の切り込み、深さ 約 15%）
- **全体サイズ**: App Storeに合わせ 1024×1024px で制作（他サイズはこれをリサイズ）

```
  ╭──────────╮
  │          │
  │    N     │
  │          │
  └───╱╲─────┘
      ↑ V字カット
```

---

## カラーパレット

| 用途 | カラー | Hex |
|------|--------|-----|
| 背景（しおり本体） | ディープネイビー | `#0D1B3E` |
| 文字「N」 | ゴールド | `#C9A84C` |
| 「N」アウトライン / ハイライト | ライトゴールド | `#E8C97A` |
| 影・奥行き | ダークネイビー | `#071022` |

---

## 「N」タイポグラフィ

- **フォント**: セリフ体推奨（例: Garamond, Didot, Playfair Display）
- **ウェイト**: Bold または ExtraBold
- **サイズ**: しおり高さの約 50%
- **カラー**: Gold `#C9A84C`（内側）+ ライトゴールド `#E8C97A`（上部ハイライト）
- **位置**: 水平中央、垂直は中央よりやや上（V字カット分を考慮）

---

## テクスチャ・仕上げ

- **グラデーション**: 背景をフラットにせず、左上に向かって `#1A2D5A` → 右下 `#0D1B3E` の微細なグラデーション
- **「N」の光沢**: 上部にライトゴールドのハイライトを入れ、金属感を演出
- **V字カット**: 影（`#071022`）で奥行きを表現

---

## 生成プロンプト（Midjourney / DALL-E 用）

```
App icon for "Novelmark", deep navy blue bookmark shape with V-notch cut at bottom,
centered bold serif letter N in gold color with slight metallic sheen,
clean flat design with subtle gradient, no text other than the letter N,
1024x1024, white background
```

---

## 必要な書き出しサイズ（iOS）

| 用途 | サイズ |
|------|--------|
| App Store | 1024×1024 |
| iPhone ホーム画面 @3x | 180×180 |
| iPhone ホーム画面 @2x | 120×120 |
| iPad @2x | 167×167 |
| Spotlight @3x | 120×120 |
| Settings @3x | 87×87 |

Flutter では `flutter_launcher_icons` パッケージを使い 1024px 原稿から自動生成可能。
