-- Add genre classification to bookmarks
-- Values: null = unclassified, 'original' = 一次創作, 'derivative' = 二次創作
ALTER TABLE bookmarks
  ADD COLUMN genre text CHECK (genre IN ('original', 'derivative'));
