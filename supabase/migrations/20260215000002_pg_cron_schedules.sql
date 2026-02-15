-- pg_cron スケジュール設定
-- ※ Supabase Dashboard > Database > Extensions で pg_cron を有効にしてから実行

-- 6時間ごとにクロール実行
SELECT cron.schedule(
  'crawl-novel-updates',
  '0 */6 * * *',
  $$
  SELECT
    net.http_post(
      url := current_setting('app.settings.supabase_url') || '/functions/v1/crawl-updates',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb
    );
  $$
);

-- 12時間ごとにお気に入り作者の新作チェック
SELECT cron.schedule(
  'check-new-novels-by-author',
  '0 */12 * * *',
  $$
  SELECT
    net.http_post(
      url := current_setting('app.settings.supabase_url') || '/functions/v1/check-new-novels',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb
    );
  $$
);
