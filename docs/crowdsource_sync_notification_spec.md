# 共有由来の最新話同期 & 小説通知 仕様・設計書

> 本ドキュメントは「相手先サーバーに負荷をかけずに最新話追従の利便性を高める」ための機能仕様・設計を定義する。
> 既存仕様は `docs/specification.md`、クローリングは同 6 章、Share Extension は同 9 章を参照。

---

## 0. 背景と狙い

現状、最新話の検出は **6時間ごとの `crawl-updates` バッチ（外部サイトへスクレイピング/API）** に依存している。
これは相手先サーバー（なろう / ハーメルン / Arcadia）への定期アクセスであり、登録小説が増えるほど負荷とコストが増える。

一方、ユーザーがSafariで小説を読んで**共有（ブックマーク登録/更新）する瞬間**、その小説ページは
**既にブラウザに正しく表示されている**。この「ユーザーが自分で開いた」という事実をシグナルとして使えば、
**相手先サーバーへ追加リクエストを一切出さずに** 最新話数を取得できる。

これを「クラウドソース型 最新話同期」と呼ぶ。狙いは次の3点：

1. **負荷削減**: 誰かが18時間以内に共有確認した小説は、バッチクロールを丸ごとスキップ。
2. **鮮度向上**: 熱心な読者が開いた瞬間に総話数がDBへ反映され、他ユーザーへ即時通知できる。
3. **利便性**: 共有＝既読更新だけでなく、コミュニティ全体の最新話追従にも貢献する。

---

## 1. 用語定義

| 用語 | 定義 |
|------|------|
| 共有 | Safari Web Extension（ツールバー）/ Share Extension からアプリへURLを渡す操作 |
| 正しく表示されていた | 共有時、対象ページが有効な小説ページとしてDOM上に描画されていた状態（エラー/削除/Cloudflare壁ページでない） |
| DOM総話数 | content.js が表示中ページのDOMから読み取った、その小説の総話数（全○話） |
| 共有確認時刻 | DOM総話数が信頼できる形で取得・反映された時刻（`novels.last_shared_verified_at`） |
| 最終確認時刻 | `max(last_crawled_at, last_shared_verified_at)`。バッチのスキップ判定に使う |

---

## 2. 機能要件

### FR-1 共有由来の最新話同期
- Safari Web Extension の `content.js` が、表示中の小説ページDOMから **総話数** と **ページ妥当性** を抽出する。
- 「正しく表示されていた」かつ「DOM総話数 > 現在のDB `total_episodes`」のときに限り、DBの最新話（`total_episodes` 等）を更新する。
- 相手先サーバーへの追加リクエストは行わない（ブラウザに既にある情報のみ使用）。

### FR-2 バッチクロールのスキップ
- `crawl-updates` バッチは、**最終確認時刻が18時間以内**の小説を対象から除外する。
- これにより共有でカバーされた人気作はクロールせず、負荷とコストを削減する。

### FR-3 小説の通知機能
- **バッチ経由**: `crawl-updates` の全サイト処理（narou / hameln / arcadia）が完了してから、更新があった全小説を一括通知する（途中では送らない）。
- **共有経由**: 共有由来でDB総話数が増加したとき、その小説をブックマークしている **他ユーザー** に通知する（共有者本人は除外）。
- 不正対策ガード（後述）を満たした更新のみ通知対象とする。
- **重複防止**: `notifications.episode_milestone`（= 通知時の `total_episodes`）+ 部分ユニークインデックスで、バッチ・共有どちらが先に到達しても同一ユーザーへ二重送信しない。

---

## 3. 信頼ポリシー（確定事項）

| 論点 | 決定 |
|------|------|
| 最新話数の取得元 | **ページDOMから総話数を抽出**（相手サーバーへ追加リクエストなし） |
| 通知の信頼性 | **通知する（不正対策ガード付き）** |
| 18時間スキップの基準時刻 | **最終確認（クロール or 共有）からの経過** |

### 不正対策ガード（FR-3 の通知条件）
共有由来の更新は「他人にも見える共有データ（`novels`）」を書き換えるため、以下を**すべて**満たす場合のみ
**通知**を発火する。満たさない更新は **DBに反映しない／通知しない**（フェイルクローズ）。

1. **ページ妥当性**: content.js がページを有効な小説ページと判定（タイトル・話数要素が存在）。
2. **サイト整合**: 共有URLの `site`/`site_novel_id` がDBの当該小説と一致。
3. **単調増加**: DOM総話数 > DB `total_episodes`。
4. **跳躍上限**: 増加幅が上限以内（`SHARE_MAX_JUMP = 50`話）。超過時はDB更新も通知もせず、`crawl_logs` に `flagged` として記録（次回バッチで正規確認）。
5. **サニティ**: DOM総話数が正の整数で、サイト別上限（例: 10,000話）以内。
6. **重複抑止**: 直近で同一 `(novel_id, total_episodes)` の通知を送っていない（後述の冪等キー）。

