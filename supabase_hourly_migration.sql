-- myLyrics hourly phrase migration.
-- Run this once in Supabase SQL Editor.
-- It keeps your existing table/data and only adds the hour_key column.

alter table public.mylyrics_widget_state
  add column if not exists hour_key text not null default '';

create index if not exists mylyrics_widget_state_hour_key_idx
  on public.mylyrics_widget_state(hour_key);

-- Keep the existing singleton row if present.
insert into public.mylyrics_widget_state (id)
values (1)
on conflict (id) do nothing;
