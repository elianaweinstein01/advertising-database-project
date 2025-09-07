# advertising-database-project
My project for my mini project in database systems class

## Proposal

### Problem & Goal
A travel agency runs many marketing campaigns across multiple media (newspapers, web, social, email). Each campaign can use several vendors and creatives, must stay within a budget, and needs performance tracking to see which spend actually drives bookings.  
**Goal:** design a normalized database that supports planning (budgets, dates), execution (placements on channels via vendors), and measurement (daily metrics tied to bookings/leads).

### Why these entities?
- **Campaign** – The organizing unit for marketing work (e.g., “Summer Greece 2025”). Holds objectives, timing, and status so teams can plan and report at the right level.
- **Channel** – Normalized lookup for the medium (Newspaper, Instagram, Google Search, Email, etc.). Lets us compare performance across channels without repeating text.
- **Vendor/Publisher** – The external company selling ad inventory (e.g., Haaretz, Meta). Needed for billing terms and accountability (who actually ran the ad).
- **CreativeAsset** – The concrete ad unit (image, text, video). Kept separate to avoid duplication because a single creative can be reused in many placements.
- **Placement** – The execution record that **connects Campaign + Channel + Vendor + CreativeAsset** with flight dates and plans; this resolves the many-to-many between Campaign and Channel.
- **BudgetAllocation** – Planned spend at campaign level.
- **PerformanceMetric** – Daily (or periodic) results per placement (impressions, clicks, conversions, spend, leads, bookings, revenue).

### How the design supports the workflow
1. **Plan** – Create a *Campaign*, allocate money in *BudgetAllocation*, set start/end dates and target regions/seasons.  
2. **Execute** – For each *Placement*, pick a *Channel*, *Vendor*, and *CreativeAsset*, then set flight dates and targeting.  
3. **Measure** – Load daily rows into *PerformanceMetric* for each placement. Analysts compare **planned vs. actual** across channels/vendors.

### Normalization choices
- Lookup/reference tables (**Channel, Vendor, CreativeAsset**) avoid duplicated names and attributes.
- “Planned” budgets are separate from “Actual” results (BudgetAllocation vs. PerformanceMetric).
- Keys and dates ensure integrity (campaign/flight windows, one performance row per placement/day).

### Target users
- **Marketing Managers:** create campaigns, book placements, and view performance by channel/vendor.
- **Finance/Operations:** allocate budgets, track currency/spend, and reconcile against results.
- **Analysts/Data Team:** evaluate funnels (leads → bookings → revenue).

