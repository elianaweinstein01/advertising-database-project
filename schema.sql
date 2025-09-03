CREATE TABLE campaigns (
  campaign_id     SERIAL PRIMARY KEY,
  name            TEXT NOT NULL,
  objective       TEXT,
  status          TEXT CHECK (status IN ('active','planned','paused','closed')),
  start_date      DATE NOT NULL,
  end_date        DATE NOT NULL,
  ramp_up_phase   BOOLEAN DEFAULT FALSE,
  season          TEXT,
  target_region   TEXT
);

CREATE TABLE channels (
  channel_id    SERIAL PRIMARY KEY,
  channel_name  TEXT NOT NULL,
  subtype       TEXT,
  rate_model    TEXT CHECK (rate_model IN ('CPM','CPC','FLAT','CPA'))
);

CREATE TABLE vendors (
  vendor_id     SERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  contact_name  TEXT,
  email         TEXT,
  phone         TEXT,
  billing_terms TEXT CHECK (billing_terms IN ('NET15','NET30','NET45','NET60','PREPAID'))
);

CREATE TABLE creative_assets (
  asset_id      SERIAL PRIMARY KEY,
  asset_type    TEXT CHECK (asset_type IN ('image','video','text','audio')),
  title         TEXT,
  url_or_path   TEXT,
  dimensions    TEXT,
  duration_sec  INT,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  compliance_ok BOOLEAN DEFAULT TRUE
);

CREATE TABLE placements (
  placement_id  SERIAL PRIMARY KEY,
  campaign_id   INT NOT NULL REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
  channel_id    INT NOT NULL REFERENCES channels(channel_id) ON DELETE CASCADE,
  vendor_id     INT NOT NULL REFERENCES vendors(vendor_id) ON DELETE CASCADE,
  asset_id      INT NOT NULL REFERENCES creative_assets(asset_id) ON DELETE CASCADE,
  flight_start  DATE NOT NULL,
  flight_end    DATE NOT NULL,
  CHECK (flight_end >= flight_start)
);

CREATE TABLE budget_allocations (
  campaign_id      INT PRIMARY KEY REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
  amount_allocated NUMERIC(12,2) NOT NULL,
  currency         CHAR(3) NOT NULL
);

CREATE TABLE performance_metrics (
  metric_id          SERIAL PRIMARY KEY,
  stat_date          DATE NOT NULL,
  impressions        INT,
  clicks             INT,
  engagements        INT,
  reach              INT,
  booking_requests   INT,
  confirmed_bookings INT,
  revenue            NUMERIC(12,2),
  placement_id       INT NOT NULL REFERENCES placements(placement_id) ON DELETE CASCADE,
  UNIQUE (placement_id, stat_date)   -- no duplicates for same placement/day
);
