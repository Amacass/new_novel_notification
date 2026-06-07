# おすすめ機能 仕様・設計書

> 本ドキュメントは Novelmark に「ユーザー間のおすすめ（推薦）機能」を追加するための仕様・設計書である。
> 既存の `docs/specification.md`（全体仕様）および `docs/requirements.md`（要件定義）を前提とする。
> UX実装時は `docs/ux_psychology.md` を参照すること。

最終更新日: 2026年6月7日 / バージョン: draft 0.1

---

## 0. 概要・前提

### 0.1 機能の目的

これまでの Novelmark は「自分のための非公開ブックマーク・トリアージツール」だった。
本機能は **初めての公開ソーシャル要素** として、ユーザーが自分の蔵書（殿堂入り・良作）を
他のユーザーに「おすすめ」として公開・共有できるようにする。

### 0.2 設計上の重要決定（確定事項）

ユーザーとの確認により以下を確定済み：

| # | 論点 | 決定 |
|---|------|------|
| 1 | 「おまかせ」の分類軸 | **作品軸（原作作品 / その他）を選択できる共通軸を新設する**。`user_categories`（各ユーザー専用の自由入力フォルダ）はユーザー間共有の軸にならないため、横断マッチには使わない |
| 2 | データ構造 | おすすめコメントは **独立した新テーブル `recommendations`** とする（既存 `reviews` とは疎結合） |
| 3 | AIモデレーション | **Gemini 2.5 Flash / Flash-Lite** を主軸とする（無料枠が大きく安価）。ただしプロバイダ差し替え可能な抽象化を行う。第三者提供のため規約・プライバシーポリシーへ追記する |

### 0.3 既存資産との関係

| 既存要素 | 本機能での扱い |
|---------|--------------|
| `bookmarks.tier`（-1〜3） | tier=2（良作）/ tier=3（殿堂入り）のブックマークのみおすすめ作成可能 |
| `bookmarks.genre`（original/derivative） | ユーザーの分類入力として参照。作品軸の補完に利用 |
| `reviews`（星評価+感想、全体公開読取） | おすすめとは別物。おすすめ作成画面で「既存の感想を引用する」導線のみ提供（任意） |
| `user_categories` / `bookmark_categories` | 各ユーザーのパーソナライズ（おまかせの嗜好推定）に利用。横断マッチには使わない |
| BottomNavigationBar（現状4タブ） | 「おすすめ」を条件付き5タブ目として追加（閲覧ON時のみ表示） |

### 0.4 用語

- **おすすめ（recommendation）**: あるユーザーが、自分が高評価した1作品について書いた公開推薦。見出し+本文を持つ。
- **作品軸 / 原作作品（source work）**: 二次創作の元作品（例: ナルト, 東方Project）や「オリジナル」などの共通分類。novels に紐づく。
- **総いいね数**: あるユーザーの全おすすめが獲得したいいねの合計。マイページ兼設定で本人が確認できる。

---

## 1. 全体像

```
┌───────────────── おすすめ画面（/recommend） ─────────────────┐
│ タブ: [おまかせ] [デイリー] [ウィークリー] [マンスリー]      │
│       [総合] [自分のおすすめ]                                 │
│ フィルタ: 作品[▼ 全作品/ナルト/東方/オリジナル...] ジャンル   │
├──────────────────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐                │
│ │ 【見出し】最後まで一気読みした神作          │                │
│ │ 小説タイトル / 作者名 / 殿堂入り             │                │
│ │ 本文: テンポが良く...（抜粋）                │                │
│ │ by 表示名（総いいね 1.2k）   ♡ 342  [開く]   │                │
│ └──────────────────────────────────────────┘                │
│                      ...                                     │
└──────────────────────────────────────────────────────────────┘

作成導線: 小説詳細画面（作成ON かつ 自分のブクマが tier∈{2,3} の場合のみ）
　└ 「この作品をおすすめする」→ 見出し+本文+公開/非公開 → 投稿（モデレーション待ち）

モデレーション: pg_cron（日次）→ Edge Function（moderate-recommendations）
　└ Gemini 2.5 Flash で R18/広告/アンチ/感想逸脱を判定 → approved/rejected
```

