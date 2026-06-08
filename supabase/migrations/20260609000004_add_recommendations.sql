-- =============================================================
-- おすすめ機能
-- =============================================================

-- -------------------------------------------------------
-- 1. source_works — 原作作品マスタ
-- -------------------------------------------------------
CREATE TABLE source_works (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       varchar(100) NOT NULL,
  reading    varchar(100),
  aliases    text[]       NOT NULL DEFAULT '{}',
  novel_count integer     NOT NULL DEFAULT 0,
  created_at timestamptz  NOT NULL DEFAULT now(),
  UNIQUE(name)
);

ALTER TABLE source_works ENABLE ROW LEVEL SECURITY;
CREATE POLICY "source_works viewable by authenticated"
  ON source_works FOR SELECT TO authenticated USING (true);

INSERT INTO source_works (name) VALUES ('オリジナル');

-- -------------------------------------------------------
-- 2. novels への追加カラム
-- -------------------------------------------------------
ALTER TABLE novels
  ADD COLUMN source_work_id bigint REFERENCES source_works(id) ON DELETE SET NULL,
  ADD COLUMN work_kind      varchar(12) CHECK (work_kind IN ('original', 'derivative'));

CREATE INDEX idx_novels_source_work ON novels(source_work_id);

-- -------------------------------------------------------
-- 3. profiles への追加カラム
-- -------------------------------------------------------
ALTER TABLE profiles
  ADD COLUMN recommend_view_enabled   boolean NOT NULL DEFAULT true,
  ADD COLUMN recommend_create_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN total_recommend_likes    integer NOT NULL DEFAULT 0;

-- -------------------------------------------------------
-- 4. public_profiles ビュー（表示名・総いいね数のみ公開）
-- -------------------------------------------------------
CREATE VIEW public_profiles
  WITH (security_invoker = false) AS
  SELECT id, display_name, avatar_url, total_recommend_likes
  FROM profiles;

GRANT SELECT ON public_profiles TO authenticated;

-- -------------------------------------------------------
-- 5. recommendations
-- -------------------------------------------------------
CREATE TABLE recommendations (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id            uuid        NOT NULL REFERENCES profiles(id)  ON DELETE CASCADE,
  novel_id           bigint      NOT NULL REFERENCES novels(id)    ON DELETE CASCADE,
  heading            varchar(60) NOT NULL,
  body               text        NOT NULL,
  is_public          boolean     NOT NULL DEFAULT true,
  moderation_status  varchar(12) NOT NULL DEFAULT 'pending'
                       CHECK (moderation_status IN ('pending', 'approved', 'rejected')),
  moderation_reason  varchar(30)
                       CHECK (moderation_reason IN ('r18','ad','harassment','off_topic','other')),
  moderated_at       timestamptz,
  like_count         integer     NOT NULL DEFAULT 0,
  source_tier        smallint    NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, novel_id)
);

ALTER TABLE recommendations ENABLE ROW LEVEL SECURITY;

-- 承認済み公開おすすめは全認証ユーザーが閲覧可
CREATE POLICY "Public approved recommendations viewable"
  ON recommendations FOR SELECT TO authenticated
  USING (is_public = true AND moderation_status = 'approved');

-- 自分のおすすめは状態に関わらず閲覧可
CREATE POLICY "Users can view own recommendations"
  ON recommendations FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own recommendations"
  ON recommendations FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own recommendations"
  ON recommendations FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own recommendations"
  ON recommendations FOR DELETE USING (auth.uid() = user_id);

-- クライアントが変更可能な列のみ GRANT（moderation_status 等の改ざん防止）
GRANT UPDATE (heading, body, is_public) ON recommendations TO authenticated;

-- -------------------------------------------------------
-- 6. recommendation_likes
-- -------------------------------------------------------
CREATE TABLE recommendation_likes (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  recommendation_id  bigint  NOT NULL REFERENCES recommendations(id) ON DELETE CASCADE,
  user_id            uuid    NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE(recommendation_id, user_id)
);

ALTER TABLE recommendation_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Likes viewable by authenticated"
  ON recommendation_likes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can like"
  ON recommendation_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike own like"
  ON recommendation_likes FOR DELETE USING (auth.uid() = user_id);

-- -------------------------------------------------------
-- 7. recommendation_reports
-- -------------------------------------------------------
CREATE TABLE recommendation_reports (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  recommendation_id  bigint      NOT NULL REFERENCES recommendations(id) ON DELETE CASCADE,
  reporter_id        uuid        NOT NULL REFERENCES profiles(id)  ON DELETE CASCADE,
  reason             varchar(30) NOT NULL
                       CHECK (reason IN ('r18','ad','harassment','off_topic','other')),
  note               text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE(recommendation_id, reporter_id)
);

