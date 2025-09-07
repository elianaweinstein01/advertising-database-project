\echo === Creating useful indexes for queries ===
\timing on

\echo
\echo --- Current project-specific indexes (before) ---
\di+ idx_*

/******************************************************************
 * Indexes we create (safe with IF NOT EXISTS):
 * 1) performance_metrics(placement_id, stat_date)
 *    - Speeds joins by placement and date filters (Q1, Q4, Q7).
 * 2) placements(campaign_id)
 *    - Speeds filtering placements by campaign (Q1, Q4).
 * 3) placements(channel_id, vendor_id)
 *    - Speeds channel/vendor grouping & joins (Q2, Q3).
 ******************************************************************/
\echo
\echo --- Creating / ensuring indexes exist ---
CREATE INDEX IF NOT EXISTS idx_pm_placement_statdate
  ON performance_metrics (placement_id, stat_date);

CREATE INDEX IF NOT EXISTS idx_pl_campaign
  ON placements (campaign_id);

CREATE INDEX IF NOT EXISTS idx_pl_channel_vendor
  ON placements (channel_id, vendor_id);

\echo
\echo --- Index list (after) ---
\di+ idx_*

ANALYZE;

\timing off

SELECT setval('campaigns_campaign_id_seq',       COALESCE((SELECT MAX(campaign_id)  FROM campaigns), 0), true);
SELECT setval('channels_channel_id_seq',         COALESCE((SELECT MAX(channel_id)   FROM channels), 0), true);
SELECT setval('vendors_vendor_id_seq',           COALESCE((SELECT MAX(vendor_id)    FROM vendors), 0), true);
SELECT setval('creative_assets_asset_id_seq',    COALESCE((SELECT MAX(asset_id)     FROM creative_assets), 0), true);
SELECT setval('placements_placement_id_seq',     COALESCE((SELECT MAX(placement_id) FROM placements), 0), true);
SELECT setval('performance_metrics_metric_id_seq',COALESCE((SELECT MAX(metric_id)   FROM performance_metrics), 0), true);


ALTER TABLE campaigns
  DROP CONSTRAINT IF EXISTS chk_campaign_dates,
  ADD CONSTRAINT chk_campaign_dates CHECK (end_date >= start_date);

ALTER TABLE vendors
  DROP CONSTRAINT IF EXISTS chk_vendor_email,
  ADD CONSTRAINT chk_vendor_email
  CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$') NOT VALID;

ALTER TABLE creative_assets
  DROP CONSTRAINT IF EXISTS chk_asset_duration,
  ADD CONSTRAINT chk_asset_duration
  CHECK (
    (asset_type = 'video' AND duration_sec > 0)
    OR (asset_type <> 'video' AND duration_sec IS NULL)
  ) NOT VALID;

ALTER TABLE creative_assets
  DROP CONSTRAINT IF EXISTS chk_dimensions_format,
  ADD CONSTRAINT chk_dimensions_format
  CHECK (dimensions ~ '^[1-9][0-9]*x[1-9][0-9]*$' OR dimensions IS NULL);

ALTER TABLE budget_allocations
  DROP CONSTRAINT IF EXISTS chk_currency_format,
  ADD CONSTRAINT chk_currency_format
  CHECK (currency ~ '^[A-Z]{3}$') NOT VALID;

ALTER TABLE budget_allocations
  DROP CONSTRAINT IF EXISTS chk_budget_positive,
  ADD CONSTRAINT chk_budget_positive
  CHECK (amount_allocated >= 0) NOT VALID;

ALTER TABLE performance_metrics
  DROP CONSTRAINT IF EXISTS chk_nonnegative_metrics,
  ADD CONSTRAINT chk_nonnegative_metrics
  CHECK (
    impressions >= 0 AND clicks >= 0 AND engagements >= 0
    AND reach >= 0 AND booking_requests >= 0
    AND confirmed_bookings >= 0 AND revenue >= 0
  ) NOT VALID;

-- Test Queries

-- (1) Campaign end date before start date → should FAIL
INSERT INTO campaigns (campaign_id, name, objective, status, start_date, end_date)
VALUES (DEFAULT, 'Bad Campaign', 'Test', 'active', '2025-09-10', '2025-09-01');
-- Expect: ERROR: new row for relation "campaigns" violates check constraint "chk_campaign_dates"

-- (2) Vendor email missing "@" → should FAIL
INSERT INTO vendors (vendor_id, name, email) VALUES (DEFAULT, 'VendorX', 'bademail.com');
-- Expect: ERROR:  new row for relation "vendors" violates check constraint "chk_vendor_email"