---

## 2. データベース設計

### 2.1 新規テーブル

#### `source_works` — 原作作品マスタ（作品軸）

二次創作の元作品や「オリジナル」を表す共通の分類軸。クロール由来 + AI推定 + ユーザー入力で育てる。

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| name | varchar(100) | NOT NULL, UNIQUE | 作品名（例: 「ナルト」「東方Project」「オリジナル」） |
| reading | varchar(100) | | 読み仮名（検索・名寄せ用） |
| aliases | text[] | DEFAULT '{}' | 別名・表記揺れ（「NARUTO」等） |
| novel_count | integer | DEFAULT 0 | 紐づく小説数（キャッシュ） |
| created_at | timestamptz | DEFAULT now() | 作成日時 |

- 名寄せ運用: 表記揺れは `aliases` に集約し、`name` を正規名として扱う。
- 特別レコードとして `name = 'オリジナル'`（= 一次創作の総称）を初期投入。

#### `novels` への追加カラム

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| source_work_id | bigint | FK → source_works.id, NULL可 | 原作作品（二次創作の元 or オリジナル） |
| work_kind | varchar(12) | CHECK IN ('original','derivative'), NULL可 | 作品種別。クロール+AI推定+ユーザー分類で確定 |

- 確定ロジック（優先度高い順）:
  1. クロール由来メタデータ（Arcadia の `cate`、ハーメルンの「原作」欄、なろうのキーワード/ジャンル）
  2. AIモデレーション時の副次推定（後述）
  3. その作品をブクマしている各ユーザーの `bookmarks.genre` の多数決（補完）

#### `recommendations` — おすすめ本体

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| user_id | uuid | FK → profiles.id, NOT NULL | 作成者 |
| novel_id | bigint | FK → novels.id, NOT NULL | 対象小説 |
| heading | varchar(60) | NOT NULL | 見出し |
| body | text | NOT NULL | コメント本文 |
| is_public | boolean | DEFAULT true | 作成者による公開/非公開（個別トグル） |
| moderation_status | varchar(12) | DEFAULT 'pending' | 'pending' / 'approved' / 'rejected' |
| moderation_reason | varchar(30) | | 'r18' / 'ad' / 'harassment' / 'off_topic' / 'other'（rejected時） |
| moderated_at | timestamptz | | 最終判定日時 |
| like_count | integer | DEFAULT 0 | いいね総数（キャッシュ。トリガで更新） |
| source_tier | smallint | NOT NULL | 投稿時のブクマtier（2 or 3）。表示用スナップショット |
| created_at | timestamptz | DEFAULT now() | 作成日時 |
| updated_at | timestamptz | DEFAULT now() | 更新日時 |

**制約**: `UNIQUE(user_id, novel_id)` — 1ユーザー1作品につき1おすすめ。

**公開条件（重要）**: 公衆に表示されるのは
`is_public = true AND moderation_status = 'approved'` のレコードのみ（フェイルクローズ）。

#### `recommendation_likes` — いいね

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| recommendation_id | bigint | FK → recommendations.id ON DELETE CASCADE, NOT NULL | 対象おすすめ |
| user_id | uuid | FK → profiles.id, NOT NULL | いいねしたユーザー |
| created_at | timestamptz | DEFAULT now() | いいね日時（期間集計に使用） |

**制約**: `UNIQUE(recommendation_id, user_id)` — 二重いいね防止。

#### `recommendation_reports` — 通報（提案: §7）

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| recommendation_id | bigint | FK → recommendations.id ON DELETE CASCADE, NOT NULL | 対象 |
| reporter_id | uuid | FK → profiles.id, NOT NULL | 通報者 |
| reason | varchar(30) | NOT NULL | 'r18' / 'ad' / 'harassment' / 'off_topic' / 'other' |
| note | text | | 補足 |
| created_at | timestamptz | DEFAULT now() | 通報日時 |

