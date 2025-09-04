\echo === Creating useful indexes for queries ===
\timing on

-- 1) speed campaign filters/joins
CREATE INDEX IF NOT EXISTS idx_placements_campaign
  ON placements (campaign_id);

-- 2) speed vendor filters/joins
CREATE INDEX IF NOT EXISTS idx_placements_vendor
  ON placements (vendor_id);

-- 3) speed date filter on creative assets
CREATE INDEX IF NOT EXISTS idx_assets_created_at
  ON creative_assets (created_at);

\echo === Current project-specific indexes ===
\di+ idx_*

\timing off
