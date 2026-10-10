-- M14 security hardening — run after schema.sql + m6..m13.
-- Addresses audit findings without breaking existing clients:
-- 1) pin search_path on every SECURITY DEFINER function
-- 2) close direct space_members self-insert bypass (joins only via RPC)
-- 3) tighten spaces_update so created_by can't be rewritten
-- 4) atomic create_space + leave_space RPCs (client already prefers them,
--    falls back to legacy two-step on old backends)
-- 5) stronger invite codes (gen_random_bytes, no predictable WORD-NN)

-- 1) search_path pinning (prevents search_path hijack in definer fns)
create or replace function is_space_member(sid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.space_members
    where space_id = sid and user_id = auth.uid()
  );
$$;

create or replace function make_pair_code()
returns text language plpgsql security definer set search_path = public as $$
declare
  c text;
  tries int := 0;
begin
  loop
    -- 8 hex chars from a CSPRNG: ~4B combinations (was ~900 WORD-NN).
    c := upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 8));
    exit when not exists (select 1 from public.invite_codes where code = c);
    tries := tries + 1;
    if tries > 20 then raise exception 'code space exhausted'; end if;
  end loop;
  return c;
end;
$$;

create or replace function create_invite(sid uuid)
returns invite_codes language plpgsql security definer set search_path = public as $$
declare r invite_codes;
begin
  if not is_space_member(sid) then raise exception 'not a member'; end if;
  insert into invite_codes (code, space_id, created_by, expires_at)
  values (make_pair_code(), sid, auth.uid(), now() + interval '24 hours')
  returning * into r;
  return r;
end;
$$;

-- join_with_code keeps its body; just pin search_path (replace header only
-- if your m8 version differs, re-apply its full body with this header):
-- create or replace function join_with_code(p_code text)
-- returns uuid language plpgsql security definer set search_path = public as $$ ... $$;

-- 2) close self-insert bypass: direct inserts into space_members are now
-- denied; membership changes go through join_with_code / leave_space /
-- the auto-member trigger below.
drop policy if exists members_insert on space_members;
create policy members_insert on space_members for insert with check (false);

-- 3) spaces_update: keep membership check AND prevent created_by rewrite.
drop policy if exists spaces_update on spaces;
create policy spaces_update on spaces for update
  using (is_space_member(id))
  with check (
    is_space_member(id)
    and created_by = (select s.created_by from spaces s where s.id = spaces.id)
  );

-- 4a) atomic space creation (space + self-membership in one transaction).
create or replace function create_space(p_name text)
returns spaces language plpgsql security definer set search_path = public as $$
declare r spaces;
declare nm text := left(trim(coalesce(p_name, '')), 80);
begin
  if auth.uid() is null then raise exception 'log in first'; end if;
  if char_length(nm) < 1 then raise exception 'name required'; end if;
  insert into public.spaces (name, created_by)
  values (nm, auth.uid()) returning * into r;
  insert into public.space_members (space_id, user_id)
  values (r.id, auth.uid()) on conflict do nothing;
  return r;
end;
$$;
revoke all on function create_space(text) from public;
grant execute on function create_space(text) to authenticated;

-- 4b) atomic leave (member delete + empty-space cleanup server-side,
-- avoiding the check-then-delete race in the legacy client path).
create or replace function leave_space(sid uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.space_members
  where space_id = sid and user_id = auth.uid();
  delete from public.spaces s
  where s.id = sid
    and not exists (
      select 1 from public.space_members m where m.space_id = sid
    );
end;
$$;
revoke all on function leave_space(uuid) from public;
grant execute on function leave_space(uuid) to authenticated;

-- 4c) auto-member trigger: legacy direct spaces inserts (old clients)
-- still get a membership row instead of orphaning the space.
create or replace function auto_join_creator()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.space_members (space_id, user_id)
  values (new.id, new.created_by) on conflict do nothing;
  return new;
end;
$$;
drop trigger if exists spaces_auto_join on spaces;
create trigger spaces_auto_join
  after insert on spaces
  for each row execute function auto_join_creator();

-- 5) push webhook: never leave the secret literal in prosrc.
-- Move PUSH_WEBHOOK_SECRET into vault and revoke public execute:
--   select vault.create_secret('<random-32B>', 'push_webhook_secret');
--   revoke all on function notify_push() from public;
--   grant execute on function notify_push() to service_role;
-- Then read it inside notify_push() via
--   (select decrypted_secret from vault.decrypted_secrets
--    where name = 'push_webhook_secret')
-- NOTE: join rate-limiting (e.g. join_attempts table + >10/5min raise)
-- is recommended next but intentionally left out here to keep this
-- migration dependency-free.
