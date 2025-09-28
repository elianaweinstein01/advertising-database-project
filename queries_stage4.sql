\timing on

\echo === V1-Q1: Customer-level attribution report for a specific campaign ===
-- Lists customers and their bookings for a given campaign (example: campaign_id = 6)
SELECT
  customer_name,
  contact_info,
  booking_date,
  booking_id,
  campaign_name
FROM public.attributed_bookings_v
WHERE campaign_id = 6
ORDER BY booking_date DESC, customer_name;

\echo === V1-Q2 (SELECT): Channels driving bookings this quarter ===
WITH quarter_bounds AS (
  SELECT
    date_trunc('quarter', CURRENT_DATE)::date AS q_start,
    (date_trunc('quarter', CURRENT_DATE) + INTERVAL '3 months')::date AS q_end
)
SELECT
  channel_name,
  subtype,
  COUNT(DISTINCT booking_id) AS bookings_this_quarter
FROM public.attributed_bookings_v ab
CROSS JOIN quarter_bounds qb
WHERE ab.booking_date >= qb.q_start
  AND ab.booking_date < qb.q_end
GROUP BY channel_name, subtype
ORDER BY bookings_this_quarter DESC, channel_name, subtype;


\echo === V2-Q3 (SELECT): Channel usage by age band (18–24, 25–34, 35–44) ===
WITH base AS (
  SELECT
    customer_id,
    channel_name,
    subtype,
    EXTRACT(YEAR FROM age(CURRENT_DATE, date_of_birth))::int AS age_years
  FROM public.customer_channel_age_v
  WHERE date_of_birth IS NOT NULL
),
banded AS (
  SELECT
    channel_name,
    subtype,
    CASE
      WHEN age_years BETWEEN 18 AND 24 THEN '18–24'
      WHEN age_years BETWEEN 25 AND 34 THEN '25–34'
      WHEN age_years BETWEEN 35 AND 44 THEN '35–44'
      ELSE '45+'
    END AS age_band,
    customer_id
  FROM base
)
SELECT
  age_band,
  channel_name,
  subtype,
  COUNT(DISTINCT customer_id) AS customers_in_band
FROM banded
GROUP BY age_band, channel_name, subtype
ORDER BY age_band, customers_in_band DESC, channel_name, subtype;


\echo === V2-Q4: customers who engaged in both instagram and newspaper ===
SELECT customer_id, customer_name 
FROM public.customer_channel_age_v 
WHERE channel_name IN ('Instagram','Newspaper') 
GROUP BY customer_id, customer_name 
HAVING COUNT(DISTINCT channel_name) > 1;

\timing off