**制約**: `UNIQUE(recommendation_id, reporter_id)`。

#### `recommendation_ranking_snapshots` — ランキングスナップショット（性能用）

daily/weekly/monthly のランキングを日次バッチで事前計算し格納（毎回の集約を避ける）。

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| period | varchar(8) | NOT NULL | 'daily' / 'weekly' / 'monthly' |
| rank | integer | NOT NULL | 順位 |
| recommendation_id | bigint | FK → recommendations.id, NOT NULL | 対象 |
| likes_in_period | integer | NOT NULL | 期間内いいね数 |
| computed_at | timestamptz | DEFAULT now() | 計算日時 |

**主キー**: `PRIMARY KEY(period, rank)`。
- `total`（総合）は `recommendations.like_count` で直接ソートするためスナップショット不要。

### 2.2 `profiles` への追加カラム（設定 + 総いいね）

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| recommend_view_enabled | boolean | DEFAULT true | 他者のおすすめ閲覧。OFFでフッター（タブ）に出さない |
| recommend_create_enabled | boolean | DEFAULT true | おすすめ作成。OFFで小説詳細に記入欄を出さない |
| total_recommend_likes | integer | DEFAULT 0 | 自分の全おすすめの総いいね数（キャッシュ） |

### 2.3 トリガ

```sql
-- いいね増減で recommendations.like_count と profiles.total_recommend_likes を更新
CREATE FUNCTION sync_recommendation_like_count() RETURNS trigger AS $$
DECLARE target_user uuid;
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE recommendations SET like_count = like_count + 1
      WHERE id = NEW.recommendation_id RETURNING user_id INTO target_user;
    UPDATE profiles SET total_recommend_likes = total_recommend_likes + 1
      WHERE id = target_user;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE recommendations SET like_count = greatest(like_count - 1, 0)
      WHERE id = OLD.recommendation_id RETURNING user_id INTO target_user;
    UPDATE profiles SET total_recommend_likes = greatest(total_recommend_likes - 1, 0)
      WHERE id = target_user;
  END IF;
  RETURN NULL;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_recommendation_likes
  AFTER INSERT OR DELETE ON recommendation_likes
  FOR EACH ROW EXECUTE FUNCTION sync_recommendation_like_count();
```

```sql
-- おすすめ作成・更新時に「自分のブクマが tier∈{2,3}」であることを強制
CREATE FUNCTION enforce_recommendable_tier() RETURNS trigger AS $$
DECLARE t smallint;
BEGIN
  SELECT tier INTO t FROM bookmarks
    WHERE user_id = NEW.user_id AND novel_id = NEW.novel_id;
  IF t IS NULL OR t < 2 THEN
    RAISE EXCEPTION 'recommendation requires bookmark tier 2 (良作) or 3 (殿堂入り)';
  END IF;
  NEW.source_tier := t;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_recommendable_tier
  BEFORE INSERT OR UPDATE OF novel_id ON recommendations
  FOR EACH ROW EXECUTE FUNCTION enforce_recommendable_tier();
```

```sql
-- 本文・見出しが編集されたら再モデレーション（pendingへ戻す）
CREATE FUNCTION requeue_on_edit() RETURNS trigger AS $$
BEGIN
  IF (NEW.heading IS DISTINCT FROM OLD.heading
      OR NEW.body IS DISTINCT FROM OLD.body) THEN
    NEW.moderation_status := 'pending';
    NEW.moderation_reason := NULL;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_requeue_on_edit
  BEFORE UPDATE OF heading, body ON recommendations
  FOR EACH ROW EXECUTE FUNCTION requeue_on_edit();
```

### 2.4 RLS（Row Level Security）ポリシー