> ガードに引っかかった場合でも「既読更新（`bookmarks.last_read_episode`）」は従来どおり行う（個人データなので安全）。

---

## 4. アーキテクチャ / データフロー

```
[Safari: 小説ページ表示中]
      │ ユーザーがツールバーの Novelmark を押す
      ▼
content.js  ──(DOMから総話数・妥当性を抽出)──┐  ※相手サーバーへリクエスト無し
      │                                      │
popup.js ─ browser.runtime.sendMessage(action:'register', url, displayedTotal, valid)
      ▼
background.js ─ sendNativeMessage({action,url,displayedTotal,valid})
      ▼
SafariWebExtensionHandler.swift ─ App Group(SharedURL) にJSONとして積む
      ▼
[Flutter App 起動/復帰] MethodChannel で受領 → registerFromUrl(url, sharedMeta)
      ▼
Edge Function: register-bookmark（拡張）
  1) 既存どおりブックマーク登録 / 既読更新
  2) sharedMeta があればガード判定 → novels更新 → 通知 → last_shared_verified_at記録
      ▼
notifications テーブル + FCM push（他ブックマーカーへ）
```

### Share Extension（共有シート経由）について
共有シート（`ShareViewController.swift`）からの登録は **DOMにアクセスできない**ため、`displayedTotal` は付かない。
この経路は従来どおり「URLのみ・既読更新まで」。**FR-1 の総話数同期は Safari Web Extension 経路に限定**する
（content.js がDOMを読めるのはこの経路だけ）。URL内の話数があれば `bookmarks.last_read_episode` の更新には使う。

---

## 5. クライアント設計（iOS Safari Web Extension）

### 5.1 content.js（新規実装の中核）
表示中ページからサイト別に総話数を抽出するスクレイパを実装。**ネットワークアクセス禁止**（DOMのみ）。

```js
// site別に総話数とページ妥当性を返す
function extractNovelMeta() {
  const host = location.host;
  if (host.includes('ncode.syosetu.com')) return parseNarou();
  if (host.includes('syosetu.org'))       return parseHameln();
  if (host.includes('mai-net.net'))        return parseArcadia();
  return { valid: false };
}
// 返り値: { valid: boolean, totalEpisodes: number|null, title: string|null }
```

サイト別の抽出指針（実装時に実DOMで要検証・脆いので防御的に）：

| サイト | 総話数の取得元（DOM） | 妥当性チェック |
|--------|----------------------|----------------|
| なろう | 目次ページの話数リンク総数 / 「全○部分」表示 | 作品タイトル要素が存在し、話数要素>0 |
| ハーメルン | 目次の各話リンク件数 / 「全○話」 | 作品タイトル(og:title相当)が存在 |
| Arcadia | 一覧の `[番号]` エントリ最大値 | タイトル/Name要素が存在 |

> 抽出に失敗（`valid:false` または `totalEpisodes:null`）した場合は `displayedTotal` を付けずに送る
> ＝ 従来の登録/既読更新のみ行い、総話数同期はしない（フェイルクローズ）。
> エピソードページ（目次でない）でも総話数が読めないことがあるため、その場合も同様にスキップ。

### 5.2 popup.js / background.js / Handler 変更
- `popup.js`: `browser.tabs.sendMessage(tab.id, {action:'extractMeta'})` で content.js から meta を取得 →
  `sendMessage({action:'register', url, displayedTotal, valid, title})`。
- `background.js`: 受けた `displayedTotal`/`valid` を `sendNativeMessage` のペイロードに付与。
- `SafariWebExtensionHandler.swift`: App Group へは **JSON文字列**（`{url, displayedTotal, valid, ts}`）の配列として積む。
  後方互換のため、旧来の素のURL文字列もパースできるようにする。

### 5.3 Flutter 受領（main.dart / app.dart / url_parser）
- App Group から受けた要素を `SharedShare { url, displayedTotal?, valid }` にデコード。
- `registerFromUrl(url, {int? sharedTotal})` を拡張し、`register-bookmark` 呼び出しに `shared_total` を渡す。
- スナックバー文言は、同期が起きたら「最新話を○話に更新しました（みんなに反映）」等を追加。

---

## 6. バックエンド設計（Edge Functions）

