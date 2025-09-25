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
