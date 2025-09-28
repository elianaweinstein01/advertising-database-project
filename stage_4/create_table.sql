-- =========================================
-- MERGED SCHEMA: Advertising + Booking
-- =========================================

-- ===== ADVERTISING TABLES =====
DROP TABLE IF EXISTS performance_metrics CASCADE;
DROP TABLE IF EXISTS budget_allocations CASCADE;
DROP TABLE IF EXISTS placements CASCADE;
DROP TABLE IF EXISTS creative_assets CASCADE;
DROP TABLE IF EXISTS vendors CASCADE;
DROP TABLE IF EXISTS channels CASCADE;
DROP TABLE IF EXISTS campaigns CASCADE;

CREATE TABLE campaigns (
    campaign_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    objective TEXT,
    status TEXT CHECK (status IN ('active','planned','paused','closed')),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    ramp_up_phase BOOLEAN DEFAULT FALSE,
    season TEXT,
    target_region TEXT
);

CREATE TABLE channels (
    channel_id SERIAL PRIMARY KEY,
    channel_name TEXT NOT NULL,
    subtype TEXT,
    rate_model TEXT CHECK (rate_model IN ('CPM','CPC','FLAT','CPA'))
);

CREATE TABLE vendors (
    vendor_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    contact_name TEXT,
    email TEXT,
    phone TEXT,
    billing_terms TEXT CHECK (billing_terms IN ('NET15','NET30','NET45','NET60','PREPAID'))
);

CREATE TABLE creative_assets (
    asset_id SERIAL PRIMARY KEY,
    asset_type TEXT CHECK (asset_type IN ('image','video','text','audio')),
    title TEXT,
    url_or_path TEXT,
    dimensions TEXT,
    duration_sec INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    compliance_ok BOOLEAN DEFAULT TRUE
);

CREATE TABLE placements (
    placement_id SERIAL PRIMARY KEY,
    campaign_id INT NOT NULL REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
    channel_id INT NOT NULL REFERENCES channels(channel_id) ON DELETE CASCADE,
    vendor_id INT NOT NULL REFERENCES vendors(vendor_id) ON DELETE CASCADE,
    asset_id INT NOT NULL REFERENCES creative_assets(asset_id) ON DELETE CASCADE,
    flight_start DATE NOT NULL,
    flight_end DATE NOT NULL,
    CHECK (flight_end >= flight_start)
);

CREATE TABLE budget_allocations (
    campaign_id INT PRIMARY KEY REFERENCES campaigns(campaign_id) ON DELETE CASCADE,
    amount_allocated NUMERIC(12,2) NOT NULL,
    currency CHAR(3) NOT NULL
);

CREATE TABLE performance_metrics (
    metric_id SERIAL PRIMARY KEY,
    stat_date DATE NOT NULL,
    impressions INT,
    clicks INT,
    engagements INT,
    reach INT,
    booking_requests INT,
    confirmed_bookings INT,
    revenue NUMERIC(12,2),
    placement_id INT NOT NULL REFERENCES placements(placement_id) ON DELETE CASCADE,
    UNIQUE (placement_id, stat_date)
);

-- ===== BOOKINGS TABLES =====
DROP TABLE IF EXISTS Room CASCADE;
DROP TABLE IF EXISTS Hotel CASCADE;
DROP TABLE IF EXISTS Flight CASCADE;
DROP TABLE IF EXISTS Booking CASCADE;
DROP TABLE IF EXISTS Customer CASCADE;
DROP TABLE IF EXISTS Car_Rental CASCADE;
DROP TABLE IF EXISTS Package_Deal CASCADE;

CREATE TABLE Customer (
    customer_id INT PRIMARY KEY CHECK (customer_id > 0),
    name VARCHAR(20) NOT NULL,
    contact_info VARCHAR(50) NOT NULL,
    date_of_birth DATE NOT NULL
);

CREATE TABLE Booking (
    booking_id INT PRIMARY KEY CHECK (booking_id > 0),
    booking_date DATE NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    customer_id INT NOT NULL REFERENCES Customer(customer_id)
);

CREATE TABLE Flight (
    flight_id INT PRIMARY KEY CHECK (flight_id > 0),
    flight_number VARCHAR(10) NOT NULL,
    origin VARCHAR(50) NOT NULL,
    destination VARCHAR(50) NOT NULL,
    departure_time VARCHAR(20) NOT NULL,
    arrival_time VARCHAR(20) NOT NULL,
    ticket_price DECIMAL(10, 2) NOT NULL
);

CREATE TABLE Hotel (
    hotel_id INT PRIMARY KEY CHECK (hotel_id > 0),
    name VARCHAR(20) NOT NULL,
    hotel_location VARCHAR(50) NOT NULL,
    star_rating INT CHECK (star_rating BETWEEN 1 AND 5)
);

CREATE TABLE Room (
    room_number INT NOT NULL CHECK (room_number > 0),
    hotel_id INT NOT NULL CHECK (hotel_id > 0),
    room_type VARCHAR(50) NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    price_per_night DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (room_number, hotel_id, check_in_date),
    FOREIGN KEY (hotel_id) REFERENCES Hotel(hotel_id)
);

CREATE TABLE Car_Rental (
    rental_transaction_id INT PRIMARY KEY CHECK (rental_transaction_id > 0),
    company VARCHAR(20) NOT NULL,
    car_model VARCHAR(20) NOT NULL,
    rental_date DATE NOT NULL,
    rental_location VARCHAR(50) NOT NULL,
    daily_rate DECIMAL(10, 2) NOT NULL
);

CREATE TABLE Package_Deal (
    deal_id INT PRIMARY KEY CHECK (deal_id > 0),
    deal_name VARCHAR(20) NOT NULL,
    discount_percent DECIMAL(5, 2) NOT NULL CHECK (discount_percent BETWEEN 0 AND 100)
);

-- ===== BRIDGE TABLE =====
DROP TABLE IF EXISTS public.booking_attribution CASCADE;
CREATE TABLE public.booking_attribution (
    booking_id INT NOT NULL REFERENCES Booking(booking_id) ON DELETE CASCADE,
    placement_id INT NOT NULL REFERENCES placements(placement_id) ON DELETE CASCADE,
    PRIMARY KEY (booking_id, placement_id)
);
