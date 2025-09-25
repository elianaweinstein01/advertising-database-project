\pset pager off
\timing on

--View #1
CREATE OR REPLACE VIEW public.attributed_bookings_v AS
SELECT
  ba.booking_id,
  b.booking_date,
  b.customer_id,
  cst.name          AS customer_name,
  cst.contact_info,

  ba.placement_id,
  p.campaign_id,
  camp.name         AS campaign_name,
  p.channel_id,
  ch.channel_name,
  ch.subtype
FROM public.booking_attribution ba
JOIN ta2.booking      b   ON b.booking_id = ba.booking_id
JOIN ta2.customer     cst ON cst.customer_id = b.customer_id
JOIN public.placements p  ON p.placement_id = ba.placement_id
JOIN public.campaigns  camp ON camp.campaign_id = p.campaign_id
JOIN public.channels   ch   ON ch.channel_id  = p.channel_id;

--Trigger which makes the view updatable 
CREATE OR REPLACE FUNCTION public.trg_attributed_bookings_dml()
RETURNS trigger
LANGUAGE plpgsql AS
$$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- validate FK existence
    PERFORM 1 FROM ta2.booking WHERE booking_id = NEW.booking_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Booking % does not exist', NEW.booking_id;
    END IF;

    PERFORM 1 FROM public.placements WHERE placement_id = NEW.placement_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Placement % does not exist', NEW.placement_id;
    END IF;

    INSERT INTO public.booking_attribution(booking_id, placement_id)
    VALUES (NEW.booking_id, NEW.placement_id)
    ON CONFLICT DO NOTHING;            -- idempotent

    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
    -- move the attribution to a different placement
    UPDATE public.booking_attribution
       SET placement_id = NEW.placement_id
     WHERE booking_id   = OLD.booking_id
       AND placement_id = OLD.placement_id;

    RETURN NEW;

  ELSIF TG_OP = 'DELETE' THEN
    DELETE FROM public.booking_attribution
     WHERE booking_id   = OLD.booking_id
       AND placement_id = OLD.placement_id;

    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_attributed_bookings_dml
ON public.attributed_bookings_v;

CREATE TRIGGER trg_attributed_bookings_dml
INSTEAD OF INSERT OR UPDATE OR DELETE ON public.attributed_bookings_v
FOR EACH ROW EXECUTE FUNCTION public.trg_attributed_bookings_dml();

\echo === V1 (SELECT): Show first 10 attributions ===
SELECT *
FROM public.attributed_bookings_v
ORDER BY booking_date DESC
LIMIT 10;

\echo === V1 (INSERT valid): add one booking→placement attribution (then ROLLBACK) ===
BEGIN;
-- Use real IDs that exist in ta2.booking and public.placements:
INSERT INTO public.attributed_bookings_v (booking_id, placement_id)
VALUES (1010, 5);
ROLLBACK;

\echo === V1 (UPDATE valid): move that booking to a different placement (then ROLLBACK) ===
BEGIN;
UPDATE public.attributed_bookings_v
SET placement_id = 6
WHERE booking_id = 1010
  AND placement_id = 5;
ROLLBACK;

\echo === V1 (DELETE valid): remove that attribution (then ROLLBACK) ===
BEGIN;
DELETE FROM public.attributed_bookings_v
WHERE booking_id = 1010
  AND placement_id = 6;
ROLLBACK;

-- View 2
DROP VIEW IF EXISTS public.customer_channel_age_v CASCADE;

CREATE OR REPLACE VIEW public.customer_channel_age_v AS
SELECT
  c.customer_id,
  c.name          AS customer_name,
  c.contact_info,
  c.date_of_birth,
  p.channel_id,
  ch.channel_name,
  ch.subtype
FROM ta2.customer      c
LEFT JOIN ta2.booking  b   ON b.customer_id   = c.customer_id
LEFT JOIN public.booking_attribution ba ON ba.booking_id   = b.booking_id
LEFT JOIN public.placements          p  ON p.placement_id  = ba.placement_id
LEFT JOIN public.channels            ch ON ch.channel_id   = p.channel_id;

--Trigger which makes the view updatable 
CREATE OR REPLACE FUNCTION public.trg_customer_channel_dml()
RETURNS trigger
LANGUAGE plpgsql AS
$$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Insert into base table but now REQUIRE customer_id to be provided
    INSERT INTO ta2.customer (customer_id, name, contact_info, date_of_birth)
    VALUES (NEW.customer_id, NEW.customer_name, NEW.contact_info, NEW.date_of_birth);

    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE ta2.customer
       SET name = NEW.customer_name,
           contact_info = NEW.contact_info,
           date_of_birth = NEW.date_of_birth
     WHERE customer_id = OLD.customer_id;

    RETURN NEW;

  ELSIF TG_OP = 'DELETE' THEN
    DELETE FROM ta2.customer
     WHERE customer_id = OLD.customer_id;

    RETURN OLD;
  END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_customer_channel_dml ON public.customer_channel_age_v;

CREATE TRIGGER trg_customer_channel_dml
INSTEAD OF INSERT OR UPDATE OR DELETE ON public.customer_channel_age_v
FOR EACH ROW EXECUTE FUNCTION public.trg_customer_channel_dml();


\echo === V2 (SELECT): sample customers with channel context ===
SELECT customer_id, customer_name, date_of_birth, channel_name, subtype
FROM public.customer_channel_age_v
ORDER BY customer_id
LIMIT 10;


\echo === V2 (INSERT via view): add a customer (then ROLLBACK) ===
BEGIN;

INSERT INTO public.customer_channel_age_v
(customer_id, customer_name, contact_info, date_of_birth)
VALUES (1000002, 'View Demo Customer', 'viewdemo@example.com', '1995-04-20');

ROLLBACK; 


\echo === V2 (UPDATE via view): correct date_of_birth (then ROLLBACK) ===
BEGIN;

-- Change the contact info of a known customer
UPDATE public.customer_channel_age_v
SET contact_info = 'updated_email@example.com'
WHERE customer_id = 9999;

ROLLBACK; -- undo the change for safety



\echo === V2 (DELETE via view): delete a customer (then ROLLBACK) ===
BEGIN;

-- Create a throwaway with an explicit customer_id (required by your trigger)
WITH new_c AS (
  INSERT INTO public.customer_channel_age_v (customer_id, customer_name, contact_info, date_of_birth)
  VALUES (1000003, 'Temp To Delete', 'temp.del@example.com', '1990-01-01')
  RETURNING customer_id
)
DELETE FROM public.customer_channel_age_v
WHERE customer_id = (SELECT customer_id FROM new_c);

-- Confirm gone from base table:
SELECT * FROM ta2.customer WHERE customer_id = 1000003;

ROLLBACK;  -- switch to COMMIT to keep





