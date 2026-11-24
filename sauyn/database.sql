-- Run in the existing Supabase project. Does not modify cs_* objects.
create extension if not exists pg_cron;
create table if not exists public.sy_rooms(id uuid primary key default gen_random_uuid(), owner uuid not null references auth.users(id) on delete cascade, created_at timestamptz not null default now(), starts_at timestamptz);
create table if not exists public.sy_players(id uuid primary key default gen_random_uuid(), room uuid not null references public.sy_rooms(id) on delete cascade, secret uuid not null, name text not null, slot int not null check(slot between 1 and 4), score int not null default 0, unique(room,slot), unique(room,secret));
alter table public.sy_rooms enable row level security;
alter table public.sy_players enable row level security;
revoke all on public.sy_rooms, public.sy_players from public, anon, authenticated;
create or replace function public.sy_new() returns uuid language plpgsql security definer set search_path='' as $$
declare r uuid; begin
if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Host login required'; end if;
perform pg_advisory_xact_lock(hashtextextended('sy:'||auth.uid()::text,0));
delete from public.sy_rooms where owner=auth.uid(); insert into public.sy_rooms(owner) values(auth.uid()) returning id into r; return r; end $$;
create or replace function public.sy_current() returns uuid language sql security definer set search_path='' as $$ select id from public.sy_rooms where owner=auth.uid() and created_at>now()-interval '24 hours' order by created_at desc limit 1 $$;
create or replace function public.sy_state(r uuid) returns jsonb language sql security definer set search_path='' as $$ select jsonb_build_object('start',s.starts_at,'now',clock_timestamp(),'players',coalesce((select jsonb_agg(jsonb_build_object('slot',p.slot,'name',p.name,'score',p.score) order by p.slot) from public.sy_players p where p.room=s.id),'[]'::jsonb)) from public.sy_rooms s where s.id=r and s.created_at>now()-interval '24 hours' $$;
create or replace function public.sy_join(r uuid,t uuid,n text) returns int language plpgsql security definer set search_path='' as $$ declare s timestamptz; k int; begin
select starts_at into s from public.sy_rooms where id=r and created_at>now()-interval '24 hours' for update; if not found then raise exception 'Room closed'; end if;
select slot into k from public.sy_players where room=r and secret=t; if found then return k; end if;
if s is not null then raise exception 'Game already started'; end if;
if t is null or n is null or char_length(trim(n)) not between 1 and 24 then raise exception 'Invalid name'; end if;
select i into k from generate_series(1,4) i where not exists(select 1 from public.sy_players where room=r and slot=i) order by i limit 1; if k is null then raise exception 'Room full'; end if;
insert into public.sy_players(room,secret,name,slot) values(r,t,trim(n),k); return k; end $$;
create or replace function public.sy_start(r uuid) returns void language plpgsql security definer set search_path='' as $$ begin
perform 1 from public.sy_rooms where id=r and owner=auth.uid() and starts_at is null and created_at>now()-interval '24 hours' for update; if not found then raise exception 'Cannot start'; end if;
if (select count(*) from public.sy_players where room=r)<>4 then raise exception 'Need four players'; end if;
update public.sy_rooms set starts_at=clock_timestamp()+interval '3 seconds' where id=r; end $$;
create or replace function public.sy_score(r uuid,t uuid,v int) returns int language plpgsql security definer set search_path='' as $$ declare s timestamptz; elapsed double precision; result int; begin
select starts_at into s from public.sy_rooms where id=r and created_at>now()-interval '24 hours'; if s is null then raise exception 'Not started'; end if;
elapsed=extract(epoch from clock_timestamp()-s); if elapsed<0 or elapsed>62 then raise exception 'Round closed'; end if;
update public.sy_players set score=greatest(score,least(greatest(v,0),floor(least(elapsed,60)*5)::int)) where room=r and secret=t returning score into result;
if not found then raise exception 'Unknown player'; end if; return result; end $$;
create or replace function public.sy_end(r uuid) returns void language sql security definer set search_path='' as $$ delete from public.sy_rooms where id=r and owner=auth.uid() $$;
revoke execute on function public.sy_new(),public.sy_current(),public.sy_state(uuid),public.sy_join(uuid,uuid,text),public.sy_start(uuid),public.sy_score(uuid,uuid,int),public.sy_end(uuid) from public,anon,authenticated;
grant execute on function public.sy_state(uuid),public.sy_join(uuid,uuid,text),public.sy_score(uuid,uuid,int) to anon,authenticated;
grant execute on function public.sy_new(),public.sy_current(),public.sy_start(uuid),public.sy_end(uuid) to authenticated;
select cron.schedule('sauyn-cleanup','* * * * *',$$delete from public.sy_rooms where created_at<=now()-interval '24 hours'$$);