ALTER TABLE recommendation_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can report"
  ON recommendation_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "Users can view own reports"
  ON recommendation_reports FOR SELECT USING (auth.uid() = reporter_id);

-- -------------------------------------------------------
-- 8. recommendation_ranking_snapshots
-- -------------------------------------------------------
CREATE TABLE recommendation_ranking_snapshots (
  period            varchar(8)  NOT NULL CHECK (period IN ('daily','weekly','monthly')),
  rank              integer     NOT NULL,
  recommendation_id bigint      NOT NULL REFERENCES recommendations(id) ON DELETE CASCADE,
  likes_in_period   integer     NOT NULL,
  computed_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (period, rank)
);

ALTER TABLE recommendation_ranking_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Snapshots viewable by authenticated"
  ON recommendation_ranking_snapshots FOR SELECT TO authenticated USING (true);

-- -------------------------------------------------------
-- 9. トリガ
-- -------------------------------------------------------

-- いいね増減で like_count と total_recommend_likes を同期
CREATE FUNCTION sync_recommendation_like_count()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE target_user uuid;
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE recommendations SET like_count = like_count + 1
      WHERE id = NEW.recommendation_id
      RETURNING user_id INTO target_user;
    UPDATE profiles SET total_recommend_likes = total_recommend_likes + 1
      WHERE id = target_user;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE recommendations SET like_count = GREATEST(like_count - 1, 0)
      WHERE id = OLD.recommendation_id
      RETURNING user_id INTO target_user;
    UPDATE profiles SET total_recommend_likes = GREATEST(total_recommend_likes - 1, 0)
      WHERE id = target_user;
  END IF;
  RETURN NULL;
END; $$;

CREATE TRIGGER trg_recommendation_likes
  AFTER INSERT OR DELETE ON recommendation_likes
  FOR EACH ROW EXECUTE FUNCTION sync_recommendation_like_count();

-- おすすめ作成・更新時に tier∈{2,3} を強制し source_tier をスナップショット
CREATE FUNCTION enforce_recommendable_tier()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE t smallint;
BEGIN
  SELECT tier INTO t FROM bookmarks
    WHERE user_id = NEW.user_id AND novel_id = NEW.novel_id;
  IF t IS NULL OR t < 2 THEN
    RAISE EXCEPTION 'recommendation requires bookmark tier 2 (良作) or 3 (殿堂入り)';
  END IF;
  NEW.source_tier := t;
  RETURN NEW;
END; $$;

CREATE TRIGGER trg_enforce_recommendable_tier
  BEFORE INSERT OR UPDATE OF novel_id ON recommendations
  FOR EACH ROW EXECUTE FUNCTION enforce_recommendable_tier();

-- 見出し・本文が編集されたら再モデレーション (pending へ戻す)
CREATE FUNCTION requeue_on_edit()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (NEW.heading IS DISTINCT FROM OLD.heading
      OR NEW.body IS DISTINCT FROM OLD.body) THEN
    NEW.moderation_status := 'pending';
    NEW.moderation_reason := NULL;
    NEW.moderated_at := NULL;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END; $$;

CREATE TRIGGER trg_requeue_on_edit
  BEFORE UPDATE ON recommendations
  FOR EACH ROW EXECUTE FUNCTION requeue_on_edit();

-- 通報がしきい値（3件）に達したら自動非公開 + pending 再投入
CREATE FUNCTION auto_unpublish_on_reports()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE cnt integer;
BEGIN
  SELECT COUNT(*) INTO cnt
    FROM recommendation_reports
    WHERE recommendation_id = NEW.recommendation_id;
  IF cnt >= 3 THEN
    UPDATE recommendations
      SET is_public = false, moderation_status = 'pending', moderation_reason = NULL
      WHERE id = NEW.recommendation_id;
  END IF;
  RETURN NEW;
END; $$;

CREATE TRIGGER trg_auto_unpublish
  AFTER INSERT ON recommendation_reports
  FOR EACH ROW EXECUTE FUNCTION auto_unpublish_on_reports();

-- -------------------------------------------------------
-- 10. インデックス
-- -------------------------------------------------------
CREATE INDEX idx_rec_public_approved
  ON recommendations(moderation_status, is_public, like_count DESC);
CREATE INDEX idx_rec_user ON recommendations(user_id);
CREATE INDEX idx_rec_novel
  ON recommendations(novel_id)
  WHERE is_public = true AND moderation_status = 'approved';
CREATE INDEX idx_rec_pending
  ON recommendations(moderation_status)
  WHERE moderation_status = 'pending';
CREATE INDEX idx_rec_likes_created ON recommendation_likes(created_at);
CREATE INDEX idx_rec_likes_rec     ON recommendation_likes(recommendation_id);
