-- Realtime enablement for watch() streams — run after schema.sql.
-- Without this, StreamBuilder tabs stay on the spinner on real backend.

alter publication supabase_realtime add table notes;
alter publication supabase_realtime add table piles;
alter publication supabase_realtime add table pile_photos;
alter publication supabase_realtime add table date_plans;
alter publication supabase_realtime add table rituals;
alter publication supabase_realtime add table space_members;
