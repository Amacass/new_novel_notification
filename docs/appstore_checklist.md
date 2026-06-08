# App Store 申請チェックリスト

## 1. Apple Developer Program 登録反映後の Xcode 設定

### 1-1. Team の切り替え

Xcode で `ios/Runner.xcworkspace` を開き、以下の**3つのターゲット全て**で Team を変更する。

| ターゲット | 場所 |
|---|---|
| Runner | Project Navigator → 青いRunnerアイコン → Runner ターゲット → Signing & Capabilities |
| SafariExtension | 同上 → SafariExtension ターゲット |
| ShareExtension | 同上 → ShareExtension ターゲット |

各ターゲットの **Team** ドロップダウン → Personal Team から **自分のチーム名（法人または個人名）** に切り替える。

### 1-2. App Groups の設定

以下の**3つのターゲット全て**に App Groups を追加する。

1. ターゲットを選択 → Signing & Capabilities タブ
2. **「+ Capability」** をクリック
3. `App Groups` と検索 → ダブルクリック
4. 追加された App Groups セクションの **「+」** をクリック
5. `group.com.amacass.novelNotification` と入力 → OK

対象ターゲット：**Runner、SafariExtension、ShareExtension** の3つ全て

### 1-3. Push Notifications の設定（Runner のみ）

1. Runner ターゲット → Signing & Capabilities
2. **「+ Capability」** → `Push Notifications` を追加

### 1-4. register-bookmark Edge Function のデプロイ

```bash
cd /Users/shinsugawara/Program/my_repo/new_novel_notification
supabase functions deploy register-bookmark
```

### 1-5. 動作確認

1. Xcode から実機ビルド（iPhone を接続して ▶ ボタン）
2. iOS設定アプリ → **Safari → 機能拡張 → Novelmark → オン**
3. Safari でなろう（syosetu.com）などを開く
4. ツールバーのアイコンをタップ
   - ✓（緑）= 登録成功
   - !（オレンジ）= 未ログイン → アプリでログイン後に再試行
   - ?（黄）= 対応外サイト

---

## 2. Firebase / FCM の設定

プッシュ通知を動かすために必要。

### 2-1. Firebase プロジェクトのセットアップ（手動）