-- (3) Video with duration 0
INSERT INTO creative_assets
(asset_id, asset_type, title, url_or_path, dimensions, duration_sec, created_at, compliance_ok)
VALUES
(DEFAULT, 'video', 'Broken Video', 'http://example.com/fail.mp4', '1920x1080', 0, CURRENT_TIMESTAMP, TRUE);
-- Expect: ERROR: new row for relation "creative_assets" violates check constraint "chk_asset_duration"

-- (4) image with invalid duration (only videos can have duration) → should FAIL
INSERT INTO creative_assets
(asset_id, asset_type, title, url_or_path, dimensions, duration_sec, created_at, compliance_ok)
VALUES
(DEFAULT, 'image', 'Broken Image', 'http://example.com/fail.jpg', '800x600', 45, DEFAULT, DEFAULT);
-- Expect: ERROR:  new row for relation "creative_assets" violates check constraint "chk_asset_duration"

-- (5) invalid creative_assets dimensions 
INSERT INTO creative_assets
(asset_id, asset_type, title, url_or_path, dimensions, duration_sec, created_at, compliance_ok)
VALUES
(DEFAULT, 'image', 'Bad Dimensions', 'http://example.com/img.jpg', '1920*1080', NULL, DEFAULT, DEFAULT);
-- Expect: ERROR:  new row for relation "creative_assets" violates check constraint "chk_dimensions_format"

-- (6) Budget with negative amount → should FAIL
INSERT INTO campaigns (campaign_id, name, objective, status, start_date, end_date)
VALUES (DEFAULT, 'Test Campaign', 'Test', 'active', '2025-09-10', '2025-09-30');

INSERT INTO budget_allocations (campaign_id, amount_allocated, currency)
VALUES (currval('campaigns_campaign_id_seq'), -500, 'USD');
-- Expect: ERROR:  new row for relation "budget_allocations" violates check constraint "chk_budget_positive"

-- (7) Budget with invalid currency format → should FAIL
INSERT INTO budget_allocations (campaign_id, amount_allocated, currency)
VALUES (currval('campaigns_campaign_id_seq'), 1000, 'usd');
-- Expect: ERROR: new row for relation "budget_allocations" violates check constraint "chk_currency_format"

-- Clean up
DELETE FROM campaigns
WHERE campaign_id = currval('campaigns_campaign_id_seq');

-- (8) Performance metrics with negative clicks → should FAIL
INSERT INTO performance_metrics (metric_id, stat_date, placement_id, impressions, clicks, revenue)
VALUES (DEFAULT, '2025-09-07', 1, 100, -5, 100.00);
-- Expect: ERROR:  ERROR:  new row for relation "performance_metrics" violates check constraint "chk_nonnegative_metrics"

-- (9) UPDATE vendor to invalid email → should FAIL
UPDATE vendors SET email = 'invalid' WHERE vendor_id = 1;
-- Expect: ERROR:  new row for relation "vendors" violates check constraint "chk_vendor_email"

-- (11) DELETE campaign with placements → should CASCADE
-- First insert valid campaign, placement, then delete campaign.
INSERT INTO campaigns (campaign_id, name, objective, status, start_date, end_date)
VALUES (DEFAULT, 'Cascade Campaign', 'Cascade Test', 'active', '2025-09-01', '2025-09-15');

INSERT INTO channels (channel_id, channel_name, rate_model)
VALUES (DEFAULT, 'Test Channel', 'CPM');

INSERT INTO vendors (vendor_id, name, email)
VALUES (DEFAULT, 'Cascade Vendor', 'cascade@example.com');

INSERT INTO creative_assets (asset_id, asset_type, title)
VALUES (DEFAULT, 'image', 'Cascade Image');

-- Insert placement tied to Cascade Campaign
INSERT INTO placements (placement_id, campaign_id, channel_id, vendor_id, asset_id, flight_start, flight_end)
VALUES (DEFAULT, currval('campaigns_campaign_id_seq'), currval('channels_channel_id_seq'),
        currval('vendors_vendor_id_seq'), currval('creative_assets_asset_id_seq'),
        '2025-09-01', '2025-09-10');

-- Now delete the campaign → placements should auto-delete
DELETE FROM campaigns WHERE name = 'Cascade Campaign';
-- Expect: placements referencing this campaign are also deleted (ON DELETE CASCADE)


