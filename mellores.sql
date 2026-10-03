-- O meu caos: toques e listas compartidas (prefixo rut_).
-- Executa ANTES compartir.sql. Pódese executar varias veces.

-- 1. Os grupos poden ser rachas ou listas
alter table public.rut_grupos add column if not exists tipo text not null default 'racha';

-- 2. Crear grupo indicando o tipo (substitúe a función anterior)
drop function if exists public.rut_crear_grupo(text, int[], text);
create or replace function public.rut_crear_grupo(p_nome text, p_dias int[], p_alcume text, p_tipo text default 'racha') returns json
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_cod text;
begin
  if auth.uid() is null then raise exception 'Tes que entrar coa túa conta'; end if;
  if p_tipo not in ('racha', 'lista') then raise exception 'Tipo non válido'; end if;
  loop
    v_cod := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from rut_grupos g where g.codigo = v_cod);
  end loop;
  insert into rut_grupos (nome, dias, codigo, creado_por, tipo)
    values (trim(p_nome), coalesce(p_dias, '{0,1,2,3,4,5,6}'), v_cod, auth.uid(), p_tipo)
    returning rut_grupos.id into v_id;
  insert into rut_grupo_membros (grupo_id, user_id, alcume) values (v_id, auth.uid(), trim(p_alcume));
  return json_build_object('id', v_id, 'codigo', v_cod);
end $$;
revoke execute on function public.rut_crear_grupo(text, int[], text, text) from public, anon;
grant execute on function public.rut_crear_grupo(text, int[], text, text) to authenticated;

-- 3. Unirse devolve tamén o tipo
create or replace function public.rut_unirse(p_codigo text, p_alcume text) returns json
language plpgsql security definer set search_path = public as $$
declare v_g rut_grupos;
begin
  if auth.uid() is null then raise exception 'Tes que entrar coa túa conta'; end if;
  select * into v_g from rut_grupos where codigo = upper(trim(p_codigo));
  if not found then raise exception 'Non hai ningunha racha nin lista con ese código'; end if;
  if not exists (select 1 from rut_grupo_membros where grupo_id = v_g.id and user_id = auth.uid())
     and (select count(*) from rut_grupo_membros where grupo_id = v_g.id) >= 12 then
    raise exception 'Este grupo xa está completo (máximo 12 persoas)';
  end if;
  insert into rut_grupo_membros (grupo_id, user_id, alcume) values (v_g.id, auth.uid(), trim(p_alcume))
    on conflict (grupo_id, user_id) do update set alcume = excluded.alcume;
  return json_build_object('id', v_g.id, 'nome', v_g.nome, 'tipo', v_g.tipo);
end $$;

-- 4. Elementos das listas compartidas
create table if not exists public.rut_lista_items (
  id         uuid primary key default gen_random_uuid(),
  grupo_id   uuid not null references public.rut_grupos(id) on delete cascade,
  texto      text not null check (char_length(texto) between 1 and 200),
  feito      boolean not null default false,
  feito_por  uuid,
  creado_por uuid not null default auth.uid(),
  creado     timestamptz not null default now()
);
alter table public.rut_lista_items enable row level security;
drop policy if exists "rut_i_ler"     on public.rut_lista_items;
drop policy if exists "rut_i_crear"   on public.rut_lista_items;
drop policy if exists "rut_i_cambiar" on public.rut_lista_items;
drop policy if exists "rut_i_borrar"  on public.rut_lista_items;
create policy "rut_i_ler"     on public.rut_lista_items for select using (public.rut_son_membro(grupo_id));
create policy "rut_i_crear"   on public.rut_lista_items for insert with check (public.rut_son_membro(grupo_id) and creado_por = auth.uid());
create policy "rut_i_cambiar" on public.rut_lista_items for update using (public.rut_son_membro(grupo_id)) with check (public.rut_son_membro(grupo_id));
create policy "rut_i_borrar"  on public.rut_lista_items for delete using (public.rut_son_membro(grupo_id));

-- 5. Toques: ánimos e felicitacións (un por persoa e día en cada racha)
create table if not exists public.rut_toques (
  id       bigint generated always as identity primary key,
  grupo_id uuid not null references public.rut_grupos(id) on delete cascade,
  de       uuid not null references auth.users(id) on delete cascade,
  para     uuid not null references auth.users(id) on delete cascade,
  tipo     text not null check (tipo in ('animo', 'bravo')),
  data     date not null default current_date,
  creado   timestamptz not null default now(),
  enviado  boolean not null default false,
  unique (grupo_id, de, para, data)
);
alter table public.rut_toques enable row level security;
drop policy if exists "rut_t_ler"   on public.rut_toques;
drop policy if exists "rut_t_crear" on public.rut_toques;
create policy "rut_t_ler" on public.rut_toques for select using (de = auth.uid() or para = auth.uid());
create policy "rut_t_crear" on public.rut_toques for insert with check (
  de = auth.uid() and para <> auth.uid()
  and public.rut_son_membro(grupo_id)
  and exists (select 1 from public.rut_grupo_membros m where m.grupo_id = rut_toques.grupo_id and m.user_id = rut_toques.para)
);

-- 6. Tempo real para listas e toques
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'rut_lista_items') then
    alter publication supabase_realtime add table public.rut_lista_items;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'rut_toques') then
    alter publication supabase_realtime add table public.rut_toques;
  end if;
end $$;