### 6.1 `register-bookmark`（拡張）
リクエストに `shared_total?: number` を追加。既存処理の後段に同期ロジックを差し込む。

```ts
// 疑似コード（既存の novelId 確定後）
if (typeof shared_total === 'number' && novel) {
  const result = applySharedUpdate(serviceClient, novel, shared_total, user.id);
  // result: { updated: boolean, reason?: string }
}
```

`applySharedUpdate` のガード（§3 の不正対策ガード）：

```ts
const old = novel.total_episodes ?? 0;
if (!(shared_total > old)) return { updated:false, reason:'not_increasing' };
if (shared_total - old > SHARE_MAX_JUMP) {            // 50
  await logCrawl(client, novel, 'flagged', shared_total - old, 'share jump too large', 0);
  return { updated:false, reason:'jump_too_large' };
}
if (shared_total > SITE_MAX_EPISODES[novel.site]) return { updated:false, reason:'insane' };

// DB更新（site_updated_at は「相手サイト由来の値」ではないため now は使わず、
// 「共有確認」専用列 last_shared_verified_at を更新する）
await client.from('novels').update({
  total_episodes: shared_total,
  last_shared_verified_at: nowIso,
  updated_at: nowIso,
}).eq('id', novel.id);

// 不足分の episodes を補完 upsert（なろう同様、連番生成）
// 通知（共有者本人は除外）
await notifyUsers(client, novel, shared_total, { excludeUserId: user.id, source: 'shared' });
return { updated:true };
```

> **冪等性**: `notifyUsers` 内で `(user_id, novel_id, type='new_episode', total=shared_total)` の重複を避けるため、
> 直近通知の `body`/メタを確認、または下記 §7 の部分ユニークインデックスで二重送信を防ぐ。

### 6.2 `crawl-updates`（スキップ条件追加）
対象抽出クエリに「最終確認が18時間以内なら除外」を追加。`last_crawled_at` だけでなく
`last_shared_verified_at` も考慮する必要があるため、**両列のうち新しい方**で判定する。

```ts
const SKIP_WINDOW_MS = 18 * 60 * 60 * 1000;
const skipCutoff = new Date(Date.now() - SKIP_WINDOW_MS).toISOString();

// novels取得後、JS側でフィルタ（Supabase or 条件で複合 OR が書きづらいため）
const fresh = (n) => {
  const t = Math.max(
    n.last_crawled_at ? Date.parse(n.last_crawled_at) : 0,
    n.last_shared_verified_at ? Date.parse(n.last_shared_verified_at) : 0,
  );
  return t >= Date.now() - SKIP_WINDOW_MS;
};
const targetNovels = novels.filter(n => bookmarkedSet.has(n.id) && !fresh(n));
```

> 並び順 `last_crawled_at ASC NULLS FIRST` は維持しつつ、`last_shared_verified_at` を `select('*')` に含める。
> スキップした件数は戻り値 `skipped` に集計し、`crawl_logs` に `status='skipped'` で1行残す（可観測性）。
> Arcadia は既存の24時間ルールをそのまま併用（より強い制限が優先）。

### 6.3 `notifyUsers`（共有/バッチ共通化）
- 引数に `excludeUserId?` と `source: 'crawl'|'shared'` を追加。
- 共有経路では `excludeUserId = 共有者` を除いてブックマーカーへ送る。
- 通知文言は従来どおり「『{title}』第{n}話が公開されました」。`source` は `data` ペイロードに入れて分析可能にする。

---

## 7. データベース変更（マイグレーション）

新規マイグレーション: `supabase/migrations/20260607000001_shared_sync.sql`

```sql
-- 共有由来の最新話確認時刻（バッチスキップ判定 & クロールと区別するため専用列）
ALTER TABLE novels
  ADD COLUMN last_shared_verified_at timestamptz;

-- バッチのスキップ判定を効率化（最終確認が新しいものを後回し/除外）
CREATE INDEX idx_novels_last_shared_verified
  ON novels(last_shared_verified_at DESC NULLS LAST);

-- 新着話通知の二重送信防止（同一小説・同一話数の通知は1ユーザー1回）
-- body 等ではなく構造化キーで担保するため、補助列を追加して部分ユニーク化
ALTER TABLE notifications
  ADD COLUMN episode_milestone integer;  -- new_episode のとき total_episodes を格納

CREATE UNIQUE INDEX uq_notifications_new_episode
  ON notifications(user_id, novel_id, episode_milestone)
  WHERE type = 'new_episode' AND episode_milestone IS NOT NULL;
```

