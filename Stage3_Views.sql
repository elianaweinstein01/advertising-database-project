-- psql -h localhost -p 5432 -U postgres -d travel_ads -f Stage3_Views.sql 2>&1 | tee stage3_views.log

\pset pager off
\timing on

-- For re-runs: drop views if they already exist
DROP VIEW IF EXISTS active_campaigns_v CASCADE;
DROP VIEW IF EXISTS video_assets_v CASCADE;
DROP VIEW IF EXISTS usd_budgets_v CASCADE;
DROP VIEW IF EXISTS reels_placements_v CASCADE;

-- =========================================================
-- View 1: Active campaigns (only campaigns that are currently active)
-- Updatable: YES (single base table), with CHECK OPTION
-- =========================================================
\echo === Create: active_campaigns_v ===
CREATE OR REPLACE VIEW active_campaigns_v AS
SELECT
  campaign_id,
  name,
  objective,
  status,
  start_date,
  end_date,
  ramp_up_phase,
  season,
  target_region
FROM campaigns
WHERE status = 'active'
WITH LOCAL CHECK OPTION;

\echo === Q1 (SELECT): list active campaigns ===
SELECT campaign_id, name, start_date, end_date
FROM active_campaigns_v
ORDER BY campaign_id
LIMIT 10;

\echo === Q1 (INSERT valid via view): insert an active campaign (should SUCCEED) ===
BEGIN;
INSERT INTO active_campaigns_v (name, objective, status, start_date, end_date, ramp_up_phase, season, target_region)
VALUES ('View Insert: Active Summer', 'Increase bookings', 'active', CURRENT_DATE, CURRENT_DATE + INTERVAL '14 days', FALSE, 'Summer', 'Europe');

\echo === Q1 (UPDATE invalid via view): set status to paused (should FAIL due to CHECK OPTION) ===
-- This tries to push the row outside the view predicate (status != 'active')
-- Expect: ERROR:  new row violates WITH CHECK OPTION for view "active_campaigns_v"
UPDATE active_campaigns_v
SET status = 'paused'
WHERE name = 'View Insert: Active Summer';

ROLLBACK;

-- =========================================================
-- View 2: Video creative assets (video only, with positive duration)
-- Updatable: YES (single base table), with CHECK OPTION
-- =========================================================
\echo === Create: video_assets_v ===
CREATE OR REPLACE VIEW video_assets_v AS
SELECT
  asset_id,
  asset_type,
  title,
  url_or_path,
  dimensions,
  duration_sec,
  created_at,
  compliance_ok
FROM creative_assets
WHERE asset_type = 'video' AND duration_sec IS NOT NULL AND duration_sec > 0
WITH LOCAL CHECK OPTION;

\echo === Q2 (SELECT): sample video assets ===
SELECT asset_id, title, duration_sec, created_at
FROM video_assets_v
ORDER BY created_at DESC
LIMIT 10;

\echo === Q2 (INSERT invalid via view): try to insert a non-video (should FAIL) ===
BEGIN;
-- Expect: ERROR due to CHECK OPTION (asset_type <> 'video')
INSERT INTO video_assets_v (asset_type, title, url_or_path, dimensions, duration_sec, compliance_ok)
VALUES ('image', 'Wrong Through View', 'http://example.com/img.jpg', '800x600', NULL, TRUE);

\echo === Q2 (UPDATE invalid via view): try to zero the duration (should FAIL) ===
-- Expect: ERROR due to CHECK OPTION (duration_sec must stay > 0)
UPDATE video_assets_v
SET duration_sec = 0
WHERE TRUE LIMIT 1;

ROLLBACK;

-- =========================================================
-- View 3: Budgets in USD (only positive amounts, currency = USD)
-- Updatable: YES (single base table), with CHECK OPTION
-- =========================================================
\echo === Create: usd_budgets_v ===
CREATE OR REPLACE VIEW usd_budgets_v AS
SELECT
  campaign_id,
  amount_allocated,
  currency
FROM budget_allocations
WHERE currency = 'USD' AND amount_allocated > 0
WITH LOCAL CHECK OPTION;

\echo === Q3 (SELECT): USD budgets ===
SELECT campaign_id, amount_allocated
FROM usd_budgets_v
ORDER BY amount_allocated DESC
LIMIT 10;

\echo === Q3 (UPDATE invalid via view): try to set negative amount (should FAIL) ===
BEGIN;
-- Expect: ERROR due to CHECK OPTION (amount_allocated must remain > 0)
UPDATE usd_budgets_v
SET amount_allocated = -100
WHERE TRUE LIMIT 1;

\echo === Q3 (INSERT invalid via view): insert non-USD row (should FAIL) ===
-- Expect: ERROR due to CHECK OPTION (currency must be USD)
INSERT INTO usd_budgets_v (campaign_id, amount_allocated, currency)
VALUES (999999, 1000, 'EUR');

ROLLBACK;

-- =========================================================
-- View 4: Placements that run on Instagram Reels
-- (we know channel_id = 3 corresponds to Instagram Reels)
-- Updatable: YES (single base table), with CHECK OPTION
-- =========================================================

\echo === Create: reels_placements_v (channel_id = 3) ===
CREATE OR REPLACE VIEW reels_placements_v AS
SELECT
  placement_id,
  campaign_id,
  channel_id,
  vendor_id,
  asset_id,
  flight_start,
  flight_end
FROM placements
WHERE channel_id = 3
WITH LOCAL CHECK OPTION;

\echo === Q4 (SELECT): sample Reels placements ===
SELECT placement_id, campaign_id, flight_start, flight_end
FROM reels_placements_v
ORDER BY flight_start DESC
LIMIT 10;

\echo === Q4 (INSERT valid via view): insert a new Reels placement (should SUCCEED then ROLLBACK) ===
BEGIN;

-- NOTE: These FKs must point to existing rows in your DB.
-- If you don't know valid IDs, preview some first:
--   SELECT campaign_id FROM campaigns LIMIT 1;
--   SELECT vendor_id FROM vendors LIMIT 1;
--   SELECT asset_id   FROM creative_assets LIMIT 1;
-- For demo, we pull one existing row and copy its FK values:
WITH sample AS (
  SELECT p.campaign_id, p.vendor_id, p.asset_id
  FROM placements p
  WHERE p.channel_id = 3
  LIMIT 1
)
INSERT INTO reels_placements_v (campaign_id, channel_id, vendor_id, asset_id, flight_start, flight_end)
SELECT campaign_id, 3, vendor_id, asset_id, CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days'
FROM sample;

\echo === Q4 (UPDATE invalid via view): try to change channel to non-3 (should FAIL) ===
-- Expect: ERROR due to CHECK OPTION (channel_id must remain 3)
UPDATE reels_placements_v
SET channel_id = 1
WHERE TRUE LIMIT 1;

\echo === Q4 (DELETE via view): deleting through the view deletes from base table (should SUCCEED then ROLLBACK) ===
DELETE FROM reels_placements_v
WHERE flight_start = CURRENT_DATE;

ROLLBACK;

\timing off
