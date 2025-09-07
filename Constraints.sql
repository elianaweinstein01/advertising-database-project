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
