-- BAN 情報（管理アプリが service_role_key で書き込む）
ALTER TABLE profiles
  ADD COLUMN banned_at timestamptz,
  ADD COLUMN ban_reason text;

-- Amazon アフィリエイトリンク
CREATE TABLE amazon_links (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  novel_id    bigint NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
  label       text NOT NULL,
  url         text NOT NULL,
  sort_order  smallint NOT NULL DEFAULT 0,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_amazon_links_novel ON amazon_links(novel_id, is_active, sort_order);

ALTER TABLE amazon_links ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Active links viewable by authenticated"
  ON amazon_links FOR SELECT TO authenticated
  USING (is_active = true);

CREATE OR REPLACE FUNCTION set_updated_at()
  RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE TRIGGER amazon_links_updated_at
  BEFORE UPDATE ON amazon_links
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
