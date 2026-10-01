-- Ourspace cloud schema — run in Supabase dashboard > SQL editor.
-- Assumes: Auth email/password enabled. R2 (private) handled app-side.
-- Order: tables -> indexes -> RLS -> policies -> functions.

-- ---------- tables ----------
create table if not exists spaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists space_members (
  space_id uuid not null references spaces (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (space_id, user_id)
);

create table if not exists invite_codes (
  code text primary key,
  space_id uuid not null references spaces (id) on delete cascade,
  created_by uuid not null references auth.users (id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '24 hours'),
  used_count int not null default 0 check (used_count >= 0),
  max_uses int not null default 1 check (max_uses >= 1),
  created_at timestamptz not null default now()
);

create table if not exists notes (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces (id) on delete cascade,
  author_id uuid not null references auth.users (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  color_idx int not null default 0 check (color_idx between 0 and 4),
  pinned boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notes_space_idx on notes (space_id, created_at desc);

create table if not exists piles (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  location text not null default '',
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists piles_space_idx on piles (space_id, created_at desc);

create table if not exists pile_photos (
  id uuid primary key default gen_random_uuid(),
  pile_id uuid not null references piles (id) on delete cascade,
  r2_key text not null,
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists pile_photos_pile_idx on pile_photos (pile_id, created_at);

create table if not exists date_plans (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  note text not null default '',
  place text not null default '',
  day date not null,
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists dates_space_idx on date_plans (space_id, day);

create table if not exists rituals (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  color_idx int not null default 0 check (color_idx between 0 and 4),
  done boolean not null default false,
  sort int not null default 0,
  updated_at timestamptz not null default now()
);
create index if not exists rituals_space_idx on rituals (space_id, sort);

-- ---------- helpers ----------
create or replace function is_space_member(sid uuid)
returns boolean language sql stable as $$
  select exists (
    select 1 from space_members
    where space_id = sid and user_id = auth.uid()
  );
$$;

-- ---------- RLS ----------
alter table spaces enable row level security;
alter table space_members enable row level security;
alter table invite_codes enable row level security;
alter table notes enable row level security;
alter table piles enable row level security;
alter table pile_photos enable row level security;
alter table date_plans enable row level security;
alter table rituals enable row level security;

-- spaces: members read; any authed user can create; members update/delete
drop policy if exists spaces_select on spaces;
create policy spaces_select on spaces for select
  using (is_space_member(id));
drop policy if exists spaces_insert on spaces;
create policy spaces_insert on spaces for insert
  with check (auth.uid() = created_by);
drop policy if exists spaces_update on spaces;
create policy spaces_update on spaces for update
  using (is_space_member(id));
drop policy if exists spaces_delete on spaces;
create policy spaces_delete on spaces for delete
  using (
    is_space_member(id)
    and not exists (
      select 1 from space_members m
      where m.space_id = id and m.user_id <> auth.uid()
    )
  );

-- members: read own spaces; join inserts self; leave deletes self
drop policy if exists members_select on space_members;
create policy members_select on space_members for select
  using (user_id = auth.uid() or is_space_member(space_id));
drop policy if exists members_insert on space_members;
create policy members_insert on space_members for insert
  with check (user_id = auth.uid());
drop policy if exists members_delete on space_members;
create policy members_delete on space_members for delete
  using (user_id = auth.uid());

-- invites: members + creator read; members create
drop policy if exists invites_select on invite_codes;
create policy invites_select on invite_codes for select
  using (is_space_member(space_id) or created_by = auth.uid());
drop policy if exists invites_insert on invite_codes;
create policy invites_insert on invite_codes for insert
  with check (is_space_member(space_id) and created_by = auth.uid());

-- content: member-only full access per space
drop policy if exists notes_all on notes;
create policy notes_all on notes for all
  using (is_space_member(space_id))
  with check (is_space_member(space_id) and author_id = auth.uid());

drop policy if exists piles_all on piles;
create policy piles_all on piles for all
  using (is_space_member(space_id))
  with check (is_space_member(space_id) and created_by = auth.uid());

drop policy if exists photos_all on pile_photos;
create policy photos_all on pile_photos for all
  using (
    exists (
      select 1 from piles p
      where p.id = pile_photos.pile_id and is_space_member(p.space_id)
    )
  )
  with check (
    exists (
      select 1 from piles p
      where p.id = pile_photos.pile_id and is_space_member(p.space_id)
    ) and created_by = auth.uid()
  );

drop policy if exists dates_all on date_plans;
create policy dates_all on date_plans for all
  using (is_space_member(space_id))
  with check (is_space_member(space_id) and created_by = auth.uid());

drop policy if exists rituals_all on rituals;
create policy rituals_all on rituals for all
  using (is_space_member(space_id))
  with check (is_space_member(space_id));

-- ---------- invite code generator ----------
create or replace function make_pair_code()
returns text language plpgsql as $$
declare
  words text[] := array['MOCHI','PEACH','SUNNY','SKY','BUBBLE','MINT','BOBA','YUKI','PICO','LULU'];
  w text; n int; c text; tries int := 0;
begin
  loop
    w := words[1 + floor(random() * array_length(words, 1))::int];
    n := floor(random() * 90 + 10)::int;
    c := w || '-' || n::text;
    exit when not exists (select 1 from invite_codes where code = c);
    tries := tries + 1;
    if tries > 20 then raise exception 'code space exhausted'; end if;
  end loop;
  return c;
end;
$$;

-- Create invite for a space I belong to. Returns the code row.
create or replace function create_invite(sid uuid)
returns invite_codes language plpgsql security definer as $$
declare r invite_codes;
begin
  if not is_space_member(sid) then raise exception 'not a member'; end if;
  insert into invite_codes (code, space_id, created_by, expires_at)
  values (make_pair_code(), sid, auth.uid(), now() + interval '24 hours')
  returning * into r;
  return r;
end;
$$;

-- Join with code. Enforces: exists, not expired, not exhausted,
-- space has < 2 members, caller not already a member.
-- Returns the space id. SECURITY DEFINER so the member-count
-- check + insert + used_count bump happen atomically.
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
