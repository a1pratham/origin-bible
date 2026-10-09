-- Origin Bible: cloud sync schema.
-- Run ONCE in Supabase Dashboard > SQL Editor (it is safe to re-run).
-- Every rule here protects the free tier and the user's privacy.

-- One table for all synced items (bookmarks, highlights, notes, progress):
-- fewer requests and a single set of security rules.
create table if not exists public.sync_items (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  kind text not null
    check (kind in ('bookmark', 'highlight', 'note', 'progress')),
  id text not null check (char_length(id) between 1 and 40),
  book_code text not null check (char_length(book_code) = 3),
  chapter integer not null check (chapter between 1 and 150),
  verse integer not null check (verse between 0 and 200),
  color text
    check (color is null or color in ('yellow', 'green', 'blue', 'pink')),
  body text check (body is null or char_length(body) <= 10000),
  client_updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default clock_timestamp(),
  primary key (user_id, kind, id)
);

-- Used by the app's incremental pull ("what changed since last time?").
create index if not exists sync_items_pull_idx
  on public.sync_items (user_id, server_updated_at);

-- ---------------------------------------------------------------------------
-- Row Level Security: a user can only ever read or write their own rows.
-- There is deliberately NO delete policy: items are soft-deleted, and account
-- deletion removes everything through the cascade above.
-- ---------------------------------------------------------------------------
alter table public.sync_items enable row level security;

drop policy if exists sync_items_select_own on public.sync_items;
create policy sync_items_select_own on public.sync_items
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists sync_items_insert_own on public.sync_items;
create policy sync_items_insert_own on public.sync_items
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists sync_items_update_own on public.sync_items;
create policy sync_items_update_own on public.sync_items
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.sync_items from anon;

-- ---------------------------------------------------------------------------
-- Guard trigger:
--  * last write wins: an upload that is not newer than the stored row is
--    ignored (protects against a stale device overwriting newer data)
--  * per-user cap of 20,000 items (protects the 500 MB free database)
--  * server_updated_at is always set by the server, never by the client
-- ---------------------------------------------------------------------------
create or replace function public.sync_items_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.client_updated_at <= old.client_updated_at then
      return null;
    end if;
  elsif tg_op = 'INSERT' then
    if not exists (
      select 1 from public.sync_items s
      where s.user_id = new.user_id and s.kind = new.kind and s.id = new.id
    ) and (
      select count(*) from public.sync_items s where s.user_id = new.user_id
    ) >= 20000 then
      raise exception 'Sync limit reached (20000 items)' using errcode = 'P0001';
    end if;
  end if;
  new.server_updated_at := clock_timestamp();
  return new;
end;
$$;

drop trigger if exists sync_items_guard_trg on public.sync_items;
create trigger sync_items_guard_trg
  before insert or update on public.sync_items
  for each row execute function public.sync_items_guard();

-- ---------------------------------------------------------------------------
-- Account deletion: the app calls rpc('delete_my_account'). Deleting the auth
-- user cascades to all of that user's sync_items.
-- ---------------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ---------------------------------------------------------------------------
-- Optional housekeeping (not scheduled automatically): removes soft-deleted
-- items older than N days. Run it by hand from the SQL editor now and then,
-- or schedule it later. Not callable by app users.
-- ---------------------------------------------------------------------------
create or replace function public.purge_old_deleted_items(days integer default 90)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  removed integer;
begin
  delete from public.sync_items
  where deleted_at is not null
    and deleted_at < now() - make_interval(days => days);
  get diagnostics removed = row_count;
  return removed;
end;
$$;

revoke all on function public.purge_old_deleted_items(integer)
  from public, anon, authenticated;
