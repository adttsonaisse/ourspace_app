-- M13 push webhooks — run after m11_device_tokens.sql.
-- Calls the send-push Edge Function on every partner-visible insert
-- (notes / piles / date_plans) so the partner gets a system push even
-- when the app is closed. Best-effort: pg_net posts in the background;
-- a failed post never blocks the insert.
--
-- BEFORE RUNNING, replace these two placeholders:
--   <PUSH_WEBHOOK_SECRET>  a long random string (e.g. openssl rand -hex 32).
--                          Must equal the PUSH_WEBHOOK_SECRET function secret.
-- The function URL below already matches this project; change it only
-- if the project ref ever changes.
--
-- Requires (one dashboard click each, also needed once):
--   1) Edge Function "send-push" deployed from supabase/functions/send-push.
--   2) Function secrets set: FIREBASE_SERVICE_ACCOUNT_JSON,
--      PUSH_WEBHOOK_SECRET (= the same random string).
--   3) Function "Verify JWT" OFF (Dashboard > Edge Functions > send-push >
--      Settings) — auth here is the x-push-secret header, and pg_net has
--      no user JWT to send.

create extension if not exists pg_net;

create or replace function notify_push()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  payload jsonb;
  spaceid uuid;
  actor uuid;
  title text := '';
  body text := '';
begin
  if TG_TABLE_NAME = 'notes' then
    spaceid := NEW.space_id; actor := NEW.author_id;
    title := 'added a sweet note'; body := left(NEW.body, 120);
  elsif TG_TABLE_NAME = 'piles' then
    spaceid := NEW.space_id; actor := NEW.created_by;
    title := 'added a pile: ' || NEW.title; body := coalesce(NEW.location, '');
  elsif TG_TABLE_NAME = 'date_plans' then
    spaceid := NEW.space_id; actor := NEW.created_by;
    title := 'planned a date: ' || NEW.title; body := coalesce(NEW.place, '');
  end if;
  payload := jsonb_build_object(
    'table', TG_TABLE_NAME,
    'space_id', spaceid,
    'actor_id', actor,
    'title', title,
    'body', body
  );
  perform net.http_post(
    url := 'https://idyixvfepfuylmopvwbc.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', '<PUSH_WEBHOOK_SECRET>'
    ),
    body := payload
  );
  return NEW;
exception
  when others then
    -- Push must never break the insert (e.g. pg_net hiccup).
    return NEW;
end;
$$;

drop trigger if exists push_on_note on notes;
create trigger push_on_note
  after insert on notes for each row execute function notify_push();

drop trigger if exists push_on_pile on piles;
create trigger push_on_pile
  after insert on piles for each row execute function notify_push();

drop trigger if exists push_on_date on date_plans;
create trigger push_on_date
  after insert on date_plans for each row execute function notify_push();
