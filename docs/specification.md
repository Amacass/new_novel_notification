# Web小説更新通知アプリ 仕様書

> 本ドキュメントは `docs/requirements.md` の要件定義に基づく技術仕様書である。

---

## 目次

1. [システムアーキテクチャ概要](#1-システムアーキテクチャ概要)
2. [技術スタック詳細](#2-技術スタック詳細)
3. [データベース設計](#3-データベース設計)
4. [API設計](#4-api設計)
5. [画面設計](#5-画面設計)
6. [クローリング仕様](#6-クローリング仕様)
7. [プッシュ通知仕様](#7-プッシュ通知仕様)
8. [認証・セキュリティ](#8-認証セキュリティ)
9. [Share Extension仕様](#9-share-extension仕様)
10. [エラーハンドリング・リトライ戦略](#10-エラーハンドリングリトライ戦略)
11. [インフラ・コスト試算](#11-インフラコスト試算)
12. [利用規約・プライバシーポリシー](#12-利用規約プライバシーポリシー)

---

## 1. システムアーキテクチャ概要

### 1.1 全体構成図

```
┌─────────────────────────────────────────────────────┐
│                    クライアント                        │
│  ┌───────────────┐     ┌──────────────────────────┐  │
│  │  Flutter App   │     │  Share Extension (iOS)   │  │
│  │  (iOS/Android) │     │  URL → ブックマーク登録    │  │
│  └──────┬────────┘     └────────────┬─────────────┘  │
│         │                           │                 │
│  ┌──────┴───────────────────────────┴──────────┐     │
│  │         ローカルストレージ (SQLite)            │     │
│  │         - PDFファイル管理                     │     │
│  │         - オフラインキャッシュ                  │     │
│  └─────────────────────┬───────────────────────┘     │
└────────────────────────┼─────────────────────────────┘
                         │ HTTPS
┌────────────────────────┼─────────────────────────────┐
│                   Supabase                            │
│  ┌─────────────┐  ┌───┴──────────┐  ┌────────────┐  │
│  │   Auth       │  │  REST API    │  │  Realtime   │  │
│  │  (認証)      │  │ (自動生成)    │  │ (WebSocket) │  │
│  └─────────────┘  └──────────────┘  └────────────┘  │
│  ┌─────────────┐  ┌──────────────┐                   │
│  │  PostgreSQL  │  │Edge Functions│                   │
│  │  (データベース)│  │(クローリング) │                   │
│  └─────────────┘  └──────┬───────┘                   │
│  ┌─────────────┐         │                            │
│  │  pg_cron     │         │                            │
│  │ (定期実行)    │─────────┘                            │
│  └─────────────┘                                      │
└──────────────────────────┼────────────────────────────┘
                           │ HTTP/HTTPS
┌──────────────────────────┼────────────────────────────┐
│                    外部サービス                         │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ なろうAPI  │  │  ハーメルン    │  │   Arcadia    │    │
│  │(API経由)  │  │(スクレイピング) │  │(スクレイピング)│    │
│  └──────────┘  └──────────────┘  └──────────────┘    │
│  ┌──────────┐  ┌──────────────────────┐              │
│  │   FCM     │  │ Amazon アフィリエイト  │              │
│  │(プッシュ)  │  │ (広告)               │              │
│  └──────────┘  └──────────────────────┘              │
└───────────────────────────────────────────────────────┘
```

### 1.2 データフロー概要

```
【更新チェックフロー】
pg_cron (6時間毎) → Edge Function (crawl) → 各小説サイト (なろう / ハーメルン / Arcadia)
  → 新エピソード検知 → novels/episodes テーブル更新
  → notifications テーブルにINSERT
  → FCMでプッシュ通知送信

【ブックマーク登録フロー】
Flutter App / Share Extension → Supabase REST API
  → bookmarks テーブルにINSERT
  → Edge Function (即時更新チェック) → 小説メタデータ取得
  → novels テーブル UPSERT

【データ同期フロー】
Flutter App ← Supabase Realtime (WebSocket)
  → notifications の変更をリアルタイム受信
  → UIに即座に反映
```

---

## 2. 技術スタック詳細

### 2.1 フロントエンド (Flutter)

| カテゴリ | 技術 | 用途 |
|---------|------|------|
| フレームワーク | Flutter 3.x | クロスプラットフォームUI |
| 言語 | Dart 3.x | アプリロジック |
| 状態管理 | Riverpod | リアクティブな状態管理 |
| ルーティング | go_router | 宣言的ルーティング |
| Supabase連携 | supabase_flutter | Auth, DB, Realtime連携 |
| ローカルDB | sqflite | PDF管理, オフラインキャッシュ |
| プッシュ通知 | firebase_messaging | FCM受信 |
| HTTP通信 | dio | Share Extension等のHTTP処理 |
| テーマ | flex_color_scheme | ライト/ダークモード |
| PDF表示 | flutter_pdfview | ローカルPDF閲覧 |

### 2.2 バックエンド (Supabase)

| カテゴリ | 技術 | 用途 |
|---------|------|------|
| データベース | PostgreSQL 15 | メインデータストア |
| 認証 | Supabase Auth | ユーザー認証 (Email/Google/Apple) |
| API | PostgREST (自動生成) | CRUD操作 |
| リアルタイム | Supabase Realtime | WebSocketによるリアルタイム同期 |
| サーバーレス関数 | Edge Functions (Deno) | クローリング, ビジネスロジック |
| 定期実行 | pg_cron | クローリングスケジューリング |
| セキュリティ | RLS (Row Level Security) | データアクセス制御 |

### 2.3 外部サービス

| サービス | 用途 |
|---------|------|
| Firebase Cloud Messaging (FCM) | プッシュ通知 |
| Amazon Product Advertising API | アフィリエイト広告 |
| なろうAPI | 小説家になろうデータ取得 |

---

## 3. データベース設計

### 3.1 ER図

```
users ─────────┬──< bookmarks >──┬───── novels
               │                 │        │
               ├──< reviews >────┘        │
               │                     episodes
               ├──< favorite_authors >── authors
               │
               ├──< user_tags >──< bookmark_tags
               │
               └──< notifications
                                    crawl_logs
                                    fcm_tokens ──── users
```

### 3.2 テーブル定義

#### `profiles` - ユーザープロフィール

Supabase Auth の `auth.users` を拡張するプロフィールテーブル。

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | uuid | PK, FK → auth.users.id | ユーザーID |
| display_name | varchar(50) | NOT NULL | 表示名 |
| avatar_url | text | | アバター画像URL |
| theme_mode | varchar(10) | DEFAULT 'system' | 'light' / 'dark' / 'system' |
| notification_enabled | boolean | DEFAULT true | プッシュ通知有効 |
| created_at | timestamptz | DEFAULT now() | 作成日時 |
| updated_at | timestamptz | DEFAULT now() | 更新日時 |

#### `novels` - 小説マスターデータ

全ユーザー共通の小説情報。同じ小説を複数ユーザーがブックマークしても1レコード。

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| site | varchar(20) | NOT NULL | 'narou' / 'hameln' / 'arcadia' |
| site_novel_id | varchar(100) | NOT NULL | サイト固有の小説ID |
| url | text | NOT NULL | 小説トップページURL |
| title | varchar(500) | | 小説タイトル |
| author_name | varchar(200) | | 作者名 |
| author_id | bigint | FK → authors.id | 作者ID (紐付け可能な場合) |
| synopsis | text | | あらすじ |
| total_episodes | integer | DEFAULT 0 | 総話数 |
| latest_episode_id | varchar(100) | | 最新話のサイト固有ID |
| latest_episode_title | varchar(500) | | 最新話タイトル |
| serial_status | varchar(20) | DEFAULT 'ongoing' | 'ongoing' / 'completed' / 'hiatus' |
| site_updated_at | timestamptz | | サイト上の最終更新日時 |
| last_crawled_at | timestamptz | | 最終クロール日時 |
| crawl_error_count | integer | DEFAULT 0 | 連続クロールエラー回数 |
| created_at | timestamptz | DEFAULT now() | 作成日時 |
| updated_at | timestamptz | DEFAULT now() | 更新日時 |

**ユニーク制約**: `UNIQUE(site, site_novel_id)`

#### `episodes` - エピソード情報

各小説のエピソード（話）一覧。更新検知の差分チェックに使用。

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| novel_id | bigint | FK → novels.id, NOT NULL | 小説ID |
| site_episode_id | varchar(100) | NOT NULL | サイト固有のエピソードID |
| episode_number | integer | | 話数番号 |
| title | varchar(500) | | エピソードタイトル |
| published_at | timestamptz | | 公開日時 |
| created_at | timestamptz | DEFAULT now() | レコード作成日時 |

**ユニーク制約**: `UNIQUE(novel_id, site_episode_id)`

#### `authors` - 作者マスターデータ

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| site | varchar(20) | NOT NULL | サイト種別 |
| site_author_id | varchar(100) | NOT NULL | サイト固有の作者ID |
| name | varchar(200) | NOT NULL | 作者名 |
| profile_url | text | | 作者プロフィールURL |
| last_checked_at | timestamptz | | 最終チェック日時 |
| created_at | timestamptz | DEFAULT now() | 作成日時 |

**ユニーク制約**: `UNIQUE(site, site_author_id)`

#### `bookmarks` - ブックマーク

ユーザーと小説の紐付け。

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| user_id | uuid | FK → profiles.id, NOT NULL | ユーザーID |
| novel_id | bigint | FK → novels.id, NOT NULL | 小説ID |
| last_read_episode | integer | DEFAULT 0 | 既読話数（しおり） |
| memo | text | | 作品メモ（キャラ名等） |
| created_at | timestamptz | DEFAULT now() | ブックマーク日時 |
| updated_at | timestamptz | DEFAULT now() | 更新日時 |

**ユニーク制約**: `UNIQUE(user_id, novel_id)`

#### `reviews` - レビュー・感想

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| user_id | uuid | FK → profiles.id, NOT NULL | ユーザーID |
| novel_id | bigint | FK → novels.id, NOT NULL | 小説ID |
| rating | smallint | CHECK (1-5) | 星評価 (1〜5) |
| comment | text | | 感想テキスト |
| created_at | timestamptz | DEFAULT now() | 作成日時 |
| updated_at | timestamptz | DEFAULT now() | 更新日時 |

**ユニーク制約**: `UNIQUE(user_id, novel_id)`

#### `favorite_authors` - お気に入り作者

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| user_id | uuid | FK → profiles.id, NOT NULL | ユーザーID |
| author_id | bigint | FK → authors.id, NOT NULL | 作者ID |
| created_at | timestamptz | DEFAULT now() | 登録日時 |

**ユニーク制約**: `UNIQUE(user_id, author_id)`

#### `user_tags` - ユーザー定義タグ

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| user_id | uuid | FK → profiles.id, NOT NULL | ユーザーID |
| name | varchar(50) | NOT NULL | タグ名 |
| color | varchar(7) | | カラーコード (#RRGGBB) |
| created_at | timestamptz | DEFAULT now() | 作成日時 |

**ユニーク制約**: `UNIQUE(user_id, name)`

#### `bookmark_tags` - ブックマークへのタグ付け

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| bookmark_id | bigint | FK → bookmarks.id, NOT NULL | ブックマークID |
| tag_id | bigint | FK → user_tags.id, NOT NULL | タグID |

**主キー**: `PRIMARY KEY(bookmark_id, tag_id)`

#### `notifications` - 通知

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| user_id | uuid | FK → profiles.id, NOT NULL | 通知先ユーザーID |
| type | varchar(30) | NOT NULL | 通知種別 (後述) |
| novel_id | bigint | FK → novels.id | 関連小説ID |
| author_id | bigint | FK → authors.id | 関連作者ID |
| title | varchar(200) | NOT NULL | 通知タイトル |
| body | text | | 通知本文 |
| is_read | boolean | DEFAULT false | 既読フラグ |
| created_at | timestamptz | DEFAULT now() | 作成日時 |

**通知種別 (`type`)**:
- `new_episode` - 新エピソード公開
- `new_novel_by_author` - お気に入り作者の新作公開
- `novel_completed` - 作品完結

#### `fcm_tokens` - FCMデバイストークン

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| user_id | uuid | FK → profiles.id, NOT NULL | ユーザーID |
| token | text | NOT NULL, UNIQUE | FCMトークン |
| platform | varchar(10) | NOT NULL | 'ios' / 'android' |
| created_at | timestamptz | DEFAULT now() | 登録日時 |
| updated_at | timestamptz | DEFAULT now() | 更新日時 |

#### `crawl_logs` - クロールログ

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| novel_id | bigint | FK → novels.id | 対象小説ID |
| site | varchar(20) | NOT NULL | サイト種別 |
| status | varchar(20) | NOT NULL | 'success' / 'error' / 'skipped' |
| episodes_found | integer | DEFAULT 0 | 検出した新エピソード数 |
| error_message | text | | エラーメッセージ |
| duration_ms | integer | | 処理時間 (ms) |
| created_at | timestamptz | DEFAULT now() | 実行日時 |

### 3.3 インデックス

```sql
-- 高頻度クエリ用インデックス
CREATE INDEX idx_bookmarks_user_id ON bookmarks(user_id);
CREATE INDEX idx_bookmarks_novel_id ON bookmarks(novel_id);
CREATE INDEX idx_novels_site_updated ON novels(site_updated_at DESC);
CREATE INDEX idx_novels_site_novel ON novels(site, site_novel_id);
CREATE INDEX idx_episodes_novel_id ON episodes(novel_id);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX idx_reviews_user_id ON reviews(user_id);
CREATE INDEX idx_reviews_rating ON reviews(user_id, rating);
CREATE INDEX idx_favorite_authors_user ON favorite_authors(user_id);
CREATE INDEX idx_crawl_logs_novel ON crawl_logs(novel_id, created_at DESC);
CREATE INDEX idx_novels_crawl ON novels(last_crawled_at ASC NULLS FIRST) WHERE crawl_error_count < 5;
```

### 3.4 RLS (Row Level Security) ポリシー

```sql
-- profiles: 自分のプロフィールのみ読み書き可能
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE USING (auth.uid() = id);

-- novels: 全ユーザー読み取り可、書き込みはサーバーのみ
ALTER TABLE novels ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Novels are viewable by all authenticated users"
  ON novels FOR SELECT TO authenticated USING (true);

-- bookmarks: 自分のブックマークのみ
ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can CRUD own bookmarks"
  ON bookmarks FOR ALL USING (auth.uid() = user_id);

-- reviews: 自分のレビューのみ書き込み、全ユーザー読み取り可
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Reviews are viewable by all"
  ON reviews FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can CRUD own reviews"
  ON reviews FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own reviews"
  ON reviews FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own reviews"
  ON reviews FOR DELETE USING (auth.uid() = user_id);

-- notifications: 自分の通知のみ
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE USING (auth.uid() = user_id);

-- favorite_authors: 自分のお気に入りのみ
ALTER TABLE favorite_authors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can CRUD own favorite authors"
  ON favorite_authors FOR ALL USING (auth.uid() = user_id);

-- user_tags: 自分のタグのみ
ALTER TABLE user_tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can CRUD own tags"
  ON user_tags FOR ALL USING (auth.uid() = user_id);
```

---

## 4. API設計

### 4.1 Supabase REST API (自動生成)

PostgRESTにより、各テーブルに対するCRUD APIが自動生成される。
クライアントからは `supabase_flutter` SDK経由でアクセスする。

```dart
// 例: ブックマーク一覧取得（更新日時降順）
final bookmarks = await supabase
  .from('bookmarks')
  .select('*, novels(*)')
  .eq('user_id', userId)
  .order('novels.site_updated_at', ascending: false);
```

### 4.2 Edge Functions (カスタムAPI)

#### `POST /functions/v1/register-bookmark`

URLからの新規ブックマーク登録。小説メタデータの即時取得も行う。

**リクエスト:**
```json
{
  "url": "https://ncode.syosetu.com/n1234ab/"
}
```

**処理フロー:**
1. URLをパースし、サイト種別・小説IDを特定
2. `novels` テーブルに既存レコードがあるか確認
3. なければ小説メタデータを取得して `novels` に INSERT
4. `bookmarks` テーブルに INSERT
5. レスポンスを返却

**レスポンス:**
```json
{
  "bookmark_id": 123,
  "novel": {
    "id": 456,
    "site": "narou",
    "title": "小説タイトル",
    "author_name": "作者名",
    "total_episodes": 100,
    "site_updated_at": "2026-02-15T10:00:00Z"
  }
}
```

**エラーレスポンス:**
```json
{
  "error": "unsupported_site",
  "message": "このURLは対応していないサイトです"
}
```

#### `POST /functions/v1/crawl-updates`

定期クローリング実行。pg_cronから呼び出される。

**処理フロー:**
1. `novels` テーブルから、ブックマークされている全小説を `last_crawled_at` 昇順で取得
2. サイトごとにグループ化し、レート制限を守りながら順次アクセス
3. 新エピソードを検知した場合:
   - `episodes` テーブルに INSERT
   - `novels` テーブルを更新
   - 該当小説をブックマークしている全ユーザーの `notifications` に INSERT
   - FCMでプッシュ通知を送信
4. `crawl_logs` にログを記録

#### `POST /functions/v1/check-new-novels`

お気に入り作者の新作チェック。pg_cronから呼び出される。

**処理フロー:**
1. `favorite_authors` からお気に入り登録されている作者を取得
2. 各作者の作品一覧を取得（API or スクレイピング）
3. `novels` テーブルに存在しない新作があれば:
   - `novels` に INSERT
   - 該当作者をお気に入りにしている全ユーザーに通知

#### `POST /functions/v1/parse-novel-url`

URLのバリデーションとサイト判定。Share Extensionから呼ばれる。

**リクエスト:**
```json
{
  "url": "https://kakuyomu.jp/works/1177354054894358323"
}
```

**レスポンス:**
```json
{
  "valid": true,
  "site": "kakuyomu",
  "site_novel_id": "1177354054894358323",
  "normalized_url": "https://kakuyomu.jp/works/1177354054894358323"
}
```

#### `POST /functions/v1/register-fcm-token`

FCMトークンの登録・更新。

**リクエスト:**
```json
{
  "token": "fcm_token_string",
  "platform": "ios"
}
```

### 4.3 URL パースルール

各サイトのURL判定ロジック:

```
小説家になろう:
  パターン: https://ncode.syosetu.com/{ncode}/
  正規表現: ^https?://ncode\.syosetu\.com/([nN]\d+[a-zA-Z]+)/?
  小説ID: ncode (例: n1234ab)

ハーメルン:
  パターン: https://syosetu.org/novel/{novel_id}/
  正規表現: ^https?://syosetu\.org/novel/(\d+)/?
  小説ID: novel_id (例: 123456)

Arcadia:
  パターン: http://www.mai-net.net/bbs/sst/sst.php?act=dump&cate={cate}&all={story_id}
  正規表現: ^https?://www\.mai-net\.net/bbs/sst/sst\.php\?.*all=(\d+).*cate=(\w+)
  小説ID: {cate}_{story_id} (例: naruto_12345)
```

---

## 5. 画面設計

### 5.1 画面一覧・遷移図

```
                 ┌──────────┐
                 │ スプラッシュ │
                 └────┬─────┘
                      │
            ┌─────────┴─────────┐
            │                   │
    ┌───────▼──────┐   ┌───────▼──────┐
    │  ログイン画面  │   │   ホーム画面   │
    │              │   │  (認証済み)    │
    └───────┬──────┘   └───────┬──────┘
            │                   │
    ┌───────▼──────┐           │
    │  新規登録画面  │           │
    └──────────────┘           │
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼──────┐  ┌────────────▼──────┐  ┌────────────▼────┐
│ ブックマーク   │  │    更新フィード    │  │     設定画面     │
│   一覧画面    │  │      (タブ1)      │  │                 │
└───────┬──────┘  └──────────────────┘  └─────────────────┘
        │
┌───────▼──────┐
│  小説詳細画面  │──┬── レビュー編集
│              │  ├── メモ編集
│              │  ├── PDF管理
│              │  └── タグ編集
└──────────────┘

┌──────────────┐
│お気に入り作者  │
│  一覧画面     │──── 作者詳細画面
└──────────────┘
```

### 5.2 タブ構成 (BottomNavigationBar)

| タブ | アイコン | 画面 |
|------|---------|------|
| ホーム | home | 更新フィード画面 |
| ブックマーク | bookmark | ブックマーク一覧画面 |
| 作者 | person | お気に入り作者一覧画面 |
| 設定 | settings | 設定画面 |

### 5.3 各画面仕様

#### 5.3.1 スプラッシュ画面

- アプリロゴを表示
- Supabase Auth のセッション確認
- 認証済み → ホーム画面へ遷移
- 未認証 → ログイン画面へ遷移

#### 5.3.2 ログイン画面

```
┌─────────────────────────┐
│                         │
│      [アプリロゴ]        │
│                         │
│  ┌───────────────────┐  │
│  │ メールアドレス       │  │
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │ パスワード          │  │
│  └───────────────────┘  │
│                         │
│  [     ログイン     ]    │
│                         │
│  ── または ──            │
│                         │
│  [ Googleでログイン  ]   │
│  [ Appleでログイン   ]   │
│                         │
│  新規登録はこちら →      │
│                         │
└─────────────────────────┘
```

**機能:**
- Email/Password ログイン
- Googleログイン (OAuth)
- Apple ID ログイン (iOS)
- 新規登録画面への遷移
- パスワードリセット

#### 5.3.3 更新フィード画面 (ホームタブ)

```
┌─────────────────────────┐
│ 更新フィード    [通知ベル] │
├─────────────────────────┤
│ ┌─────────────────────┐ │
│ │ [N] 転生したら...    │ │
│ │ 第245話 公開         │ │
│ │ 小説家になろう        │ │
│ │ 2時間前  ★★★★★      │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ [H] 運命の...        │ │
│ │ 第89話 公開          │ │
│ │ ハーメルン            │ │
│ │ 5時間前  ★★★★☆      │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ [A] 英雄の...        │ │
│ │ 第56話 公開          │ │
│ │ Arcadia             │ │
│ │ 1日前    未評価       │ │
│ └─────────────────────┘ │
│         ...             │
│                         │
│ ─── Amazon広告バナー ─── │
│                         │
├─────────────────────────┤
│ [ホーム][BM][作者][設定]  │
└─────────────────────────┘
```

**機能:**
- ブックマーク中の小説の更新情報を更新日時降順で表示
- サイト種別を示すアイコンバッジ ([N]なろう, [H]ハーメルン, [A]Arcadia)
- 星評価の表示
- 未読エピソード数のバッジ表示
- プルダウンリフレッシュ
- タップで小説詳細画面へ遷移
- 右上の通知ベルに未読通知数バッジ
- フィードの合間にAmazonアフィリエイト広告を挿入（5件に1件程度）

#### 5.3.4 ブックマーク一覧画面

```
┌─────────────────────────┐
│ ブックマーク   [フィルタ]  │
├─────────────────────────┤
│ [全て][★5][★4][★3]...   │
│ [タグ: 異世界][完結済]    │
├─────────────────────────┤
│ ソート: 更新日▼ / 評価 /  │
│        タイトル / 登録日   │
├─────────────────────────┤
│ ┌─────────────────────┐ │
│ │ 転生したら...        │ │
│ │ 作者名  245話        │ │
│ │ ★★★★★ 未読: 3話     │ │
│ │ [異世界][連載中]      │ │
│ └─────────────────────┘ │
│         ...             │
├─────────────────────────┤
│ [ホーム][BM][作者][設定]  │
└─────────────────────────┘
```

**機能:**
- 星評価フィルタ（★1〜★5、未評価）
- タグフィルタ（複数選択可）
- ソート切り替え（更新日 / 評価 / タイトル / 登録日）
- 連載ステータスフィルタ（連載中 / 完結 / 長期未更新）
- スワイプで削除（確認ダイアログ付き）
- 未読話数バッジ

#### 5.3.5 小説詳細画面

```
┌─────────────────────────┐
│ ← 戻る                  │
├─────────────────────────┤
│                         │
│ 転生したらスライムだった件 │
│ 作者: 伏瀬              │
│ 小説家になろう            │
│ 連載中 ・ 全245話        │
│                         │
│ ── しおり ──             │
│ 既読: 第242話まで        │
│ [未読3話を確認する →]     │
│                         │
│ ── 評価・感想 ──         │
│ ★★★★★                  │
│ テンポが良くて面白い。     │
│ 主人公が...              │
│ [編集]                   │
│                         │
│ ── メモ ──              │
│ リムル=テンペスト(主人公)  │
│ [編集]                   │
│                         │
│ ── タグ ──              │
│ [異世界] [転生] [+追加]   │
│                         │
│ ── PDF ──               │
│ 📄 1-50話.pdf           │
│ 📄 51-100話.pdf         │
│ [+ PDFを追加]            │
│                         │
│ ── エピソード一覧 ──     │
│ 第245話 新たなる旅立ち    │
│ 第244話 決戦の時         │
│ ...                     │
│                         │
│ [サイトで読む]            │
│                         │
└─────────────────────────┘
```

**機能:**
- 小説メタデータの表示
- しおり（既読管理）の表示と更新
- 「サイトで読む」ボタンで外部ブラウザを起動
- レビュー（星評価 + 感想テキスト）の表示・編集
- メモの表示・編集
- タグの表示・追加・削除
- PDF一覧の表示・追加・削除・閲覧
- エピソード一覧（降順表示、既読マーク付き）
- 作者名タップで作者詳細画面へ

#### 5.3.6 お気に入り作者一覧画面

```
┌─────────────────────────┐
│ お気に入り作者            │
├─────────────────────────┤
│ ┌─────────────────────┐ │
│ │ 伏瀬                 │ │
│ │ 小説家になろう  作品3件 │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │ 作者B               │ │
│ │ ハーメルン    作品1件  │ │
│ └─────────────────────┘ │
│         ...             │
├─────────────────────────┤
│ [ホーム][BM][作者][設定]  │
└─────────────────────────┘
```

**機能:**
- お気に入り作者の一覧表示
- 各作者の作品数表示
- タップで作者詳細画面（作品一覧）へ遷移
- スワイプでお気に入り解除

#### 5.3.7 設定画面

```
┌─────────────────────────┐
│ 設定                     │
├─────────────────────────┤
│                         │
│ ── アカウント ──         │
│ メールアドレス            │
│ パスワード変更            │
│                         │
│ ── 表示 ──              │
│ テーマ    [システム ▼]    │
│           ライト/ダーク    │
│                         │
│ ── 通知 ──              │
│ プッシュ通知  [ON/OFF]    │
│ 新エピソード  [ON/OFF]    │
│ 新作通知      [ON/OFF]    │
│ 完結通知      [ON/OFF]    │
│                         │
│ ── データ ──            │
│ データエクスポート         │
│ データインポート          │
│                         │
│ ── その他 ──            │
│ 利用規約                 │
│ プライバシーポリシー       │
│ ライセンス               │
│ バージョン: 1.0.0        │
│                         │
│ [ログアウト]              │
│                         │
├─────────────────────────┤
│ [ホーム][BM][作者][設定]  │
└─────────────────────────┘
```

**機能:**
- テーマ切り替え（ライト / ダーク / システム連動）
- 通知設定（種別ごとにON/OFF）
- データエクスポート（JSON形式でブックマーク・レビュー・タグを出力）
- データインポート（エクスポートしたJSONを読み込み）
- 利用規約の表示（アプリ内WebView）
- プライバシーポリシーの表示（アプリ内WebView）
- オープンソースライセンスの表示
- アカウント削除（確認ダイアログ → Supabase Auth経由で削除 → 30日後に完全削除）
- ログアウト

#### 5.3.8 通知一覧画面

```
┌─────────────────────────┐
│ ← 通知                  │
├─────────────────────────┤
│ ┌─────────────────────┐ │
│ │ 🔵 新エピソード公開   │ │
│ │ 転生したら... 第245話 │ │
│ │ 2時間前              │ │
│ └─────────────────────┘ │
│ ┌─────────────────────┐ │
│ │    伏瀬さんの新作    │ │
│ │ 「新しい物語」が公開  │ │
│ │ 1日前               │ │
│ └─────────────────────┘ │
│         ...             │
│                         │
│ [全て既読にする]          │
└─────────────────────────┘
```

---

## 6. クローリング仕様

### 6.1 スケジューリング

```sql
-- pg_cron設定: 6時間ごとに更新チェック
SELECT cron.schedule(
  'crawl-novel-updates',
  '0 */6 * * *',
  $$SELECT net.http_post(
    url := 'https://<project>.supabase.co/functions/v1/crawl-updates',
    headers := '{"Authorization": "Bearer <service_role_key>"}'::jsonb
  )$$
);

-- pg_cron設定: 12時間ごとにお気に入り作者の新作チェック
SELECT cron.schedule(
  'check-new-novels',
  '0 3,15 * * *',
  $$SELECT net.http_post(
    url := 'https://<project>.supabase.co/functions/v1/check-new-novels',
    headers := '{"Authorization": "Bearer <service_role_key>"}'::jsonb
  )$$
);
```

### 6.2 サイト別取得ロジック

#### 小説家になろう (API)

```
エンドポイント: https://api.syosetu.com/novelapi/api/
パラメータ:
  - ncode: 小説ID
  - of: t-w-ga-gl-nu (title, writer, general_all_no, general_lastup, novelupdated_at)
  - out: json
  - gzip: 5

レート制限: 80,000リクエスト/日 or 400MB/日
推奨間隔: 1秒/リクエスト

更新検知ロジック:
  1. APIからnovelupdated_at (最終更新日時) とgeneral_all_no (総話数) を取得
  2. DBの novels.site_updated_at と比較
  3. 変更があれば novels テーブルを更新
  4. 新エピソードの詳細は目次ページから取得 (https://ncode.syosetu.com/{ncode}/)
```

#### ハーメルン (スクレイピング)

```
目次URL: https://syosetu.org/novel/{novel_id}/
User-Agent: NovelNotificationApp/1.0 (contact: <developer email>)

レート制限: 3秒/リクエスト以上

更新検知ロジック:
  1. 目次ページのHTMLを取得
  2. エピソード一覧をパース（<a>タグから話数・タイトル・URL抽出）
  3. DB上の最新話数と比較
  4. 新エピソードがあれば episodes テーブルに INSERT

403対策:
  - 適切なUser-Agent設定
  - Cookie管理（セッション維持）
  - リクエスト間隔を十分に空ける（3秒以上）
  - 連続403の場合はバックオフ（5分 → 30分 → 6時間）
```

#### Arcadia (スクレイピング)

```
作品URL: http://www.mai-net.net/bbs/sst/sst.php?act=dump&cate={cate}&all={story_id}
※ HTTP only (SSL期限切れ)

レート制限: 5秒/リクエスト以上 (サーバーが脆弱なため)

更新検知ロジック:
  1. 作品ページのHTMLを取得
  2. BBS投稿一覧をパースし、最新の投稿番号を特定
  3. DB上の情報と比較
  4. 新しい投稿があれば更新

注意事項:
  - HTTPのみのため、通信内容は暗号化されない
  - サイトの存続が不安定であることをユーザーに通知
  - クロールエラーが継続する場合、自動的にスキップ
```

### 6.3 クロール実行フロー

```
crawl-updates Edge Function 全体フロー:

1. novels テーブルから対象小説を取得
   SELECT * FROM novels
   WHERE id IN (SELECT DISTINCT novel_id FROM bookmarks)
   AND crawl_error_count < 5
   ORDER BY last_crawled_at ASC NULLS FIRST

2. サイトごとにグループ化
   narou_novels    = [...]
   hameln_novels   = [...]
   arcadia_novels  = [...]

3. 各サイトを並行処理 (サイト間は並行、同一サイト内は直列)
   ┌─ narou:    1秒間隔で順次処理
   ├─ hameln:   3秒間隔で順次処理
   └─ arcadia:  5秒間隔で順次処理

4. 各小説の処理:
   a. メタデータ取得 (API or スクレイピング)
   b. 前回との差分チェック
   c. 新エピソードがあれば:
      - episodes テーブルに INSERT
      - novels テーブルを UPDATE
      - ブックマーク中の全ユーザーを取得
      - notifications テーブルに一括 INSERT
      - FCM通知送信 (バッチ)
   d. crawl_logs にログ記録
   e. novels.last_crawled_at を更新

5. Edge Functionのタイムアウト対策:
   - Supabase Edge Functions のタイムアウト: 最大150秒
   - 対象小説が多い場合、バッチ分割して複数回実行
   - 1回の実行で処理する上限: 50小説
   - 残りがあれば次のバッチを自分自身を呼び出して処理
```

### 6.4 他ユーザーブックマーク時の即時更新

```
bookmarks テーブルへの INSERT をトリガーにして:

1. PostgreSQL トリガー関数:
   - INSERT時に該当 novel の last_crawled_at を確認
   - 6時間以上経過していれば Edge Function を呼び出し
   - 即座にメタデータを最新化

2. Edge Function (register-bookmark) が代替:
   - ブックマーク登録時に小説メタデータを取得
   - novels テーブルが未登録 or 古い場合は更新
```

---

## 7. プッシュ通知仕様

### 7.1 アーキテクチャ

```
Edge Function (crawl-updates)
  │
  ├─ 新エピソード検知
  │
  ├─ notifications テーブル INSERT
  │
  └─ FCM API呼び出し
       │
       ├─ FCM (Firebase Cloud Messaging)
       │    │
       │    └─ APNs (iOS) / FCM (Android)
       │         │
       │         └─ ユーザーのデバイス
       │
       └─ バッチ送信 (1リクエストで最大500デバイス)
```

### 7.2 FCM連携

```
Edge FunctionからFCM HTTP v1 APIを呼び出す:

POST https://fcm.googleapis.com/v1/projects/{project_id}/messages:send
Authorization: Bearer {access_token}

{
  "message": {
    "token": "{device_fcm_token}",
    "notification": {
      "title": "小説の更新があります",
      "body": "「転生したら...」第245話が公開されました"
    },
    "data": {
      "type": "new_episode",
      "novel_id": "456",
      "click_action": "OPEN_NOVEL_DETAIL"
    },
    "apns": {
      "payload": {
        "aps": {
          "badge": 3,
          "sound": "default"
        }
      }
    }
  }
}
```

### 7.3 通知トリガー条件

| トリガー | 条件 | 通知タイトル | 通知本文 |
|---------|------|------------|---------|
| 新エピソード | ブックマーク中の小説に新話公開 | 小説の更新があります | 「{title}」第{n}話が公開されました |
| 新作通知 | お気に入り作者の新しい小説 | お気に入り作者の新作 | {author}さんの新作「{title}」が公開されました |
| 完結通知 | ブックマーク中の小説が完結 | 小説が完結しました | 「{title}」が完結しました（全{n}話） |

### 7.4 バッジ管理

- 未読通知数をアプリアイコンのバッジ数として表示
- 通知一覧画面を開くとバッジ数をリセット
- 「全て既読にする」で全通知を既読化

### 7.5 まとめ通知

同一ユーザーに短時間で複数の更新がある場合:
- 1分以内に3件以上の通知が発生した場合はまとめ通知にする
- タイトル: 「{n}件の小説が更新されました」
- 本文: 各小説名をリスト表示

---

## 8. 認証・セキュリティ

### 8.1 認証方式

Supabase Auth を利用し、以下の認証方式を提供:

| 方式 | 用途 |
|------|------|
| Email + Password | メイン認証。新規登録・ログイン |
| Google OAuth | ソーシャルログイン |
| Apple Sign In | iOS向け。App Store要件 |

### 8.2 セッション管理

- Supabase Auth のJWTトークンベース
- アクセストークン有効期限: 1時間
- リフレッシュトークンによる自動更新
- `supabase_flutter` SDKがトークン管理を自動化

### 8.3 新規ユーザー登録フロー

```
1. ユーザーがサインアップ (email/password or OAuth)
2. Supabase Auth が auth.users にレコード作成
3. PostgreSQL トリガーで profiles テーブルに自動 INSERT:

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name', 'ユーザー'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

### 8.4 データ移行 (iOS ↔ Android)

ユーザーデータは全てSupabase (サーバー側) に保存されているため、端末移行は以下の手順で完了:

1. 新端末でアプリをインストール
2. 同じアカウント（Email or OAuth）でログイン
3. ブックマーク・レビュー・タグ等は自動同期

**ローカルデータ（PDF）の移行:**
- 設定画面の「データエクスポート」でPDFを含むZIPファイルを生成
- ファイル共有（AirDrop, Google Drive等）で新端末に転送
- 新端末で「データインポート」を実行

### 8.5 セキュリティ対策

| 項目 | 対策 |
|------|------|
| 通信暗号化 | 全てHTTPS (Supabase標準) |
| SQL Injection | Supabase SDK + RLS によりプリペアドステートメント |
| 認可 | RLSポリシーでユーザーごとのデータアクセス制御 |
| API キー管理 | service_role_key はEdge Functionsの環境変数のみ |
| FCMトークン | ユーザーごとに管理、ログアウト時に削除 |
| クローリング資格情報 | Edge Functionsの Supabase Secrets に格納 |

---

## 9. Share Extension仕様

### 9.1 概要

iOSのShare Extensionを利用し、Safariで閲覧中の小説ページURLをワンアクションでブックマーク登録する。

### 9.2 処理フロー

```
1. ユーザーがSafariで小説ページを閲覧
2. 共有ボタン → アプリアイコンを選択
3. Share Extension起動

┌─────────────────────────┐
│ Web小説をブックマーク      │
├─────────────────────────┤
│                         │
│ URL: https://ncode...   │
│ サイト: 小説家になろう ✓   │
│                         │
│ [ブックマークに追加]      │
│ [キャンセル]              │
│                         │
└─────────────────────────┘

4. URLをバリデーション (parse-novel-url Edge Function)
5. 対応サイトであれば register-bookmark Edge Function を呼び出し
6. 成功 → 完了メッセージ表示、Extension終了
7. 失敗 → エラーメッセージ表示
```

### 9.3 URL判定ロジック

```dart
class NovelUrlParser {
  static NovelSite? parseSite(String url) {
    final uri = Uri.parse(url);

    // 小説家になろう
    if (uri.host == 'ncode.syosetu.com') {
      final match = RegExp(r'/([nN]\d+[a-zA-Z]+)').firstMatch(uri.path);
      if (match != null) return NovelSite.narou(match.group(1)!);
    }

    // ハーメルン
    if (uri.host == 'syosetu.org') {
      final match = RegExp(r'/novel/(\d+)').firstMatch(uri.path);
      if (match != null) return NovelSite.hameln(match.group(1)!);
    }

    // Arcadia
    if (uri.host == 'www.mai-net.net') {
      final all = uri.queryParameters['all'];
      final cate = uri.queryParameters['cate'];
      if (all != null && cate != null) {
        return NovelSite.arcadia('${cate}_$all');
      }
    }

    return null; // 非対応サイト
  }
}
```

### 9.4 Flutterでの実装方針

- `receive_sharing_intent` パッケージでShare Extensionを実装
- App Group を使ってメインアプリとExtension間でSupabaseセッションを共有
- 認証状態がない場合は「アプリを開いてログインしてください」と表示

---

## 10. エラーハンドリング・リトライ戦略

### 10.1 クローリングエラー

| エラー種別 | HTTP Status | 対処 |
|-----------|-------------|------|
| 一時的エラー | 5xx, タイムアウト | 指数バックオフでリトライ (5分 → 30分 → 6時間) |
| レート制限 | 429 | Retry-Afterヘッダに従って待機 |
| アクセス拒否 | 403 | バックオフ + User-Agent確認 |
| ページ不存在 | 404 | 小説が削除された可能性 → ユーザーに通知 |
| パースエラー | - | サイトのHTML構造変更 → crawl_logsに記録、手動対応 |

### 10.2 エラーカウントによる自動スキップ

```
novels.crawl_error_count の管理:
- クロール成功時: 0にリセット
- クロール失敗時: +1
- crawl_error_count >= 5: 自動スキップ (クロール対象から除外)
- ユーザーが手動更新した場合: リセットして再試行
```

### 10.3 クライアント側エラーハンドリング

| エラー種別 | ユーザーへの表示 |
|-----------|---------------|
| ネットワークエラー | 「通信エラーが発生しました。再試行してください」 |
| 認証エラー (401) | 自動リフレッシュ → 失敗時はログイン画面へ |
| サーバーエラー (5xx) | 「サーバーエラーが発生しました。しばらくしてから再試行してください」 |
| 非対応URL | 「このURLは対応していません。対応サイト: ...」 |
| 既にブックマーク済み | 「この小説は既にブックマークされています」 |

### 10.4 Edge Function タイムアウト対策

```
Supabase Edge Functions の制限:
- 実行時間: 最大150秒 (Free plan)
- メモリ: 150MB

対策:
- 1回のクロール実行で処理する上限を50小説に制限
- 残りがあれば crawl_queue テーブル or 自己呼び出しで次バッチに委譲
- 各サイトへのリクエストタイムアウト: 10秒
```

---

## 11. インフラ・コスト試算

### 11.1 Supabase Free Plan の制約

| リソース | 無料枠 | 想定使用量 | 余裕 |
|---------|--------|-----------|------|
| データベース | 500MB | 〜50MB (初期) | 十分 |
| Auth | 50,000 MAU | 〜1,000 MAU (初期) | 十分 |
| Edge Functions | 500,000 呼び出し/月 | 〜5,000回/月 | 十分 |
| Edge Functions 実行時間 | 合計なし (150秒/回) | - | 注意 |
| Realtime | 200 同時接続 | 〜50 | 十分 |
| Storage | 1GB | 不使用 (PDFはローカル) | - |
| 帯域 | 5GB/月 | 〜1GB/月 | 十分 |

### 11.2 Firebase Free Plan (FCMのみ)

| リソース | 無料枠 | 想定使用量 |
|---------|--------|-----------|
| FCMメッセージ | 無制限 | 制限なし |
| Cloud Functions (FCM用) | 不要 | Edge Functionから直接呼び出し |

### 11.3 スケーリング時の想定コスト

ユーザー数が増加した場合:

| ユーザー数 | 想定月額コスト | 主なボトルネック |
|-----------|-------------|---------------|
| 〜1,000 | $0 (無料枠内) | - |
| 1,000〜5,000 | $25/月 (Pro plan) | Edge Functions実行回数 |
| 5,000〜 | $25+ | DB容量, 帯域 |

### 11.4 コスト最適化戦略

- **クロール対象の効率化**: 複数ユーザーが同じ小説をブックマークしても1回のクロールで済む設計
- **なろうAPIのgzip圧縮**: 帯域節約
- **Realtimeの活用**: ポーリングではなくWebSocketで更新を受け取ることでAPI呼び出しを削減
- **ローカルキャッシュ**: 小説メタデータをSQLiteにキャッシュし、サーバーリクエストを削減

---

## 付録A: 連載ステータス自動判定ロジック

```
serial_status の自動判定:

ongoing (連載中):
  - 最終更新から30日以内

hiatus (長期未更新):
  - 最終更新から30日以上180日未満
  - ※なろうAPIの場合、end フラグが立っていなければ hiatus

completed (完結):
  - なろうAPI: end = 1 のフラグ
  - その他: 目次ページに「完結」表記があるか判定
  - 手動設定も可能
```

## 付録B: Amazon アフィリエイト連携仕様

```
Product Advertising API 5.0 (PA-API):

検索ロジック:
  1. novels.title から書籍化されている作品を検索
  2. SearchItems オペレーション:
     - Keywords: 小説タイトル
     - SearchIndex: "Books"
     - ItemCount: 3
  3. レスポンスから書影URL・価格・AmazonリンクをGET
  4. フィード画面の5件に1件の割合で広告カードとして表示

キャッシュ戦略:
  - 検索結果は24時間キャッシュ
  - novels テーブルに amazon_asin カラムを追加し、
    一度紐付いた書籍は再検索しない

収益還元:
  - アフィリエイトリンク経由の購入で作者の書籍売上に貢献
  - アプリ説明文に趣旨を明記
```

---

## 12. 利用規約・プライバシーポリシー

### 12.1 ドキュメント一覧

| ドキュメント | ファイル | 表示場所 |
|------------|---------|---------|
| 利用規約 | `docs/terms_of_service.md` | 設定画面 > その他 > 利用規約 |
| プライバシーポリシー | `docs/privacy_policy.md` | 設定画面 > その他 > プライバシーポリシー |

### 12.2 同意フロー

```
【初回登録時】
新規登録画面
  └─ 「アカウントを作成することで、[利用規約] および
      [プライバシーポリシー] に同意したものとみなされます。」
      ※ 各リンクをタップするとアプリ内WebViewで全文表示

【規約変更時】
アプリ起動
  └─ サーバー側で規約バージョンを管理
      └─ ユーザーの同意済みバージョン < 最新バージョン の場合
          └─ 規約変更通知ダイアログを表示
              ├─ [変更内容を確認] → WebViewで差分を表示
              └─ [同意する] → 同意バージョンを更新
              ※ 同意するまでアプリの主要機能は利用不可
```

### 12.3 規約バージョン管理

#### `legal_documents` テーブル

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| type | varchar(30) | NOT NULL | 'terms_of_service' / 'privacy_policy' |
| version | varchar(20) | NOT NULL | バージョン (例: '1.0.0') |
| content_url | text | NOT NULL | ドキュメントURL |
| summary_of_changes | text | | 変更概要（変更時のダイアログに表示） |
| effective_date | date | NOT NULL | 発効日 |
| created_at | timestamptz | DEFAULT now() | 作成日時 |

**ユニーク制約**: `UNIQUE(type, version)`

#### `user_consents` テーブル

| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | bigint | PK, GENERATED | 内部ID |
| user_id | uuid | FK → profiles.id, NOT NULL | ユーザーID |
| legal_document_id | bigint | FK → legal_documents.id, NOT NULL | 同意した規約ID |
| consented_at | timestamptz | DEFAULT now() | 同意日時 |
| ip_address | inet | | 同意時のIPアドレス |

**ユニーク制約**: `UNIQUE(user_id, legal_document_id)`

#### RLSポリシー

```sql
-- legal_documents: 全ユーザー読み取り可
ALTER TABLE legal_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Legal docs are viewable by all"
  ON legal_documents FOR SELECT TO authenticated USING (true);

-- user_consents: 自分の同意記録のみ
ALTER TABLE user_consents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own consents"
  ON user_consents FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own consents"
  ON user_consents FOR INSERT WITH CHECK (auth.uid() = user_id);
```

### 12.4 Edge Function

#### `GET /functions/v1/check-legal-updates`

ユーザーが未同意の規約があるかチェックする。アプリ起動時に呼び出す。

**レスポンス (更新なし):**
```json
{
  "updates_required": false
}
```

**レスポンス (更新あり):**
```json
{
  "updates_required": true,
  "documents": [
    {
      "type": "privacy_policy",
      "version": "1.1.0",
      "content_url": "https://example.com/privacy-policy-v1.1",
      "summary_of_changes": "第三者サービスにXXを追加しました",
      "effective_date": "2026-03-01"
    }
  ]
}
```

#### `POST /functions/v1/record-consent`

ユーザーの同意を記録する。

**リクエスト:**
```json
{
  "legal_document_id": 3
}
```

### 12.5 利用規約の主要ポイント

| セクション | 概要 |
|-----------|------|
| サービス内容 | 更新通知サービスであり、小説本文の閲覧機能は提供しない |
| 禁止事項 | サーバー過負荷行為、不正アクセス、成りすまし等 |
| 免責事項 | 更新情報の遅延・欠落、対象サイトの仕様変更による影響 |
| 広告 | Amazonアソシエイト・プログラムの参加者である旨を明記 |
| 準拠法 | 日本法 |

### 12.6 プライバシーポリシーの主要ポイント

| セクション | 概要 |
|-----------|------|
| 収集情報 | メール、表示名、ブックマーク、レビュー、FCMトークン等 |
| 非収集情報 | 位置情報、連絡先、小説本文、対象サイトのアカウント情報 |
| 第三者共有 | Supabase, Firebase, Google, Apple, Amazon (それぞれ目的と範囲を明記) |
| データ保持 | アカウント削除後30日で完全削除 |
| ユーザー権利 | アクセス権、訂正権、削除権、データポータビリティ、通知オプトアウト |
| セキュリティ | TLS, bcrypt, RLS, JWT |
| トラッキング | Cookie不使用、行動トラッキング不実施 |

### 12.7 App Store 審査対応

Apple App Store の審査ガイドラインに準拠するため:

- アプリ内から利用規約・プライバシーポリシーの全文にアクセスできること
- App Store Connect の「App Privacy」セクションにデータ収集内容を正確に申告
- アカウント削除機能を提供すること（設定画面から実行可能）
- 「Sign in with Apple」を提供すること（他のソーシャルログインがある場合は必須）
