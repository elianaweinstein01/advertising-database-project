\timing on

\set campaign_id 1
\set placement_id 1
\set start_date '2024-01-01'
\set end_date   '2024-03-31'

\echo === Q1 (SELECT): Top 5 campaigns by total revenue ===
  
SELECT
  c.campaign_id,
  c.name,
  SUM(pm.revenue) AS total_revenue
FROM performance_metrics pm
JOIN placements p ON p.placement_id = pm.placement_id
JOIN campaigns c ON c.campaign_id = p.campaign_id
GROUP BY c.campaign_id, c.name
ORDER BY total_revenue DESC
LIMIT 5;


\echo === Q1 via function: Top-N campaigns by total revenue ===
SELECT * FROM f_top_campaign_revenue(5);

\echo ------------------

\echo === Q2 (SELECT): Impressions, clicks, simple CTR by channel (Click Through Rate : a basic advertising metric that measures how often people who see an ad actually click on it.)===
  
SELECT
  ch.channel_id,
  ch.channel_name,
  SUM(pm.impressions) AS impressions,
  SUM(pm.clicks) AS clicks,
  ROUND(100.0 * SUM(pm.clicks) / NULLIF(SUM(pm.impressions), 0), 2) AS ctr_percent
FROM performance_metrics pm
JOIN placements p ON p.placement_id = pm.placement_id
JOIN channels ch ON ch.channel_id  = p.channel_id
GROUP BY ch.channel_id, ch.channel_name
ORDER BY impressions DESC;

\echo ------------------

\echo === Q3 (SELECT): Vendor revenue totals (highest to lowest) ===
  
SELECT
  v.vendor_id,
  v.name AS vendor_name,
  SUM(pm.revenue) AS revenue
FROM performance_metrics pm
JOIN placements p ON p.placement_id = pm.placement_id
JOIN vendors v ON v.vendor_id = p.vendor_id
GROUP BY v.vendor_id, v.name
ORDER BY revenue DESC;

\echo === Q3 via function: Vendor revenue totals (highest to lowest) ===
SELECT * FROM f_vendor_revenue();

\echo ------------------


\echo === Q4 (SELECT): Daily confirmed bookings for one campaign ===
SELECT 
  pm.stat_date,
  SUM(pm.confirmed_bookings) AS total_bookings
FROM performance_metrics pm
JOIN placements p ON p.placement_id = pm.placement_id
WHERE p.campaign_id = :campaign_id
GROUP BY pm.stat_date
ORDER BY pm.stat_date;

\echo === Q4 via function: Daily confirmed bookings for one campaign ===
\set campaign_id 1
SELECT * FROM f_campaign_daily_bookings(:campaign_id);

\echo ------------------

\echo === Q5 (UPDATE): Close campaigns that already ended (no changes applied by default) ===
BEGIN;

UPDATE campaigns
SET status = 'closed'
WHERE end_date < CURRENT_DATE
  AND status <> 'closed';
ROLLBACK;

\echo ------------------

\echo === Q6 (UPDATE): +5% budget for all ACTIVE campaigns (no changes applied by default) ===
BEGIN;

UPDATE budget_allocations ba
SET amount_allocated = ROUND(ba.amount_allocated * 1.05, 2)
WHERE EXISTS (
  SELECT 1 FROM campaigns c
  WHERE c.campaign_id = ba.campaign_id
    AND c.status = 'active'
);
ROLLBACK;

\echo === Q6 via function: +5% budget for all ACTIVE campaigns (dry run) ===
BEGIN;
SELECT f_bump_active_budgets(0.05) AS rows_updated;
ROLLBACK;

\echo ------------------

\echo === Q7 (DELETE): Remove perf rows for one placement in a date range (no changes applied) ===
BEGIN;

DELETE FROM performance_metrics
WHERE placement_id = 123   -- example placement
  AND stat_date >= '2024-01-01'::date
  AND stat_date <= '2024-01-31'::date;

ROLLBACK;

\echo ------------------

\echo === Q8 (DELETE): Remove creative assets not used by any placement (no changes applied) ===
BEGIN;
DELETE FROM creative_assets ca
WHERE NOT EXISTS (
  SELECT 1 FROM placements p WHERE p.asset_id = ca.asset_id
);
ROLLBACK;

\timing off
