-- M6 hardening — run after schema.sql + realtime.sql.
-- 1) Tighten spaces DELETE: members can only delete a space when they
--    are the last member left (leave() already does this; this blocks a
--    rogue client from nuking a 2-person space).
-- 2) Atomic join: advisory lock per code so two simultaneous joins
--    cannot both squeeze past the 2-member check.

drop policy if exists spaces_delete on spaces;
create policy spaces_delete on spaces for delete
  using (
    is_space_member(id)
    and not exists (
      select 1 from space_members m
      where m.space_id = id and m.user_id <> auth.uid()
    )
  );

create or replace function join_with_code(p_code text)
returns uuid language plpgsql security definer as $$
declare
  inv invite_codes;
  cnt int;
  code_norm text := upper(trim(p_code));
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
