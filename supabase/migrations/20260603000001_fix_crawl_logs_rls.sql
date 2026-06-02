-- Enable RLS on crawl_logs (was missing, flagged by Supabase security advisor)
-- crawl_logs is written only by Edge Functions via service role.
-- Regular users have no access; service role bypasses RLS as usual.
ALTER TABLE crawl_logs ENABLE ROW LEVEL SECURITY;
