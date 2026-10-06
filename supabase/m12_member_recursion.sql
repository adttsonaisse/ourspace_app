-- M12 member-check recursion — run after schema.sql (+ m6–m11).
-- Fixes 54001 "stack depth limit exceeded" on everyday reads.
--
-- Root cause: is_space_member() queried space_members, while the
-- members_select policy itself called is_space_member() — policy
-- evaluation recursed into the function forever. It only surfaced
-- once the table held other users' rows (planner-dependent), which is
-- why pairing worked at first and then broke everywhere with generic
-- errors (mySpace/createSpace/createInvite/join all read membership).
--
-- Fix (standard Supabase pattern): SECURITY DEFINER so the check runs
-- as the function owner and bypasses RLS instead of recursing into it.
-- SET search_path pins name resolution (never trust the caller's path
-- inside a definer function).

create or replace function is_space_member(sid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from space_members
    where space_id = sid and user_id = auth.uid()
  );
$$;
