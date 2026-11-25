-- Only changes the minimum player count for Sauyn Show.
create or replace function public.sy_start(r uuid) returns void language plpgsql security definer set search_path='' as $$ begin
perform 1 from public.sy_rooms where id=r and owner=auth.uid() and starts_at is null and created_at>now()-interval '24 hours' for update; if not found then raise exception 'Cannot start'; end if;
if (select count(*) from public.sy_players where room=r)not between 2 and 4 then raise exception 'Need 2 to 4 players'; end if;
update public.sy_rooms set starts_at=clock_timestamp()+interval '3 seconds' where id=r; end $$;
