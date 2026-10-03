-- O meu caos: executa a función de avisos cada minuto.
-- Antes de executar, cambia TEU-PROXECTO e O_TEU_SEGREDO (o mesmo que AVISOS_SEGREDO).

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.unschedule('rut-avisos') where exists (select 1 from cron.job where jobname = 'rut-avisos');

select cron.schedule('rut-avisos', '* * * * *', $$
  select net.http_post(
    url     := 'https://TEU-PROXECTO.supabase.co/functions/v1/rut-avisos',
    headers := '{"Content-Type":"application/json","x-rut-segredo":"O_TEU_SEGREDO"}'::jsonb,
    body    := '{}'::jsonb
  );
$$);
