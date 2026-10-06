-- M11 device tokens — run after schema.sql.
-- Stores FCM tokens so the send-push Edge Function can notify the
-- partner (realtime push works even when the app is closed).
-- One row per (user, token): multi-device safe. Tokens are secrets:
-- RLS is self-only, the Edge Function reads them with service_role.

create table if not exists device_tokens (
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

alter table device_tokens enable row level security;

-- Own rows only: register/refresh/unregister from the app.
drop policy if exists device_tokens_self_all on device_tokens;
create policy device_tokens_self_all on device_tokens for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