```sql
-- recommendations
ALTER TABLE recommendations ENABLE ROW LEVEL SECURITY;

-- 公開: 承認済みかつ公開のものは全認証ユーザーが閲覧可
CREATE POLICY "Public approved recommendations are viewable"
  ON recommendations FOR SELECT TO authenticated
  USING (is_public = true AND moderation_status = 'approved');

-- 自分のものは状態に関わらず閲覧可（自分のおすすめタブ用）
CREATE POLICY "Users can view own recommendations"
  ON recommendations FOR SELECT USING (auth.uid() = user_id);

-- 作成・更新・削除は本人のみ（tier制約はトリガで担保）
CREATE POLICY "Users can insert own recommendations"
  ON recommendations FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own recommendations"
  ON recommendations FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own recommendations"
  ON recommendations FOR DELETE USING (auth.uid() = user_id);
-- ※ moderation_status / moderation_reason はサービスロール（Edge Function）のみ更新。
--   クライアントからの更新でこれらが変わらないよう、列レベルの GRANT もしくは
--   別ポリシー + チェック関数で制御する（実装メモ §9）。

-- recommendation_likes
ALTER TABLE recommendation_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Likes are viewable by all"
  ON recommendation_likes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can like"
  ON recommendation_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike own like"
  ON recommendation_likes FOR DELETE USING (auth.uid() = user_id);

-- source_works / novels の追加列は既存方針通り「全認証ユーザー読取・書込はサーバーのみ」
```

### 2.5 公開プロフィール用ビュー

おすすめには作成者の表示名・総いいね数を併記する。一方 `profiles` の SELECT は現状
「本人のみ」。メール等を晒さず必要列だけ公開するため **ビュー** を切る。

```sql
CREATE VIEW public_profiles
  WITH (security_invoker = false) AS
  SELECT id, display_name, avatar_url, total_recommend_likes
  FROM profiles;
-- security_invoker=false（= definer 権限）で必要列のみ公開。
GRANT SELECT ON public_profiles TO authenticated;
```

### 2.6 インデックス

```sql
CREATE INDEX idx_rec_public_approved
  ON recommendations(moderation_status, is_public, like_count DESC);
CREATE INDEX idx_rec_user ON recommendations(user_id);
CREATE INDEX idx_rec_novel ON recommendations(novel_id)
  WHERE is_public = true AND moderation_status = 'approved';
CREATE INDEX idx_rec_pending ON recommendations(moderation_status)
  WHERE moderation_status = 'pending';
CREATE INDEX idx_rec_likes_created ON recommendation_likes(created_at);
CREATE INDEX idx_rec_likes_rec ON recommendation_likes(recommendation_id);
CREATE INDEX idx_novels_source_work ON novels(source_work_id);
```

---

## 3. 「おまかせ」アルゴリズム

### 3.1 方針

要件「ブクマしているカテゴリから3つ、他カテゴリから2つ、ある程度いいねがあるものを優先的にランダム」を、
**作品軸（source_work）+ ジャンル（work_kind）** をベースに実装する。

### 3.2 嗜好プロファイル算出

ユーザーのブックマーク（特に tier ≥ 1）から、嗜好する `source_work_id` と
`work_kind` の重み分布を作る。`user_categories` の偏りも補助シグナルに使う。

```
preferred_works = ブクマ作品の source_work_id を出現数で集計し上位N件
preferred_kind  = original/derivative の比率
```

### 3.3 フィード構成（1ページ ≒ 20件の例）

```
1. 候補プール = approved かつ public、自分の投稿を除外、
   （任意で）自分が既にブクマ済みの作品を除外。
2. 「嗜好作品」枠（≒60%）:
     source_work_id ∈ preferred_works のおすすめ
3. 「他作品」枠（≒40%）:
     preferred_works に含まれない作品のおすすめ（発見性確保）
4. 各枠内は like_count による重み付きランダム抽選
   weight = log(1 + like_count) + ε     （ε=新規救済の下駄）
   → いいねが多いものを優先しつつ完全固定化を避ける
5. 同一作者・同一小説の連続を避けてシャッフル
```

