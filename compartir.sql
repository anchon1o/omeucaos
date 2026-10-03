-- O meu caos: rachas compartidas (prefixo rut_).
-- Pega isto no SQL Editor de Supabase e executa. Pódese executar varias veces.

-- 1. Táboas
create table if not exists public.rut_grupos (
  id         uuid primary key default gen_random_uuid(),
  nome       text not null check (char_length(nome) between 1 and 80),
  dias       int[] not null default '{0,1,2,3,4,5,6}',
  codigo     text not null unique,
  creado_por uuid not null references auth.users(id) on delete cascade,
  creado     timestamptz not null default now()
);
create table if not exists public.rut_grupo_membros (
  grupo_id uuid not null references public.rut_grupos(id) on delete cascade,
  user_id  uuid not null references auth.users(id) on delete cascade,
  alcume   text not null check (char_length(alcume) between 1 and 30),
  unido    timestamptz not null default now(),
  primary key (grupo_id, user_id)
);
create table if not exists public.rut_grupo_marcas (
  grupo_id uuid not null,
  user_id  uuid not null,
  data     date not null,
  creada   timestamptz not null default now(),
  primary key (grupo_id, user_id, data),
  foreign key (grupo_id, user_id) references public.rut_grupo_membros(grupo_id, user_id) on delete cascade
);

-- 2. Saber se a persoa conectada pertence a un grupo
create or replace function public.rut_son_membro(g uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from rut_grupo_membros where grupo_id = g and user_id = auth.uid());
$$;

-- 3. Seguridade: cada quen só ve os grupos aos que pertence
alter table public.rut_grupos        enable row level security;
alter table public.rut_grupo_membros enable row level security;
alter table public.rut_grupo_marcas  enable row level security;

drop policy if exists "rut_g_ler"     on public.rut_grupos;
drop policy if exists "rut_g_cambiar" on public.rut_grupos;
drop policy if exists "rut_g_borrar"  on public.rut_grupos;
create policy "rut_g_ler"     on public.rut_grupos for select using (public.rut_son_membro(id));
create policy "rut_g_cambiar" on public.rut_grupos for update using (creado_por = auth.uid()) with check (creado_por = auth.uid());
create policy "rut_g_borrar"  on public.rut_grupos for delete using (creado_por = auth.uid());

drop policy if exists "rut_m_ler"     on public.rut_grupo_membros;
drop policy if exists "rut_m_cambiar" on public.rut_grupo_membros;
drop policy if exists "rut_m_sair"    on public.rut_grupo_membros;
create policy "rut_m_ler"     on public.rut_grupo_membros for select using (public.rut_son_membro(grupo_id));
create policy "rut_m_cambiar" on public.rut_grupo_membros for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "rut_m_sair"    on public.rut_grupo_membros for delete using (user_id = auth.uid());

drop policy if exists "rut_k_ler"     on public.rut_grupo_marcas;
drop policy if exists "rut_k_marcar"  on public.rut_grupo_marcas;
drop policy if exists "rut_k_borrar"  on public.rut_grupo_marcas;
create policy "rut_k_ler"    on public.rut_grupo_marcas for select using (public.rut_son_membro(grupo_id));
create policy "rut_k_marcar" on public.rut_grupo_marcas for insert
  with check (user_id = auth.uid() and public.rut_son_membro(grupo_id) and data between current_date - 14 and current_date + 1);
create policy "rut_k_borrar" on public.rut_grupo_marcas for delete using (user_id = auth.uid());

-- 4. Crear unha racha (xera o código e mete a quen a crea)
create or replace function public.rut_crear_grupo(p_nome text, p_dias int[], p_alcume text) returns json
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_cod text;
begin
  if auth.uid() is null then raise exception 'Tes que entrar coa túa conta'; end if;
  loop
    v_cod := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from rut_grupos g where g.codigo = v_cod);
  end loop;
  insert into rut_grupos (nome, dias, codigo, creado_por)
    values (trim(p_nome), coalesce(p_dias, '{0,1,2,3,4,5,6}'), v_cod, auth.uid())
    returning rut_grupos.id into v_id;
  insert into rut_grupo_membros (grupo_id, user_id, alcume) values (v_id, auth.uid(), trim(p_alcume));
  return json_build_object('id', v_id, 'codigo', v_cod);
end $$;

-- 5. Unirse cun código
create or replace function public.rut_unirse(p_codigo text, p_alcume text) returns json
language plpgsql security definer set search_path = public as $$
declare v_g rut_grupos;
begin
  if auth.uid() is null then raise exception 'Tes que entrar coa túa conta'; end if;
  select * into v_g from rut_grupos where codigo = upper(trim(p_codigo));
  if not found then raise exception 'Non hai ningunha racha con ese código'; end if;
  if not exists (select 1 from rut_grupo_membros where grupo_id = v_g.id and user_id = auth.uid())
     and (select count(*) from rut_grupo_membros where grupo_id = v_g.id) >= 12 then
    raise exception 'Este grupo xa está completo (máximo 12 persoas)';
  end if;
  insert into rut_grupo_membros (grupo_id, user_id, alcume) values (v_g.id, auth.uid(), trim(p_alcume))
    on conflict (grupo_id, user_id) do update set alcume = excluded.alcume;
  return json_build_object('id', v_g.id, 'nome', v_g.nome);
end $$;

revoke execute on function public.rut_crear_grupo(text, int[], text) from public, anon;
revoke execute on function public.rut_unirse(text, text) from public, anon;
grant execute on function public.rut_crear_grupo(text, int[], text) to authenticated;
grant execute on function public.rut_unirse(text, text) to authenticated;

-- 6. Tempo real: ver ao momento cando alguén do grupo marca
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'rut_grupo_marcas') then
    alter publication supabase_realtime add table public.rut_grupo_marcas;
  end if;
end $$;
