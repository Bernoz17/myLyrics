-- myLyrics: one independent row shared by app + widget through Supabase.
-- Run in Supabase Dashboard -> SQL Editor.

create table if not exists public.mylyrics_widget_state (
  id bigint primary key check (id = 1),
  phrase_id bigint not null default 0,
  testo text not null default '',
  titolo text not null default '',
  artista text not null default '',
  bg_color text not null default '000000',
  text_color text not null default 'FFFFFF',
  font_style text not null default 'default',
  updated_at timestamptz not null default now()
);

alter table public.mylyrics_widget_state enable row level security;

grant select, insert, update on public.mylyrics_widget_state to anon;

drop policy if exists "myLyrics anon can read state" on public.mylyrics_widget_state;
create policy "myLyrics anon can read state"
on public.mylyrics_widget_state
for select to anon
using (id = 1);

drop policy if exists "myLyrics anon can insert state" on public.mylyrics_widget_state;
create policy "myLyrics anon can insert state"
on public.mylyrics_widget_state
for insert to anon
with check (id = 1);

drop policy if exists "myLyrics anon can update state" on public.mylyrics_widget_state;
create policy "myLyrics anon can update state"
on public.mylyrics_widget_state
for update to anon
using (id = 1)
with check (id = 1);

insert into public.mylyrics_widget_state (id)
values (1)
on conflict (id) do nothing;