- 比率（60/40）と1ページ件数は設定定数化。要件の「3:2」をデフォルトの近似とする。
- **明示フィルタ**: ユーザーが「作品」を選択した場合は §3.3 を無視し、その `source_work_id`
  のおすすめを like_count 降順 + 新着で表示。「オリジナル」選択時は work_kind='original'。

### 3.4 ランキングタブ（daily / weekly / monthly / total）

| タブ | 算出 |
|------|------|
| デイリー | 直近24時間の `recommendation_likes` を集計（snapshot: period='daily'） |
| ウィークリー | 直近7日 |
| マンスリー | 直近30日 |
| 総合 | `recommendations.like_count` 降順（snapshotなし、直クエリ） |

- daily/weekly/monthly は日次バッチ（§4.2）で `recommendation_ranking_snapshots` に
  上位200件程度を書き出し、画面はそれを読むだけにする（集約コストを画面から排除）。
- いずれも公開条件（approved & public）を満たすもののみ対象。

### 3.5 自分のおすすめタブ

`user_id = self` の全おすすめを状態バッジ付き（審査中/公開中/非公開/却下）で一覧。
却下時は `moderation_reason` を表示し、編集→再投稿（再モデレーション）を促す。

---

## 4. AIモデレーション

### 4.1 何を弾くか

| 区分 | reason | 例 |
|------|--------|----|
| R18 | `r18` | 性的・露骨な表現 |
| 広告・スパム | `ad` | 外部URL誘導、宣伝、無関係な販促 |
| アンチ・誹謗中傷 | `harassment` | 作者・他者への攻撃、ヘイト |
| 感想逸脱 | `off_topic` | 小説の感想として内容から著しく外れたもの |
| その他不適切 | `other` | 上記に準じる規約違反 |

### 4.2 日次バッチ構成

```
pg_cron（1日1回, 例: 04:00 JST）
  → Edge Function: moderate-recommendations
     1. moderation_status='pending' のおすすめを取得（上限バッチ, 例: 200件/回）
     2. 各レコードについて:
        - 入力: heading, body, 小説タイトル, あらすじ（先頭数百字）
        - ModerationProvider.classify() を呼び出し
        - 返却 JSON で approved/rejected と reason を判定
        - 併せて work_kind / source_work の推定があれば novels を補完（任意）
     3. recommendations を一括 UPDATE（moderation_status, reason, moderated_at）
     4. （提案）却下時は作成者に通知（notifications type='recommendation_rejected'）
  → ranking snapshot 再計算（同バッチ or 別ジョブ）
```

- **公開までのラグ**: 投稿〜次回バッチまで `pending`（非公開）。要件どおり日次バッチを正とする。
- **UX改善（任意・推奨）**: 投稿時に同じ Provider で **即時1回チェック** を行い、明白な違反は
  即 reject、問題なければ即 approve するハイブリッドも可能。日次バッチは取りこぼし・再審査の
  セーフティネットとして残す。採用可否は運用コストと相談。

### 4.3 プロバイダ抽象化

```typescript
// supabase/functions/_shared/moderation/provider.ts
export interface ModerationResult {
  allow: boolean;
  reason: 'r18' | 'ad' | 'harassment' | 'off_topic' | 'other' | null;
  workKind?: 'original' | 'derivative';
}
export interface ModerationProvider {
  classify(input: {
    heading: string; body: string;
    novelTitle: string; synopsis: string;
  }): Promise<ModerationResult>;
}
```

- 既定実装 `GeminiModerationProvider`（**Gemini 2.5 Flash / Flash-Lite**）。
  - 安価・無料枠あり・高スループットで日次分類に好適。
  - `responseSchema` で JSON 構造化出力を強制し、パース失敗を防ぐ。
  - 失敗時はフェイルクローズ（pendingのまま、次回バッチで再試行）。
