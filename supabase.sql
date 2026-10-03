-- O meu caos: táboas (prefixo rut_). Pega isto no SQL Editor de Supabase e executa.
-- Pódese executar varias veces sen problema.

-- 1. Os teus datos
create table if not exists public.rut_estado (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  datos       jsonb not null default '{}'::jsonb,
  actualizado timestamptz not null default now()
);
alter table public.rut_estado enable row level security;
drop policy if exists "rut_ler_o_meu"     on public.rut_estado;
drop policy if exists "rut_crear_o_meu"   on public.rut_estado;
drop policy if exists "rut_cambiar_o_meu" on public.rut_estado;
drop policy if exists "rut_borrar_o_meu"  on public.rut_estado;
create policy "rut_ler_o_meu"     on public.rut_estado for select using (auth.uid() = user_id);
create policy "rut_crear_o_meu"   on public.rut_estado for insert with check (auth.uid() = user_id);
create policy "rut_cambiar_o_meu" on public.rut_estado for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "rut_borrar_o_meu"  on public.rut_estado for delete using (auth.uid() = user_id);

-- 2. Dispositivos que reciben avisos coa app pechada
create table if not exists public.rut_subscricions (
  endpoint    text primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  sub         jsonb not null,
  dispositivo text,
  creada      timestamptz not null default now()
);
alter table public.rut_subscricions enable row level security;
drop policy if exists "rut_sub_ler"     on public.rut_subscricions;
drop policy if exists "rut_sub_crear"   on public.rut_subscricions;
drop policy if exists "rut_sub_cambiar" on public.rut_subscricions;
drop policy if exists "rut_sub_borrar"  on public.rut_subscricions;
create policy "rut_sub_ler"     on public.rut_subscricions for select using (auth.uid() = user_id);
create policy "rut_sub_crear"   on public.rut_subscricions for insert with check (auth.uid() = user_id);
create policy "rut_sub_cambiar" on public.rut_subscricions for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "rut_sub_borrar"  on public.rut_subscricions for delete using (auth.uid() = user_id);

-- 3. Rexistro de avisos xa enviados (para non repetilos). Só o usa a función.
create table if not exists public.rut_avisos_enviados (
  user_id    uuid not null,
  chave      text not null,
  enviado_en timestamptz not null default now(),
  primary key (user_id, chave)
);
alter table public.rut_avisos_enviados enable row level security;