> 既存の `crawl-updates` の `notifyUsers` も `episode_milestone = total_episodes` を入れるよう更新し、
> 共有・バッチ間でも二重通知を防ぐ。insert は `upsert(..., {onConflict, ignoreDuplicates:true})` 方式に変更。

`crawl_logs.status` に `skipped` / `flagged` の2値を許容（現状 varchar なので制約変更不要、運用上の取り決めのみ）。

---

## 8. 定数（環境変数 or 共有定数）

| 名前 | 値 | 意味 |
|------|----|------|
| `SHARE_MAX_JUMP` | 50 | 共有1回で許容する総話数の最大増分 |
| `SKIP_WINDOW_HOURS` | 18 | バッチスキップ窓（最終確認からの経過） |
| `SITE_MAX_EPISODES` | narou/hameln/arcadia ごと 10000 | サニティ上限 |

`_shared/constants.ts` に集約し、`register-bookmark` と `crawl-updates` で共用。

---

## 9. セキュリティ / 悪用シナリオと対策

| 脅威 | 対策 |
|------|------|
| 偽の高い総話数を送って全員に誤通知 | DOM妥当性＋単調増加＋跳躍上限(50)＋サイト別サニティ。超過は `flagged` で握りつぶし、次回バッチが正規値で訂正 |
| クロール永久スキップでDBが古いまま | 18時間窓は「共有 or クロール」両方を見るため、共有が止まれば必ずバッチが拾う。スキップは18hで自然失効 |
| 改造クライアントが `shared_total` を捏造 | サーバー側ガードが最終防衛線（クライアントを信用しない）。`flagged` をモニタリングし異常ユーザーを検知 |
| 通知スパム（同一話数連打） | `uq_notifications_new_episode` 部分ユニークで冪等化、共有者本人は除外 |
| content.js が壁ページ/エラーを誤検知 | `valid:false` 時は同期しないフェイルクローズ。タイトル＋話数要素の二重チェック |

---

## 10. 観測可能性（メトリクス）

- `crawl_logs` に `skipped`（18h窓） / `flagged`（ガード逸脱）を記録 → スキップ率・異常率を可視化。
- 同期成功時は `status='success'` 相当のログ（`site, episodes_found=増分, source='shared'`）を残す。
- KPI: バッチ処理対象数の削減率、共有由来更新が「正規クロールと一致した」整合率。

---

## 11. 実装タスク分解（PR分割案）

1. **DBマイグレーション**: `last_shared_verified_at` / `episode_milestone` / インデックス（§7）。
2. **共通定数**: `_shared/constants.ts`、`notifyUsers` の共通化（`excludeUserId`/`source`/`episode_milestone`）。
3. **register-bookmark 拡張**: `shared_total` 受領 + `applySharedUpdate` ガードロジック（§6.1）。
4. **crawl-updates スキップ**: 18h窓フィルタ + `skipped` ログ（§6.2）。
5. **iOS content.js スクレイパ**: サイト別総話数抽出（§5.1、実DOM検証必須）。
6. **iOS popup/background/Handler**: meta受け渡し + App Group JSON化 + 後方互換（§5.2）。
7. **Flutter 受領**: SharedShare デコード + `registerFromUrl(sharedTotal)` + 文言（§5.3）。
8. **テスト**: ガード単体（増分/跳躍/サニティ/冪等）、18hスキップ境界、content.js抽出の各サイトHTMLフィクスチャ。

> 1〜4（サーバー & DB）は相手先サーバー非依存で先行リリース可能。5〜7（iOS）はApp審査を伴うため後追い。
> サーバー側が `shared_total` 未指定でも従来通り動くため、段階リリースで破綻しない。

---

## 12. 受け入れ条件（Acceptance Criteria）

- [ ] Safari Web Extensionで最新話ページを共有 → DOM総話数 > DB話数 のとき `total_episodes` が更新される。
- [ ] 同操作で、その小説をブックマークする**他ユーザー**に in-app + push 通知が届く（共有者本人には届かない）。
- [ ] DOMが無効/壁ページ/総話数取得不可のとき、総話数は更新されない（既読更新は従来通り）。
- [ ] 増分が50話超 or サニティ外のとき、更新も通知もされず `crawl_logs` に `flagged` が残る。
- [ ] 最終確認（クロール or 共有）から18時間以内の小説は `crawl-updates` の対象から除外され、相手先サーバーへアクセスしない。
- [ ] 同一小説・同一総話数の通知は1ユーザーにつき1回まで（共有とバッチをまたいでも重複しない）。
- [ ] 上記すべてにおいて、相手先サーバーへの**追加**HTTPリクエストが発生しない（共有経路）。