1. [Firebase Console](https://console.firebase.google.com/) を開く
2. プロジェクト選択 → **プロジェクトの設定**
3. **「マイアプリ」** → iOS アプリを追加
   - Bundle ID: `com.amacass.novelNotification`
4. **`GoogleService-Info.plist`** をダウンロード
5. Xcode で `Runner` フォルダに追加（`Runner/GoogleService-Info.plist`）

### 2-2. APNs キーの登録

1. [Apple Developer](https://developer.apple.com/account/) → Certificates, Identifiers & Profiles → **Keys**
2. **「+」** → Key Name: `FCM Key` など
3. **Apple Push Notifications service (APNs)** にチェック → Continue → Register
4. `.p8` ファイルをダウンロード（**1回しかダウンロードできないので保管必須**）
5. Firebase Console → プロジェクト設定 → **Cloud Messaging** タブ
6. Apple アプリの設定 → **APNs 認証キー** をアップロード
   - Key ID: Apple Developer で確認
   - Team ID: Apple Developer アカウントの Team ID

---

## 3. プライバシーポリシー・利用規約の公開

App Store Connect に登録するためには**公開URLが必要**。

### 選択肢A: GitHub Pages（無料・簡単）

1. GitHub で新しいリポジトリを作成（例: `amacass.github.io`）
2. `docs/privacy_policy.md` と `docs/terms_of_service.md` をHTMLに変換してアップロード
3. Settings → Pages → Source: main branch → Save
4. URL: `https://amacass.github.io/privacy-policy.html` など

### 選択肢B: Notion（最も簡単）

1. Notion でページを作成してプライバシーポリシーを記載
2. **「共有」** → **「Webに公開」** をオン
3. 公開URLをコピー

### 必要なURL

| 用途 | 必要箇所 |
|---|---|
| プライバシーポリシー | App Store Connect（必須）、アプリ内設定画面 |
| 利用規約 | App Store Connect（任意だが推奨）、アプリ内設定画面 |
| サポートURL | App Store Connect（必須） |

---

## 4. Bundle ID と App ID の登録

### 4-1. Apple Developer での登録

1. [developer.apple.com](https://developer.apple.com/account/) → Certificates, Identifiers & Profiles → **Identifiers**
2. **「+」** → App IDs → App → Continue
3. Bundle ID: `com.amacass.novelNotification`（Explicit）
4. Capabilities で以下を有効化：
   - **App Groups**
   - **Push Notifications**
5. Register

### 4-2. App Groups Identifier の登録

1. Identifiers → **「+」** → App Groups → Continue
2. Description: `Novelmark App Group`
3. Identifier: `group.com.amacass.novelNotification`
4. Continue → Register

---

## 5. App Store Connect でのアプリ登録

### 5-1. アプリの新規作成

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com/) にログイン
2. **「マイ App」** → **「+」** → 新規 App
3. 以下を入力：

| 項目 | 内容 |
|---|---|
| プラットフォーム | iOS |
| 名前 | Novelmark |
| 言語 | 日本語 |
| Bundle ID | com.amacass.novelNotification |
| SKU | novel-notification-001（任意の識別子） |

### 5-2. アプリ情報の入力

**「App 情報」** から：

| 項目 | 内容 |
|---|---|
| カテゴリ | ブック（主）/ ユーティリティ（副） |
| プライバシーポリシーURL | 公開したURL |
| サポートURL | 公開したURL または メールアドレス |

### 5-3. 価格と配布状況

- 価格: **無料**
- 配布: **日本のみ** または全世界

### 5-4. スクリーンショットの準備

**必須サイズ（iPhone）：**

| デバイス | 解像度 |
|---|---|
| 6.9インチ（iPhone 16 Plus等） | 1320×2868 |
| 6.5インチ（iPhone 14 Plus等） | 1284×2778 |

**撮影のコツ：**
- Xcode シミュレーター（iPhone 16 Plus）でスクリーンショット
- `Cmd + S` でスクリーンショット保存
- 最低1枚、最大10枚
- 実際の画面を使う（フレームは任意）

**必要な画面例：**
1. タイムライン（通知一覧）
2. 本棚画面
3. 小説詳細画面
4. Safari拡張機能の動作画面

### 5-5. 説明文の準備

```
【アプリの説明文（例）】
Web小説の更新を自動でお知らせするアプリです。

■ 主な機能
・なろう、ハーメルン、Arcadiaの更新を自動チェック
・新着エピソードをプッシュ通知でお知らせ
・本棚でお気に入り作品を管理
・Safariから1タップでブックマーク登録

■ 対応サイト
・小説家になろう（syosetu.com）
・ハーメルン（syosetu.org）
・Arcadia（mai-net.net）
```

**キーワード（100文字以内、カンマ区切り）：**
```
小説,なろう,ハーメルン,Arcadia,更新通知,Web小説,ブックマーク,読書管理
```

### 5-6. App プライバシー（データ収集の申告）

「App プライバシー」セクションで回答：

| 質問 | 回答 | 理由 |
|---|---|---|
| データを収集しますか？ | はい | |
| メールアドレス | 収集する・アカウント設定・ユーザーに紐付け | ログイン用 |
| ユーザーID | 収集する・アプリの機能・ユーザーに紐付け | Supabase UUID |
| 使用状況データ | 収集しない | |
| 診断データ | 収集しない | |

### 5-7. 輸出コンプライアンス

- 「暗号化を使用していますか？」→ **はい**
- 「標準的な暗号化のみですか？」→ **はい**（HTTPS/TLSのみ）
- 「免除資格がありますか？」→ **はい**

---

## 6. ビルドのアップロード

### 6-1. アーカイブの作成

1. Xcode 上部のデバイス選択を **「Any iOS Device (arm64)」** に変更
2. メニュー → **Product → Archive**
3. しばらく待つ（5〜10分）
4. Organizer ウィンドウが開く

### 6-2. App Store Connect へアップロード

1. Organizer → 作成されたアーカイブを選択
2. **「Distribute App」** をクリック
3. **「App Store Connect」** → Next
4. **「Upload」** → Next → Next → Upload
5. アップロード完了後、App Store Connect の TestFlight に反映される（数分〜30分）

### 6-3. TestFlight でのテスト（推奨）

1. App Store Connect → TestFlight → ビルドを選択
2. 内部テスト → 自分のApple IDを追加
3. iPhone の TestFlight アプリからインストールして確認

---

## 7. 審査提出

### 7-1. 審査情報の入力

「バージョン情報」→「App 審査情報」：

| 項目 | 内容 |
|---|---|
| サインインが必要 | はい |
| デモアカウント（ユーザー名） | 審査用メールアドレス |
| デモアカウント（パスワード） | 審査用パスワード |
| メモ | 「Supabaseバックエンドを使用しています。なろうAPIで小説更新を取得します。」など |

> 審査用アカウントを事前に作成しておく（本番のSupabaseに登録）

### 7-2. 提出

「審査へ提出」ボタンをクリック → 通常1〜3営業日で審査結果が届く

---

## 優先順位まとめ

| 順番 | タスク | 担当 |
|---|---|---|
| 1 | Apple Developer 登録反映を待つ | 待機 |
| 2 | Xcode: Team切り替え + App Groups + Push Notifications | Xcode操作 |
| 3 | Firebase: GoogleService-Info.plist の設定 | Firebase Console + Xcode |
| 4 | APNs キー登録 → Firebase に登録 | Apple Developer + Firebase |
| 5 | プライバシーポリシー・利用規約をURL公開 | GitHub Pages or Notion |
| 6 | App Store Connect でアプリ登録・情報入力 | ブラウザ |
| 7 | スクリーンショット撮影 | シミュレーター |
| 8 | アーカイブ作成 → アップロード | Xcode |
| 9 | 審査用アカウント作成 | ブラウザ |
| 10 | 審査提出 | App Store Connect |
