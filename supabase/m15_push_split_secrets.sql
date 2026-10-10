-- M15 push split secrets — run after m13 + m14.
-- Memindahkan secret pg_net dari literal di prosrc ke vault, dan ganti ke
-- PUSH_PARTNER_SECRET (bukan lagi secret gabungan).
--
-- Langkah dashboard sekali saja (sebelum/sesudah migration ini):
--   1) Edge Functions > Secrets: sudah ada PUSH_PARTNER_SECRET +
--      PUSH_BROADCAST_SECRET (kamu sudah tambah).
--   2) SQL editor: simpan partner secret ke vault (ganti <isi-sama>):
--        select vault.create_secret('<isi-sama-dengan-PUSH_PARTNER_SECRET>', 'push_partner_secret');
--   3) Jalankan migration ini.
--   4) Verifikasi: select prosrc from pg_proc where proname='notify_push';
--      pastikan tidak ada lagi string secret mentah di sana.
--   5) Nanti setelah workflow pindah ke PUSH_BROADCAST_SECRET:
--        delete from vault.decrypted_secrets ... (tidak perlu, vault aman);
--        hapus secret lama PUSH_WEBHOOK_SECRET dari Edge Secrets.

create extension if not exists pg_net;
create extension if not exists supabase_vault cascade;

create or replace function notify_push()
returns trigger language plpgsql security definer set search_path = public, extensions, vault as $$
declare
  payload jsonb;
  spaceid uuid;
  actor uuid;
  title text := '';
  body text := '';
  psecret text;
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
  -- Secret dibaca dari vault saat runtime, tidak lagi tertanam di prosrc.
  select decrypted_secret into psecret
  from vault.decrypted_secrets where name = 'push_partner_secret' limit 1;
  if psecret is null or psecret = '' then return NEW; end if;
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
      'x-push-secret', psecret
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

-- Kunci akses: hanya service_role / postgres yang boleh execute langsung.
revoke all on function notify_push() from public;
revoke all on function notify_push() from anon, authenticated;