- 差し替え用に `ClaudeModerationProvider`（claude-haiku-4-5）も同インターフェースで用意可能。
- **データ取り扱い注意**: 送信するのは「公開意図のテキスト + 小説メタ」のみ。個人情報は送らない。
  Gemini無料枠（AI Studio）は入力がモデル改善に使われ得るため、
  気になる場合は有料 / Vertex AI 経由（学習非利用）を選択する。いずれにせよ
  第三者提供としてプライバシーポリシーに明記する（§8で対応済み）。

### 4.4 プロンプト要旨

```
あなたはWeb小説レビューのモデレーターです。以下の「見出し」「本文」が、
指定小説の感想・おすすめとして適切か判定し、JSONのみで返答してください。
弾く対象: (1)R18/露骨な性的表現 (2)広告・宣伝・外部誘導 (3)誹謗中傷・アンチ・ヘイト
(4)その小説の感想から著しく逸脱した無関係な内容。
出力: {"allow": bool, "reason": "r18|ad|harassment|off_topic|other"|null,
        "work_kind": "original|derivative"|null}
小説タイトル: {title}
あらすじ: {synopsis}
見出し: {heading}
本文: {body}
```

---

## 5. 画面・UI設計

### 5.1 ナビゲーション（フッター = BottomNavigationBar）

- `recommend_view_enabled = true` のとき、**5タブ目「おすすめ」**（`Icons.recommend`）を表示。
  OFF のときはタブを出さず `/recommend` へ遷移させない（要件の「フッターにリンクが出ない」）。
- 現状4タブ→最大5タブ。NavigationBar の実用上限は5なので許容範囲。
  将来さらに増える場合は「もっと見る」集約 or タイムライン内タブ化を検討（§7）。

```dart
// router.dart MainShell（差分イメージ）
final showRecommend = ref.watch(recommendSettingsProvider).viewEnabled;
// destinations を showRecommend で動的に組み立て、index 計算も連動させる
```

### 5.2 おすすめ画面 `/recommend`

- 上部タブ: おまかせ / デイリー / ウィークリー / マンスリー / 総合 / 自分のおすすめ
- フィルタ行: 作品セレクタ（全作品 / 各 source_work / オリジナル）+ ジャンル（任意）
- カード: 見出し、小説タイトル・作者・tierバッジ、本文抜粋、作成者表示名+総いいね、
  いいねボタン（♡ + 件数）、[開く]（小説詳細へ）、… メニュー（通報）
- プルリフレッシュ、無限スクロール（ページング）

### 5.3 小説詳細画面 への追加

```
── おすすめ ──
（A）作成欄（recommend_create_enabled=true かつ 自分のブクマ tier∈{2,3} の場合のみ）
    [見出し______________]（60字）
    [本文________________]（複数行）
    公開 ◉ / 非公開 ○        [おすすめを投稿]
    既存の自分の感想を引用する（任意トグル）
    ※ 投稿後は審査中。承認後に公開されます の注記
（B）この作品への公開おすすめ一覧（approved & public）
    各カードにいいねボタン・通報メニュー
```

- tier が 2/3 でない場合: 「殿堂入り・良作に分類するとおすすめを書けます」と導線表示。
- 作成OFF時: (A) 自体を非表示（(B) は閲覧設定に従う）。

### 5.4 マイページ兼設定 への追加

```
── おすすめ ──
あなたの総いいね数:  ♡ 1,234        （profiles.total_recommend_likes）
自分のおすすめを管理 →               （自分のおすすめタブへ）

他者のおすすめ
  閲覧                [ON/OFF]       （recommend_view_enabled）
  作成（記入欄の表示）  [ON/OFF]       （recommend_create_enabled）
```

- 個々のおすすめの公開/非公開は「自分のおすすめ」一覧の各カードでトグル。

---

## 6. API設計

### 6.1 Supabase REST（PostgREST 自動生成）で賄うもの

