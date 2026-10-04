-- M9 creator can read own space — run after schema.sql (+ m6/m7/m8).
-- Fixes new-user pairing bootstrap: the app creates a space with
-- insert+select in ONE roundtrip, but spaces_select used to require an
-- existing space_members row (which is only inserted afterwards), so the
-- chained select returned 0 rows and pairing failed with a generic error.
-- Creator-read is safe: a space starts with exactly one member (its creator).

drop policy if exists spaces_select on spaces;
create policy spaces_select on spaces for select
  using (is_space_member(id) or created_by = auth.uid());
