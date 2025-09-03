\timing on
-- Q1: Creative assets after a certain date
PREPARE assets_after_date(date) AS
SELECT asset_id, asset_type, created_at
FROM creative_assets
WHERE created_at > $1
ORDER BY created_at;

EXECUTE assets_after_date('2024-01-01');


-- Q2: Impressions + clicks for a channel
PREPARE campaigns_by_vendor(text) AS
SELECT DISTINCT c.campaign_id, c.name, v.name
FROM campaigns c
JOIN placements p ON p.campaign_id = c.campaign_id
JOIN vendors v ON v.vendor_id = p.vendor_id
WHERE v.name = $1;

EXECUTE campaigns_by_vendor('Google Ads');


-- Q3: Impressions + clicks for a channel
PREPARE channel_stats(int) AS
SELECT ch.channel_id, ch.channel_name,
       SUM(pm.impressions) AS total_impressions,
       SUM(pm.clicks) AS total_clicks
FROM performance_metrics pm
JOIN placements p ON p.placement_id = pm.placement_id
JOIN channels ch ON ch.channel_id = p.channel_id
WHERE ch.channel_id = $1
GROUP BY ch.channel_id, ch.channel_name;

EXECUTE channel_stats(2);

-- Q4: Average revenue for placements in one campaign
PREPARE avg_revenue_for_campaign(int) AS
SELECT c.campaign_id, c.name,
       ROUND(AVG(pm.revenue), 2) AS avg_revenue
FROM performance_metrics pm
JOIN placements p ON p.placement_id = pm.placement_id
JOIN campaigns c ON c.campaign_id = p.campaign_id
WHERE c.campaign_id = $1
GROUP BY c.campaign_id, c.name;

EXECUTE avg_revenue_for_campaign(5);
\timing off
