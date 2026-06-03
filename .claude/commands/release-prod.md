# 本番リリース手順

このコマンドを実行したら、以下の順序でリリース作業を進めてください。

## 1. バージョン番号を確認・更新

`pubspec.yaml` の `version` を確認する。
- バグ修正・小改善: `1.0.x+N` → `1.0.(x+1)+(N+1)`
- 機能追加: `1.x.0+N` → `1.(x+1).0+(N+1)`

`pubspec.yaml` の `version:` 行を更新する。

## 2. 変更内容をコミット

```bash
git add <関連ファイル>
git commit -m "add/fix: 変更内容の要約 (バージョン番号)"
```

## 3. Supabase マイグレーション（DBスキーマ変更がある場合のみ）

新規マイグレーションファイルがある場合のみ実行:
```bash
make migrate-prod
```

エラーが出た場合は「already applied」の可能性があるので確認してから `supabase migration repair` で対処する。

## 4. Edge Functions をデプロイ

`supabase/functions/` 配下に変更がある場合は必ず実行:
```bash
make deploy-functions-prod
```

変更がなくても、前回デプロイ済みか不明な場合は実行しておく（冪等なので問題なし）。

## 5. IPA ビルド

```bash
flutter build ipa --release --dart-define=FLAVOR=production
```

完了すると `build/ios/ipa/*.ipa` が生成される。

## 6. App Store Connect へアップロード

**Xcode Organizer を使う場合:**
1. `build/ios/archive/Runner.xcarchive` をダブルクリック → Xcode Organizer が開く
2. 対象バージョンを選択 → **Distribute App**
3. App Store Connect → Upload → 次へ → 完了

**Transporter を使う場合:**
- `build/ios/ipa/*.ipa` を Transporter アプリにドラッグ&ドロップ → 配信

## 7. App Store Connect で審査提出

1. [App Store Connect](https://appstoreconnect.apple.com) を開く
2. アプリ → 「+」で新バージョン作成（バージョン番号を入力）
3. アップロードされたビルドを選択
4. リリースノート（日本語）を記入
5. 「審査に提出」

## チェックリスト

- [ ] `pubspec.yaml` バージョン更新済み
- [ ] 変更をコミット済み
- [ ] DBマイグレーション適用済み（変更がある場合）
- [ ] Edge Functions デプロイ済み（変更がある場合）
- [ ] IPA ビルド成功
- [ ] App Store Connect にアップロード済み
- [ ] 審査提出済み
