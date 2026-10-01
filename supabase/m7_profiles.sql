-- M7 profiles — run after schema.sql + realtime.sql.
-- Gives the AppBar + settings card real initials (ours, not M/J).
-- Auth usernames live in auth.users metadata; clients cannot read
-- each other's auth rows, so mirror them here.

create table if not exists profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null default '' check (char_length(username) <= 40),
  updated_at timestamptz not null default now()
);

alter table profiles enable row level security;

-- Own row: full self access for ensureProfile upserts.
drop policy if exists profiles_self_select on profiles;
create policy profiles_self_select on profiles for select
  using (id = auth.uid());

drop policy if exists profiles_self_insert on profiles;
create policy profiles_self_insert on profiles for insert
  with check (id = auth.uid());

drop policy if exists profiles_self_update on profiles;
create policy profiles_self_update on profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- Pair read: members of the same space can see each other's names.
drop policy if exists profiles_pair_select on profiles;
create policy profiles_pair_select on profiles for select
  using (
    exists (
      select 1 from space_members m1
      join space_members m2 on m1.space_id = m2.space_id
      where m1.user_id = auth.uid() and m2.user_id = profiles.id
    )
  );

-- Auto-create profile on signup from user_metadata username,
-- fallback to email prefix so older clients still get an initial.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'username'), ''),
      split_part(new.email, '@', 1),
      'you'
    )
  )
  on conflict (id) do update set
    username = excluded.username,
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