### Files for Stage 1
- **ERD (image)**: `ERD.png` (embedded below).  
- **ERD (JSON source)**: `ERD.erdplus` (in repo).  
- **DSD (image)**: `DSD.png’
- **SQL schema**: `schema.sql` (PostgreSQL `CREATE TABLE` statements).

![ERD Diagram](ERD.png)

### Data Generation Process

To populate the database with realistic but synthetic data, I used a prompt-driven approach with ChatGPT. For each table, I wrote a natural-language prompt describing:
- Table name
- Fields and their types
- Constraints (unique IDs, foreign keys, value ranges, correlations)
ChatGPT then generated CSV files following those rules. Each CSV was downloaded and checked in Excel before being imported into the database.
I documented this process with screenshots of prompts and results, showing how the data was generated step by step. This ensures transparency in how the synthetic dataset was created.

### Dataset Sizes
- **Campaigns**: 20 rows
- **Channels**: 10 rows
- **Vendors**: 25 rows
- **CreativeAssets**: 200 rows
- **Placements**: 1,000 rows
- **BudgetAllocations**: 20 rows
- **PerformanceMetrics**: 200,000 rows
- **Total**: ~201,275 rows across all tables

## Screenshots

### Campaign Prompt
![Campaign Prompt](campaign_prompt.png)

### Channels Prompt
![Channels Prompt](channels_prompt.png)

### Vendors Prompt
![Vendors Prompt](vendors_prompt.png)

### CreativeAssets Prompt
![CreativeAssets Prompt](creative_asset_prompt.png)

### Placements Prompt
![Placements Prompt](placements_prompt_1.png)

### BudgetAllocations Prompt
![BudgetAllocations Prompt](budget_allocation_prompt.png)

### PerformanceMetrics Prompt
![PerformanceMetrics Prompt](performance_metrics_prompt.png)

## Dump

![Dump Screenshots](dump_ss_1.png)
![Dump Screenshots](dump_ss_3.png)
![Dump Screenshots](dump_ss_2.png)

### Stage 2

### Backups and Restore

In this stage, I prepared scripts to back up and restore the PostgreSQL database.

1. Plain SQL Backup
- Command: ./scripts/backup_sql.sh
- Output file: backupSQL.sql
- Log file: backupSQL.log (includes pg_dump output and timing statistics)

2. Custom Format Backup & Restore
- Command: ./scripts/backup_psql.sh
- Output file: backupPSQL.sql
- Log file: backupPSQL.log (includes pg_dump output and timing statistics)

Restore tested with: 
- DROP SCHEMA public CASCADE;
- CREATE SCHEMA public;
- ./scripts/restore_psql.sh


### Constraints 

In this stage of the project, I strengthened the database schema by adding ancillary constraints using ALTER TABLE. These constraints ensure data integrity beyond just primary and foreign keys. I then wrote test queries (INSERT, UPDATE, DELETE) that intentionally violate the constraints to confirm they are enforced. Finally, I captured all inputs and outputs (including error messages) into a log file for documentation (constraints.log).

### Step 1: I added the following constraints across multiple tables:

### 1) Campaigns
- chk_campaign_dates: Ensures end_date >= start_date.

### 2) Vendors
- chk_vendor_email: Validates email format with regex.

### 3) Creative Assets
- chk_asset_duration: Only videos can have a positive duration, all other asset types must have NULL.
- chk_dimensions_format: Ensures dimensions are in WIDTHxHEIGHT format (e.g., 1920x1080) with nonzero values.

### 4) Budget Allocations
- chk_budget_positive: Ensures allocated budget is greater than 0.
- chk_currency_format: Enforces three uppercase letters (e.g., USD, ILS) for currency codes.

### 5) Performance Metrics
- chk_nonnegative_metrics: Ensures all numeric statistics (impressions, clicks, revenue, etc.) are nonnegative.

### Step 2: For each constraint, I wrote queries that deliberately fail:

- Campaign with end_date before start_date → violates chk_campaign_dates.
- Vendor with invalid email → violates chk_vendor_email.
- Video asset with duration = 0 → violates chk_asset_duration.
- Image asset with duration → violates chk_asset_duration.
- Creative asset with invalid dimensions (1920*1080) → violates chk_dimensions_format.
- Negative budget allocation → violates chk_budget_positive.
- Currency not uppercase (usd) → violates chk_currency_format.
- Negative clicks in performance metrics → violates chk_nonnegative_metrics.
- Update vendor email to invalid string → violates chk_vendor_email.
- Cascade delete test: Inserted a campaign with related placement, then deleted the campaign to confirm that placements were automatically deleted (ON DELETE CASCADE).

### Step 3: Captured Logs:
- I ran the script using: psql -h localhost -p 5432 -U postgres -d travel_ads -f Constraints.sql 2>&1 | tee constraints.log
- ![Constraints Screenshots](constraints-sc-1.png)
- This produced a log file (constraints.log) with both commands and error messages.
- ![Constraints Screenshots](constraints-cs-2.png)

## ERROR and message explanations (from constraints.log)
- ALTER TABLE (multiple lines)
Meaning: All constraint DDL statements executed successfully (no errors here).
- psql:Constraints.sql:89: ERROR: new row for relation "relation" violates check constraint "chk_constraint" (multiple times).
Meaning: the constraints that I added were violated (intentionally)
- INSERT 0 1 (right after the above)
Meaning: The setup campaign for the budget tests inserted successfully.
- DELETE 1
Meaning: Cleanup delete of the test campaign succeeded (and cascades ran as defined).
### All failing statements intentionally triggered the new CHECK constraints, confirming they work; setup/cleanup statements behaved correctly, including cascade deletes.

### Files
- Constraints.sql: Contains all ALTER TABLE statements and test queries.
- constraints.log: Log file capturing all inputs and outputs.