```dart
// おすすめ作成（tier制約・状態はトリガ/既定値で担保）
await supabase.from('recommendations').insert({
  'novel_id': novelId, 'heading': heading, 'body': body, 'is_public': isPublic,
});

// 公開/非公開トグル
await supabase.from('recommendations')
  .update({'is_public': next}).eq('id', recId);

// いいね / 取消
await supabase.from('recommendation_likes').insert({'recommendation_id': recId});
await supabase.from('recommendation_likes')
  .delete().eq('recommendation_id', recId).eq('user_id', uid);

// おまかせ以外のフィード（例: 総合）
await supabase.from('recommendations')
  .select('*, novels(*), author:public_profiles(*)')
  .eq('is_public', true).eq('moderation_status', 'approved')
  .order('like_count', ascending: false).range(0, 19);

// ランキング（snapshot 参照）
await supabase.from('recommendation_ranking_snapshots')
  .select('rank, likes_in_period, recommendations(*, novels(*), author:public_profiles(*))')
  .eq('period', 'weekly').order('rank').range(0, 19);
```

### 6.2 Edge Functions（新規）

| 関数 | 起動 | 役割 |
|------|------|------|
| `moderate-recommendations` | pg_cron（日次）/ 任意で作成時 | AIモデレーション判定・状態更新 |
| `compute-recommend-rankings` | pg_cron（日次, モデレーション後） | daily/weekly/monthly snapshot 再計算 |
| `recommend-feed`（任意） | クライアント | 「おまかせ」抽選をサーバー側で実行（嗜好集計+重み付き抽選） |

- 「おまかせ」は重み付きランダム+除外条件があるため、純PostgRESTでは表現しにくい。
  - 簡易版: クライアントで候補を多めに取得しクライアント抽選。
  - 推奨版: `recommend-feed` Edge Function（or Postgres RPC `get_omakase_feed(user_id, limit)`）。

```sql
-- 代替: Postgres 関数（RPC）でおまかせを実装する例（抜粋）
CREATE FUNCTION get_omakase_feed(p_limit int DEFAULT 20)
RETURNS SETOF recommendations AS $$
  -- 嗜好作品集計 → 60/40枠 → weight=log(1+like_count) で order by random()*weight
$$ LANGUAGE sql STABLE;
```

### 6.3 pg_cron 追加

```sql
SELECT cron.schedule('moderate-recommendations', '0 19 * * *',  -- 04:00 JST
  $$SELECT net.http_post(url := '.../functions/v1/moderate-recommendations',
     headers := '{"Authorization":"Bearer <service_role_key>"}'::jsonb)$$);

SELECT cron.schedule('compute-recommend-rankings', '20 19 * * *', -- モデレーション後
  $$SELECT net.http_post(url := '.../functions/v1/compute-recommend-rankings', ...)$$);
```

---

## 7. 追加提案（やった方がよいこと）

公開UGC（ユーザー生成コンテンツ）を初めて導入するため、安全・健全運用の観点で以下を強く推奨する。

1. **通報機能（§2.1 `recommendation_reports`）**: 各おすすめに「通報」。同一おすすめへの
   通報がしきい値（例: 3件）に達したら自動で非公開化＋再モデレーションキュー投入。
   AIモデレーションのすり抜けを人手/再判定で補う。
2. **ユーザーブロック/ミュート**: 特定ユーザーのおすすめを自分のフィードから除外。
   `user_blocks(blocker_id, blocked_id)` を新設。
3. **表示名・アバターのモデレーション**: 表示名が初めて公開される。不適切表示名対策として
   表示名変更時にも軽量チェック or 通報対象に含める。
4. **tier 連動の自動非公開**: おすすめ後にユーザーが tier を 2/3 未満へ下げた場合、
   そのおすすめを自動的に非公開（unpublish）にするルール（要件の整合）。トリガで実装。
