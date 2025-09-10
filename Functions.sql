-- 1) Q1 replacement: Top-N campaigns by total revenue
create or replace function f_top_campaign_revenue(p_limit int)
returns table(
  campaign_id int,
  name text,
  total_revenue numeric
)
as
$func$
begin
  return query
  select
    c.campaign_id,
    c.name,
    sum(pm.revenue) as total_revenue
  from performance_metrics pm
  join placements p on p.placement_id = pm.placement_id
  join campaigns  c on c.campaign_id   = p.campaign_id
  group by c.campaign_id, c.name
  order by total_revenue desc
  limit p_limit;
end;
$func$
language plpgsql;

-- 2) Q3 replacement: Vendor revenue totals (highest to lowest)
create or replace function f_vendor_revenue()
returns table(
  vendor_id    int,
  vendor_name  text,
  revenue      numeric
)
as
$func$
begin
  return query
  select
    v.vendor_id,
    v.name as vendor_name,
    sum(pm.revenue) as revenue
  from performance_metrics pm
  join placements p on p.placement_id = pm.placement_id
  join vendors v on v.vendor_id = p.vendor_id
  group by v.vendor_id, v.name
  order by revenue desc;
end;
$func$
language plpgsql;

-- 3) Q4 replacement: Daily confirmed bookings for one campaign
create or replace function f_campaign_daily_bookings(p_campaign_id int)
returns table(
  stat_date      date,
  total_bookings bigint
)
as
$func$
begin
  return query
  select
    pm.stat_date,
    sum(pm.confirmed_bookings)::bigint as total_bookings
  from performance_metrics pm
  join placements p on p.placement_id = pm.placement_id
  where p.campaign_id = p_campaign_id
  group by pm.stat_date
  order by pm.stat_date;
end;
$func$
language plpgsql;

-- 4) Q6 Bump budgets for ACTIVE campaigns by a percent. Returns number of rows updated.
create or replace function f_bump_active_budgets(p_percent numeric)
returns integer
as
$func$
declare
  v_rows int;
begin
  -- p_percent = 0.10 means +10%
  update budget_allocations ba
  set amount_allocated = round(ba.amount_allocated * (1 + p_percent), 2)
  where exists (
    select 1
    from campaigns c
    where c.campaign_id = ba.campaign_id
      and c.status = 'active'
  );

  get diagnostics v_rows = row_count;
  return v_rows;
end;
$func$
language plpgsql;
