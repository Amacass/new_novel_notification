-- 通知の重複送信防止
-- new_episode 型の通知に話数マイルストーンを記録し、
-- クロール / 共有どちらが先に更新しても同一ユーザーへ二重送信しない

ALTER TABLE notifications
  ADD COLUMN episode_milestone integer;

-- 同一ユーザー × 同一小説 × 同一話数は1回だけ
CREATE UNIQUE INDEX uq_notifications_new_episode
  ON notifications(user_id, novel_id, episode_milestone)
  WHERE type = 'new_episode' AND episode_milestone IS NOT NULL;

COMMENT ON COLUMN notifications.episode_milestone IS
  'new_episode 通知に限り total_episodes を格納。重複送信防止のユニークキーとして使用。';