5. **レート制限（不正対策）**: いいね/作成/通報の連打防止。
   - いいねはUNIQUE制約で多重防止済み。短時間大量いいねはサーバー側でレート制限。
   - おすすめ作成数の上限（例: 1日n件）。
6. **却下理由の本人通知 + 異議申し立て**: 却下時に reason を通知し、編集→再投稿の導線。
   誤判定（false positive）救済のため、運営問い合わせ窓口を案内。
7. **いいね到達通知（任意）**: 自分のおすすめが「初いいね」「100いいね」等の節目で通知。
   エンゲージメント向上。`notifications` に type を追加。
8. **年齢/R18方針の明文化**: R18を弾く方針なので、規約・ストア審査の整合を取る（§8で対応）。
9. **データ保持/削除整合**: アカウント削除時に recommendations・likes もカスケード削除
   （FK ON DELETE CASCADE で担保）。プライバシーポリシーの保持期間表に追記済み（§8）。
10. **多重ジャンル作品への対応余地**: `novels.source_work_id` は単一。クロスオーバー等で
    複数原作に跨る作品は将来 `novel_source_works` 中間テーブルへ拡張可能な設計にしておく。

---

## 8. 規約・プライバシーポリシーへの影響と対応

本機能は「ユーザーが公開するコンテンツ」「第三者AI（Gemini）への送信」「表示名の公開」を
新たに導入するため、以下を更新する（別ファイルで実施）。

### 8.1 利用規約（`docs/terms_of_service.md`）

- **第2条（サービス内容）**: おすすめ（推薦）機能の追加を明記。
- **第4条（禁止事項）**: おすすめへの R18・広告/宣伝・誹謗中傷/アンチ・無関係内容の投稿を禁止に追加。
- **新条（おすすめ機能・公開コンテンツ）**: 公開範囲、いいね、AIモデレーションによる非公開化・
  削除の権利、表示用の利用許諾、保証なし、通報の取扱いを規定。
- バージョン/最終更新日を更新 → `legal_documents` に新バージョン登録し、既存の
  同意再取得フロー（specification §12.2）で再同意を促す。

### 8.2 プライバシーポリシー（`docs/privacy_policy.md`）

- **1.1 収集情報**: おすすめ見出し・本文、いいね、（公開される）表示名を追加。
- **公開範囲の明示**: おすすめ・いいね・表示名・総いいね数が他ユーザーに公開される旨。
- **第三者提供**: Google（Gemini API）にモデレーション目的でおすすめ本文+小説メタを送信する旨。
- **保持期間**: recommendations / likes の保持・削除（アカウント削除でカスケード）。

※ 実際の追記は本コミットで両ファイルに反映する。

---

## 9. 実装メモ・残課題

- **moderation_status の改ざん防止**: クライアントの UPDATE で `moderation_status` /
  `moderation_reason` / `like_count` / `source_tier` が変えられないよう、列レベル GRANT を
  絞る（`GRANT UPDATE (heading, body, is_public) ON recommendations TO authenticated;`）。
  Edge Function はサービスロールで全列更新。
- **おまかせの実装場所**: まずクライアント抽選で素早く出し、負荷・品質を見て RPC/Edge へ移行。
- **source_work の名寄せ運用**: 初期はクロール由来 + 手動整備。表記揺れは `aliases` に集約。
- **Flutterモデル追加**: `lib/models/recommendation.dart`（+ `RecommendationAuthor`）,
  `lib/providers/recommendation_provider.dart`, `lib/screens/recommend/...`。
- **i18n / 文言**: 審査中・却下理由・公開非公開の文言を定義。
- **テスト**: tier制約トリガ、公開条件RLS、いいね二重防止、モデレーション判定のスナップショット。

---

## 付録A: マイグレーション SQL（ドラフト）

> ファイル名案: `supabase/migrations/20260607000001_add_recommendations.sql`
> 本文は §2 のテーブル定義・トリガ・RLS・インデックスを統合したもの。実装時に確定する。
