-- Run this file with:
-- psql -h localhost -p 5432 -U postgres -d travel_ads -f Stage3_Queries.sql 2>&1 | tee stage4_queries.log

\pset pager off

\echo === Q1 (SELECT): Instagram Reels placements per campaign ===
\timing on
SELECT
  c.campaign_id,
  c.name AS campaign_name,
  p.flight_start,
  p.flight_end
FROM placements p
JOIN campaigns c ON c.campaign_id = p.campaign_id
JOIN channels  ch ON ch.channel_id = p.channel_id
WHERE ch.channel_name = 'instagram'
  AND ch.subtype     = 'reels'
ORDER BY c.campaign_id, p.flight_start;
\timing off

\echo === Q2 (UPDATE): +10% budget for campaigns with bookings in last 30 days ===
\timing off
BEGIN;
\timing on
UPDATE budget_allocations ba
SET amount_allocated = ROUND(ba.amount_allocated * 1.10, 2)
WHERE EXISTS (
  SELECT 1
  FROM placements p
  JOIN performance_metrics pm ON pm.placement_id = p.placement_id
  WHERE p.campaign_id = ba.campaign_id
    AND pm.stat_date >= CURRENT_DATE - INTERVAL '30 days'
    AND COALESCE(pm.confirmed_bookings, 0) > 0
);
\timing off
ROLLBACK;

\echo === Q3 (SELECT): Bookings by campaign from newspaper ads ===
\timing on
SELECT 
  c.campaign_id,
  c.name AS campaign_name,
  SUM(COALESCE(pm.confirmed_bookings, 0)) AS total_bookings
FROM performance_metrics pm
JOIN placements p ON p.placement_id = pm.placement_id
JOIN channels ch  ON ch.channel_id = p.channel_id
JOIN campaigns c  ON c.campaign_id = p.campaign_id
WHERE ch.channel_name ILIKE 'newspaper'
GROUP BY c.campaign_id, c.name
ORDER BY total_bookings DESC;
\timing off



