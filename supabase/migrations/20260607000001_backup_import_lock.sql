-- Import lockout mechanism for failed backup imports
-- Unlock by running:
--   UPDATE profiles SET import_failure_count = 0, import_locked_at = NULL WHERE id = '<user_id>';

ALTER TABLE profiles
  ADD COLUMN import_failure_count smallint NOT NULL DEFAULT 0,
  ADD COLUMN import_locked_at timestamptz;

COMMENT ON COLUMN profiles.import_failure_count IS '連続インポート失敗回数。成功時にリセット。';
COMMENT ON COLUMN profiles.import_locked_at IS 'NULLでない場合インポートをブロック。DBで直接NULLに戻して解除。';
