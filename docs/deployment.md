# デプロイ手順書

## 環境一覧

| 環境 | Supabase プロジェクト | ref ID |
|------|----------------------|--------|
| 開発 (development) | novel-notification-dev | `oszscaegphdrdlypofqi` |
| 本番 (production) | novel-notification | `zrxsapgvlflxitddeqcn` |

---

## 1. ローカル開発

### Flutter アプリの起動

```bash
# 開発DB に向けて起動（デフォルト）
make run-dev

# 本番DB に向けて起動（確認用）
make run-prod
```

FLAVOR dart-define が未指定の場合は `development` になります。

### 環境ファイル

| ファイル | 用途 |
|---------|------|
| `.env.development` | 開発DB の接続情報 |
| `.env.production` | 本番DB の接続情報 |

どちらも `.gitignore` で管理外です。新しい開発者が参加した際は手動でコピーしてください。

---

## 2. DBマイグレーション（カラム・テーブル追加など）

### 基本フロー

```
開発DBで試す → 動作確認 → 本番DBに反映
```

### 手順

#### Step 1: マイグレーションファイルを作成

```bash
# supabase/migrations/ 以下に新しいファイルを作成
# ファイル名: YYYYMMDDHHMMSS_説明.sql
# 例: 20260602000001_add_user_settings.sql
```

**命名規則**: タイムスタンプは既存ファイルより大きい値にする。

#### Step 2: 開発DBに適用

```bash
make migrate-dev
# → supabase link (dev) → supabase db push
```

`supabase db push` はローカルに存在してリモートに未適用のマイグレーションのみ実行します。

#### Step 3: 動作確認

開発環境（`make run-dev`）で新しいカラム・テーブルを使った機能を確認する。

#### Step 4: 本番DBに反映

```bash
make migrate-prod
# → supabase link (prod) → supabase db push
```

> **注意**: 本番への適用後は元に戻せません。`supabase db push --dry-run` で事前確認を推奨します。

### 破壊的変更（カラム削除・リネーム）のルール

1. 先にアプリ側のコードを更新してリリース（旧カラム参照をなくす）
2. その後マイグレーションでカラムを削除

---

## 3. Edge Functions のデプロイ

### 開発環境に反映

```bash
make deploy-functions-dev
```

### 本番環境に反映

```bash
make deploy-functions-prod
```

`--prune` フラグを付けると、ローカルに存在しない Function がリモートから削除されます（通常は不要）。

### Secrets（環境変数）の管理

Edge Functions 内で使う秘密情報は `supabase secrets` で管理します。

```bash
# 開発に設定
supabase link --project-ref oszscaegphdrdlypofqi
supabase secrets set MY_SECRET=value

# 本番に設定
supabase link --project-ref zrxsapgvlflxitddeqcn
supabase secrets set MY_SECRET=value
```

`SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` は Supabase が自動注入するため設定不要。

---

## 4. アプリリリース（App Store / Google Play）

### iOS

```bash
make build-ios-prod
# → flutter build ipa --dart-define=FLAVOR=production
```

生成された `build/ios/ipa/*.ipa` を Xcode Organizer または `xcrun altool` でアップロード。

### Android

```bash
make build-android-prod
# → flutter build appbundle --dart-define=FLAVOR=production
```

生成された `build/app/outputs/bundle/release/app-release.aab` を Google Play Console にアップロード。

---

## 5. 初回セットアップ（新しい Supabase 環境を立てる際）

新しいプロジェクトを作ったときは以下の手順が必要です。

#### pg_cron の有効化

Supabase Dashboard → `Database` → `Extensions` → `pg_cron` を ON にする。

#### app.settings の設定

pg_cron から Edge Functions を呼び出すために必要な設定です。

Supabase Dashboard → `Database` → `Database Configuration（App Settings）` に以下を追加:

| キー | 値 |
|-----|-----|
| `app.settings.supabase_url` | `https://<ref>.supabase.co` |
| `app.settings.service_role_key` | プロジェクトの service_role JWT |

または SQL で実行:
```sql
-- Supabase Dashboard の SQL Editor で実行（superuser権限が必要）
ALTER DATABASE postgres SET "app.settings.supabase_url" = 'https://<ref>.supabase.co';
ALTER DATABASE postgres SET "app.settings.service_role_key" = '<service_role_key>';
```

#### マイグレーション適用

```bash
make migrate-dev   # または migrate-prod
```

---

## 6. よくある作業パターン

### 新機能開発（スキーマ変更あり）

```bash
# 1. マイグレーションファイル作成
touch supabase/migrations/$(date +%Y%m%d%H%M%S)_feature_name.sql

# 2. SQL を書いて開発DBに適用
make migrate-dev

# 3. 開発で実装・動作確認
make run-dev

# 4. Edge Functions も変更した場合
make deploy-functions-dev

# 5. テスト・レビュー後に本番反映
make migrate-prod
make deploy-functions-prod
make build-ios-prod
```

### スキーマ変更なしの機能開発

```bash
# 開発で実装
make run-dev

# Edge Functions のみ変更した場合
make deploy-functions-dev

# 本番反映
make deploy-functions-prod
make build-ios-prod
```
