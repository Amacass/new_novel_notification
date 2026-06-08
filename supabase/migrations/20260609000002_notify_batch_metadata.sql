-- バッチクロール由来の一括通知に更新小説リストを格納するための列
-- crawl_batch 型: metadata = [{novel_id, title, new_total}, ...]
-- new_episode 型: metadata = null（単体通知なので不要）

ALTER TABLE notifications
  ADD COLUMN metadata jsonb;

COMMENT ON COLUMN notifications.metadata IS
  'crawl_batch 通知のみ使用。更新があった小説リスト [{novel_id, title, new_total}] を格納。';
