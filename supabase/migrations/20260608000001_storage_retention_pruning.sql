-- ============================================
-- ストレージ肥大化対策: 定期剪定 (retention pruning)
-- ============================================
-- 目的: DB容量(Free 500MB)を圧迫する3テーブルを定期的に剪定し、
--       無料枠で運用できる期間を延ばす / Pro移行後のDB課金を抑える。
--
--   1. crawl_logs    … クロール毎に積み上がる運用ログ。14日保持。
--   2. notifications … 既読かつ古い通知を削除。90日保持(未読は残す)。
--   3. episodes      … 小説ごとに最新50話だけ保持(更新検知は
--                      novels.total_episodes で行うため履歴全保持は不要)。
--
-- ※ pg_cron / pg_net は 20260215000002 の時点で有効化済みの前提。
-- ※ 各関数は手動実行も可能 (例: SELECT prune_crawl_logs(7);)。
-- ============================================

-- --------------------------------------------
-- 剪定を効率化するインデックス
-- --------------------------------------------
CREATE INDEX IF NOT EXISTS idx_crawl_logs_created_at
  ON crawl_logs(created_at);

CREATE INDEX IF NOT EXISTS idx_notifications_read_created
  ON notifications(created_at) WHERE is_read = true;

CREATE INDEX IF NOT EXISTS idx_episodes_novel_number
  ON episodes(novel_id, episode_number DESC);

-- --------------------------------------------
-- 1. crawl_logs の剪定
-- --------------------------------------------
CREATE OR REPLACE FUNCTION prune_crawl_logs(retention_days integer DEFAULT 14)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count integer;
BEGIN
  DELETE FROM crawl_logs
  WHERE created_at < now() - make_interval(days => retention_days);
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

-- --------------------------------------------
-- 2. notifications の剪定 (既読 & 古いもののみ。未読は保持)
-- --------------------------------------------
CREATE OR REPLACE FUNCTION prune_old_notifications(retention_days integer DEFAULT 90)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count integer;
BEGIN
  DELETE FROM notifications
  WHERE is_read = true
    AND created_at < now() - make_interval(days => retention_days);
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

-- --------------------------------------------
-- 3. episodes の剪定 (小説ごとに最新 keep_per_novel 話を残す)
-- --------------------------------------------
CREATE OR REPLACE FUNCTION prune_old_episodes(keep_per_novel integer DEFAULT 50)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count integer;
BEGIN
  WITH ranked AS (
    SELECT id,
           row_number() OVER (
             PARTITION BY novel_id
             ORDER BY episode_number DESC NULLS LAST, id DESC
           ) AS rn
    FROM episodes
  )
  DELETE FROM episodes e
  USING ranked
  WHERE e.id = ranked.id
    AND ranked.rn > keep_per_novel;
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

-- --------------------------------------------
-- pg_cron スケジュール登録 (再実行可能にするため一旦 unschedule)
-- --------------------------------------------
DO $$
BEGIN
  PERFORM cron.unschedule(jobid)
  FROM cron.job
  WHERE jobname IN ('prune-crawl-logs', 'prune-old-notifications', 'prune-old-episodes');
EXCEPTION WHEN OTHERS THEN
  -- 初回適用時はジョブが存在しないため無視
  NULL;
END;
$$;

-- crawl_logs: 毎日 03:20 に剪定
SELECT cron.schedule(
  'prune-crawl-logs',
  '20 3 * * *',
  $$SELECT prune_crawl_logs(14);$$
);

-- notifications: 毎日 03:30 に剪定
SELECT cron.schedule(
  'prune-old-notifications',
  '30 3 * * *',
  $$SELECT prune_old_notifications(90);$$
);

-- episodes: 毎週日曜 04:00 に剪定 (全件スキャンのため低頻度)
SELECT cron.schedule(
  'prune-old-episodes',
  '0 4 * * 0',
  $$SELECT prune_old_episodes(50);$$
);
