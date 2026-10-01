-- M8 numeric invite codes — run after schema.sql (+ m6/m7).
-- Codes are now 6 random digits (e.g. 482916): easy to read aloud.
-- NOTE: WORD-NN codes issued before this migration stop working
-- (all expire within 24h anyway).

create or replace function make_pair_code()
returns text language plpgsql as $$
declare
  c text; tries int := 0;
begin
  loop
    c := (floor(random() * 900000 + 100000)::int)::text;
    exit when not exists (select 1 from invite_codes where code = c);
    tries := tries + 1;
    if tries > 20 then raise exception 'code space exhausted'; end if;
  end loop;
  return c;
end;
$$;

-- Same atomic join as m6, but forgiving: strips spaces/dashes so
-- "482 916" and "482-916" both match "482916".
create or replace function join_with_code(p_code text)
returns uuid language plpgsql security definer as $$
declare
  inv invite_codes;
  cnt int;
  code_norm text := regexp_replace(upper(trim(p_code)), '[^A-Z0-9]', '', 'g');
begin
  -- Serialize joins per code: count + insert + bump happen atomically.
  perform pg_advisory_xact_lock(hashtext('join:' || code_norm));

  select * into inv from invite_codes where code = code_norm;
  if not found then raise exception 'code not found'; end if;
  if inv.expires_at < now() then raise exception 'code expired'; end if;
  if inv.used_count >= inv.max_uses then raise exception 'code used'; end if;
  if exists (select 1 from space_members
             where space_id = inv.space_id and user_id = auth.uid()) then
    return inv.space_id;
  end if;
  select count(*) into cnt from space_members where space_id = inv.space_id;
  if cnt >= 2 then raise exception 'space is full'; end if;
  insert into space_members (space_id, user_id) values (inv.space_id, auth.uid());
  update invite_codes set used_count = used_count + 1 where code = inv.code;
  return inv.space_id;
end;
$$;
