CREATE TABLE user_categories (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name varchar(50) NOT NULL,
  color varchar(7) NOT NULL DEFAULT '#6B7280',
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, name)
);
CREATE INDEX idx_user_categories_user ON user_categories(user_id);

CREATE TABLE bookmark_categories (
  bookmark_id bigint NOT NULL REFERENCES bookmarks(id) ON DELETE CASCADE,
  category_id bigint NOT NULL REFERENCES user_categories(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(bookmark_id, category_id)
);
CREATE INDEX idx_bookmark_categories_category ON bookmark_categories(category_id);

ALTER TABLE user_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookmark_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users CRUD own categories" ON user_categories
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users CRUD own bookmark categories" ON bookmark_categories
  FOR ALL USING (
    auth.uid() = (SELECT user_id FROM bookmarks WHERE id = bookmark_id)
  ) WITH CHECK (
    auth.uid() = (SELECT user_id FROM bookmarks WHERE id = bookmark_id)
  );
