-- クラウドソース型最新話同期で使用する列
-- Safari Extension 経由で共有されたページのDOM総話数が信頼できる形で
-- DBに反映された最終時刻を記録する。
-- crawl-updates バッチはこの時刻が18時間以内の小説をスキップする。

ALTER TABLE novels
  ADD COLUMN last_shared_verified_at timestamptz;

COMMENT ON COLUMN novels.last_shared_verified_at IS
  '共有由来の最新話同期が最後に成功した時刻。crawl-updatesバッチの18hスキップ判定に使用。';
