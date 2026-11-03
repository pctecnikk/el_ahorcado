-- El ahorcado: jugadores, puntos y clasificación online.
-- Pega este script entero en Supabase → SQL Editor → New query, y pulsa Run.
-- Se puede ejecutar más de una vez sin problema.
--
-- Cómo funciona:
--   · Cada jugador puede crear un código secreto (por ejemplo AH-7K3Q-9XPA).
--   · Con ese código guarda y recupera su progreso desde cualquier dispositivo.
--   · Nadie puede leer ni tocar las tablas directamente: todo pasa por las
--     funciones de abajo, que solo devuelven lo necesario.
--   · El código se guarda cifrado (hash), nunca en claro.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.ah_players (
  id          bigint generated always as identity primary key,
  code_hash   text unique not null,
  name        text not null check (char_length(name) between 1 and 16),
  renames     integer not null default 0,
  points      integer not null default 0,
  medals      integer not null default 0,
  data        jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table public.ah_players add column if not exists medals integer not null default 0;
alter table public.ah_players enable row level security;
revoke all on table public.ah_players from anon, authenticated;

create or replace function public.ah_hash(p_code text)
returns text
language sql
immutable
set search_path = public, extensions
as $$
  select encode(digest('ah:' || upper(trim(coalesce(p_code, ''))), 'sha256'), 'hex')
$$;

create or replace function public.ah_new_code()
returns text
language plpgsql
set search_path = public, extensions
as $$
declare
  v_chars text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code  text := 'AH-';
  i       int;
begin
  for i in 1..8 loop
    v_code := v_code || substr(v_chars, 1 + (get_byte(gen_random_bytes(1), 0) % length(v_chars)), 1);
    if i = 4 then v_code := v_code || '-'; end if;
  end loop;
  return v_code;
end
$$;

-- Crea un jugador y devuelve su código secreto.
create or replace function public.ah_create(p_name text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code text;
  v_try  int := 0;
begin
  if p_name is null or char_length(trim(p_name)) < 1 or char_length(trim(p_name)) > 16 then
    raise exception 'Nombre no válido';
  end if;
  loop
    v_code := public.ah_new_code();
    begin
      insert into public.ah_players (code_hash, name) values (public.ah_hash(v_code), trim(p_name));
      return json_build_object('code', v_code);
    exception when unique_violation then
      v_try := v_try + 1;
      if v_try > 5 then raise; end if;
    end;
  end loop;
end
$$;

-- Guarda el progreso. El nombre solo se puede cambiar 2 veces.
-- (si existía una versión anterior sin medallas, se quita)
drop function if exists public.ah_save(text, text, integer, jsonb);
create or replace function public.ah_save(p_code text, p_name text, p_points integer, p_medals integer, p_data jsonb)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_old text;
  v_ren integer;
  v_new text;
  v_change boolean;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object' or pg_column_size(p_data) > 50000 then
    raise exception 'Datos no válidos';
  end if;
  select name, renames into v_old, v_ren from public.ah_players where code_hash = public.ah_hash(p_code);
  if not found then return false; end if;
  v_new := left(coalesce(nullif(trim(p_name), ''), v_old), 16);
  v_change := v_new <> v_old and v_ren < 2;
  update public.ah_players
     set name       = case when v_change then v_new else v_old end,
         renames    = renames + case when v_change then 1 else 0 end,
         points     = greatest(0, least(coalesce(p_points, 0), 10000000)),
         medals     = greatest(0, least(coalesce(p_medals, 0), 1000)),
         data       = p_data,
         updated_at = now()
   where code_hash = public.ah_hash(p_code);
  return true;
end
$$;

-- Recupera el progreso de un código.
create or replace function public.ah_load(p_code text)
returns json
language sql
stable
security definer
set search_path = public, extensions
as $$
  select json_build_object('name', name, 'renames', renames, 'points', points, 'medals', medals, 'data', data)
    from public.ah_players
   where code_hash = public.ah_hash(p_code)
$$;

-- Cambia el código por uno nuevo (el anterior deja de valer). Hace falta el actual.
create or replace function public.ah_regen(p_code text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code text;
  v_try  int := 0;
begin
  if not exists (select 1 from public.ah_players where code_hash = public.ah_hash(p_code)) then
    return null;
  end if;
  loop
    v_code := public.ah_new_code();
    begin
      update public.ah_players set code_hash = public.ah_hash(v_code), updated_at = now()
       where code_hash = public.ah_hash(p_code);
      return json_build_object('code', v_code);
    exception when unique_violation then
      v_try := v_try + 1;
      if v_try > 5 then raise; end if;
    end;
  end loop;
end
$$;

-- Borra para siempre al jugador que tenga ese código.
create or replace function public.ah_delete(p_code text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  delete from public.ah_players where code_hash = public.ah_hash(p_code);
  return found;
end
$$;

-- Clasificación mundial: solo nombre, puntos y medallas.
drop function if exists public.ah_top(integer);
create or replace function public.ah_top(p_limit integer default 20)
returns table (name text, points integer, medals integer)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select name, points, medals
    from public.ah_players
   where points > 0
   order by points desc, updated_at asc
   limit least(greatest(coalesce(p_limit, 20), 1), 50)
$$;

-- ===== Quién está jugando ahora (solo lo ve el dueño, desde el panel de Supabase) =====
create table if not exists public.ah_presence (
  session     text primary key check (char_length(session) between 8 and 40),
  name        text,
  place       text,
  has_code    boolean not null default false,
  first_seen  timestamptz not null default now(),
  last_seen   timestamptz not null default now()
);
alter table public.ah_presence enable row level security;
revoke all on table public.ah_presence from anon, authenticated;

create or replace function public.ah_ping(p_session text, p_name text, p_place text, p_code boolean)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if p_session is null or char_length(p_session) not between 8 and 40 then return; end if;
  insert into public.ah_presence (session, name, place, has_code)
  values (p_session, left(p_name, 16), left(p_place, 40), coalesce(p_code, false))
  on conflict (session) do update
     set name = excluded.name, place = excluded.place, has_code = excluded.has_code, last_seen = now();
  delete from public.ah_presence where last_seen < now() - interval '1 day';
end
$$;

create or replace view public.ahorcado_jugando_ahora as
  select coalesce(name, '(sin nombre)') as jugador,
         place                           as donde,
         has_code                        as tiene_codigo,
         first_seen                      as conectado_desde,
         last_seen                       as ultima_senal
    from public.ah_presence
   where last_seen > now() - interval '2 minutes'
   order by last_seen desc;
revoke all on public.ahorcado_jugando_ahora from anon, authenticated;

revoke all on function public.ah_new_code() from public, anon, authenticated;
revoke all on function public.ah_create(text) from public;
revoke all on function public.ah_save(text, text, integer, integer, jsonb) from public;
revoke all on function public.ah_load(text) from public;
revoke all on function public.ah_regen(text) from public;
revoke all on function public.ah_delete(text) from public;
revoke all on function public.ah_top(integer) from public;
revoke all on function public.ah_ping(text, text, text, boolean) from public;
grant execute on function public.ah_create(text) to anon, authenticated;
grant execute on function public.ah_save(text, text, integer, integer, jsonb) to anon, authenticated;
grant execute on function public.ah_load(text) to anon, authenticated;
grant execute on function public.ah_regen(text) to anon, authenticated;
grant execute on function public.ah_delete(text) to anon, authenticated;
grant execute on function public.ah_top(integer) to anon, authenticated;
grant execute on function public.ah_ping(text, text, text, boolean) to anon, authenticated;
