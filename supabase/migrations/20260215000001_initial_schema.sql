-- ============================================
-- Web小説更新通知アプリ 初期スキーマ
-- ============================================

-- profiles
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name varchar(50) NOT NULL DEFAULT 'ユーザー',
  avatar_url text,
  theme_mode varchar(10) NOT NULL DEFAULT 'system',
  notification_enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- authors
CREATE TABLE authors (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  site varchar(20) NOT NULL,
  site_author_id varchar(100) NOT NULL,
  name varchar(200) NOT NULL,
  profile_url text,
  last_checked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(site, site_author_id)
);

-- novels
CREATE TABLE novels (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  site varchar(20) NOT NULL,
  site_novel_id varchar(100) NOT NULL,
  url text NOT NULL,
  title varchar(500),
  author_name varchar(200),
  author_id bigint REFERENCES authors(id),
  synopsis text,
  total_episodes integer NOT NULL DEFAULT 0,
  latest_episode_id varchar(100),
  latest_episode_title varchar(500),
  serial_status varchar(20) NOT NULL DEFAULT 'ongoing',
  site_updated_at timestamptz,
  last_crawled_at timestamptz,
  crawl_error_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(site, site_novel_id)
);

-- episodes
CREATE TABLE episodes (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  novel_id bigint NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
  site_episode_id varchar(100) NOT NULL,
  episode_number integer,
  title varchar(500),
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(novel_id, site_episode_id)
);

-- bookmarks
CREATE TABLE bookmarks (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  novel_id bigint NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
  last_read_episode integer NOT NULL DEFAULT 0,
  memo text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, novel_id)
);

-- reviews
CREATE TABLE reviews (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  novel_id bigint NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
  rating smallint CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, novel_id)
);

-- favorite_authors
CREATE TABLE favorite_authors (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  author_id bigint NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, author_id)
);

-- user_tags
CREATE TABLE user_tags (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name varchar(50) NOT NULL,
  color varchar(7),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, name)
);

-- bookmark_tags
CREATE TABLE bookmark_tags (
  bookmark_id bigint NOT NULL REFERENCES bookmarks(id) ON DELETE CASCADE,
  tag_id bigint NOT NULL REFERENCES user_tags(id) ON DELETE CASCADE,
  PRIMARY KEY(bookmark_id, tag_id)
);

-- notifications
CREATE TABLE notifications (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type varchar(30) NOT NULL,
  novel_id bigint REFERENCES novels(id) ON DELETE SET NULL,
  author_id bigint REFERENCES authors(id) ON DELETE SET NULL,
  title varchar(200) NOT NULL,
  body text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- fcm_tokens
CREATE TABLE fcm_tokens (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token text NOT NULL UNIQUE,
  platform varchar(10) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- crawl_logs
CREATE TABLE crawl_logs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  novel_id bigint REFERENCES novels(id) ON DELETE SET NULL,
  site varchar(20) NOT NULL,
  status varchar(20) NOT NULL,
  episodes_found integer NOT NULL DEFAULT 0,
  error_message text,
  duration_ms integer,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- legal_documents
CREATE TABLE legal_documents (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  type varchar(30) NOT NULL,
  version varchar(20) NOT NULL,
  content_url text NOT NULL,
  summary_of_changes text,
  effective_date date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(type, version)
);

-- user_consents
CREATE TABLE user_consents (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  legal_document_id bigint NOT NULL REFERENCES legal_documents(id),
  consented_at timestamptz NOT NULL DEFAULT now(),
  ip_address inet,
  UNIQUE(user_id, legal_document_id)
);

-- ============================================
-- Indexes
-- ============================================

CREATE INDEX idx_bookmarks_user_id ON bookmarks(user_id);
CREATE INDEX idx_bookmarks_novel_id ON bookmarks(novel_id);
CREATE INDEX idx_novels_site_updated ON novels(site_updated_at DESC);
CREATE INDEX idx_novels_site_novel ON novels(site, site_novel_id);
CREATE INDEX idx_episodes_novel_id ON episodes(novel_id);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX idx_reviews_user_id ON reviews(user_id);
CREATE INDEX idx_reviews_rating ON reviews(user_id, rating);
CREATE INDEX idx_favorite_authors_user ON favorite_authors(user_id);
CREATE INDEX idx_crawl_logs_novel ON crawl_logs(novel_id, created_at DESC);
CREATE INDEX idx_novels_crawl ON novels(last_crawled_at ASC NULLS FIRST) WHERE crawl_error_count < 5;

-- ============================================
-- Trigger: Auto-create profile on signup
-- ============================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name', 'ユーザー'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================
-- RLS Policies
-- ============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

ALTER TABLE novels ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Novels viewable by authenticated" ON novels FOR SELECT TO authenticated USING (true);
CREATE POLICY "Novels insertable by authenticated" ON novels FOR INSERT TO authenticated WITH CHECK (true);

ALTER TABLE episodes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Episodes viewable by authenticated" ON episodes FOR SELECT TO authenticated USING (true);

ALTER TABLE authors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authors viewable by authenticated" ON authors FOR SELECT TO authenticated USING (true);

ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users CRUD own bookmarks" ON bookmarks FOR ALL USING (auth.uid() = user_id);

ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Reviews viewable by all" ON reviews FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users insert own reviews" ON reviews FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own reviews" ON reviews FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own reviews" ON reviews FOR DELETE USING (auth.uid() = user_id);

ALTER TABLE favorite_authors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users CRUD own favorite authors" ON favorite_authors FOR ALL USING (auth.uid() = user_id);

ALTER TABLE user_tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users CRUD own tags" ON user_tags FOR ALL USING (auth.uid() = user_id);

ALTER TABLE bookmark_tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users CRUD own bookmark tags" ON bookmark_tags FOR ALL
  USING (EXISTS (SELECT 1 FROM bookmarks WHERE bookmarks.id = bookmark_id AND bookmarks.user_id = auth.uid()));

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users update own notifications" ON notifications FOR UPDATE USING (auth.uid() = user_id);

ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users CRUD own fcm tokens" ON fcm_tokens FOR ALL USING (auth.uid() = user_id);

ALTER TABLE legal_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Legal docs viewable by all" ON legal_documents FOR SELECT TO authenticated USING (true);

ALTER TABLE user_consents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own consents" ON user_consents FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own consents" ON user_consents FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
