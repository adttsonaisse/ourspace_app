-- v2.0.1: editable anniversary date per space.
-- Day counter uses this when set, else falls back to created_at.
alter table spaces
  add column if not exists anniversary_date date;
