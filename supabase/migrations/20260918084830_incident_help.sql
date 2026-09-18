create table public.incident_help_requests (
 id uuid primary key default gen_random_uuid(),
 incident_id uuid not null references public.incidents(id) on delete cascade,
 actor_key text not null,
 account_id uuid references auth.users(id),
 guest_session_id uuid references public.external_force_sessions(id),
 sender_label text not null,
 message text not null default '' check(length(message)<=160),
 lat double precision, lng double precision,
 created_at timestamptz not null default now(),
 cleared_at timestamptz,
 unique(incident_id,actor_key),
 check((account_id is null)<>(guest_session_id is null))
);
alter table public.incident_help_requests enable row level security;
revoke all on public.incident_help_requests from anon,authenticated;
grant select on public.incident_help_requests to authenticated;
create policy help_read on public.incident_help_requests for select to authenticated
using(public.firemap_operational_account_active() and public.firemap_can_view_incident(incident_id));

create function firemap_private.help_actor(p_incident uuid,p_token text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.external_force_sessions%rowtype; a public.firemap_accounts%rowtype;v public.vehicles%rowtype;i public.incidents%rowtype;
begin
 select * into i from public.incidents where id=p_incident and active;
 if not found then raise exception 'Zdarzenie nieaktywne';end if;
 if p_token is not null then
  s:=firemap_private.guest_session(p_token);
  if s.incident_id<>p_incident then raise exception 'Brak dostępu do zdarzenia';end if;
  select * into v from public.vehicles where id=s.vehicle_id and external_session_id=s.id;
  return jsonb_build_object('key','g:'||s.id,'guest',s.id,'label',coalesce(v.call_sign,'Zastęp QR')||' · '||coalesce(v.unit_name,''),'lat',v.lat,'lng',v.lng);
 end if;
 select * into a from public.firemap_accounts where user_id=auth.uid() and enabled;
 if not found or not public.firemap_can_view_incident(p_incident) then raise exception 'Brak dostępu do zdarzenia';end if;
 select * into v from public.vehicles where account_id=a.user_id and incident_id=p_incident and status<>'BASE' order by updated_at desc limit 1;
 if v.id is null and not public.firemap_can_manage_incident(p_incident) then raise exception 'Najpierw przypisz zastęp do zdarzenia';end if;
 return jsonb_build_object('key','a:'||a.user_id,'account',a.user_id,'label',coalesce(v.call_sign,a.role)||' · '||a.unit_name,'lat',coalesce(v.lat,i.lat),'lng',coalesce(v.lng,i.lng));
end $$;
revoke all on function firemap_private.help_actor(uuid,text) from public,anon,authenticated;

create function public.firemap_help_raise(p_incident_id uuid,p_message text default '',p_session_token text default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare a jsonb;rid uuid;
begin
 perform 1 from public.incidents where id=p_incident_id and active for share;
 if not found then raise exception 'Zdarzenie nieaktywne';end if;
 a:=firemap_private.help_actor(p_incident_id,p_session_token);
 if p_message is null or length(p_message)>160 then raise exception 'Maksymalnie 160 znaków';end if;
 insert into public.incident_help_requests(incident_id,actor_key,account_id,guest_session_id,sender_label,message,lat,lng)
 values(p_incident_id,a->>'key',(a->>'account')::uuid,(a->>'guest')::uuid,a->>'label',p_message,(a->>'lat')::float8,(a->>'lng')::float8)
 on conflict(incident_id,actor_key) do update set cleared_at=null,message=excluded.message,sender_label=excluded.sender_label,lat=excluded.lat,lng=excluded.lng,
 created_at=case when public.incident_help_requests.cleared_at is null then public.incident_help_requests.created_at else now() end
 returning id into rid;
 return rid;
end $$;

create function public.firemap_help_read(p_session_token text default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare s public.external_force_sessions%rowtype;out_rows jsonb;uid uuid;
begin
 if p_session_token is not null then s:=firemap_private.guest_session(p_session_token);
 else
  uid:=auth.uid();if public.firemap_operational_account_active() is not true then raise exception 'Brak aktywnego konta';end if;
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',h.id,'incident_id',h.incident_id,'incident_description',i.description,'sender_label',h.sender_label,'message',h.message,'lat',h.lat,'lng',h.lng,'created_at',h.created_at,'can_clear',case when p_session_token is not null then h.guest_session_id=s.id else h.account_id=uid or public.firemap_can_manage_incident(h.incident_id) end) order by h.created_at),'[]') into out_rows
 from public.incident_help_requests h join public.incidents i on i.id=h.incident_id and i.active
 where h.cleared_at is null and case when p_session_token is not null then h.incident_id=s.incident_id else public.firemap_can_view_incident(h.incident_id) end;
 return out_rows;
end $$;

create function public.firemap_help_clear(p_request_id uuid,p_session_token text default null) returns boolean
language plpgsql security definer set search_path='' as $$
declare h public.incident_help_requests%rowtype;s public.external_force_sessions%rowtype;allowed boolean:=false;
begin
 select * into h from public.incident_help_requests where id=p_request_id for update;
 if not found then raise exception 'Brak zgłoszenia';end if;
 if p_session_token is not null then
  s:=firemap_private.guest_session(p_session_token);allowed:=s.id=h.guest_session_id and s.incident_id=h.incident_id;
 else
  allowed:=public.firemap_operational_account_active() and public.firemap_can_view_incident(h.incident_id) and (h.account_id=auth.uid() or public.firemap_can_manage_incident(h.incident_id));
 end if;
 if allowed is not true then raise exception 'Nie możesz odwołać tego zgłoszenia';end if;
 update public.incident_help_requests set cleared_at=coalesce(cleared_at,now()) where id=h.id;
 return true;
end $$;
revoke all on function public.firemap_help_raise(uuid,text,text),public.firemap_help_read(text),public.firemap_help_clear(uuid,text) from public;
grant execute on function public.firemap_help_raise(uuid,text,text),public.firemap_help_read(text),public.firemap_help_clear(uuid,text) to anon,authenticated;
