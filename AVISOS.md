# Avisos coa app pechada: configuración (unha soa vez)

1. **Táboas.** Executa `supabase.sql` no SQL Editor (crea `rut_subscricions` e `rut_avisos_enviados`; o resto xa o tes).
2. **Chaves.** Sube todo ao repositorio, abre `https://o-teu-dominio/xerar-chaves.html` e preme «Xerar chaves». Copia os tres valores. Despois borra `xerar-chaves.html` do repositorio.
3. **Chave pública na app.** En `index.html`, pon a chave pública en `CONFIG.vapid`.
4. **Función.** En Supabase: Edge Functions → Deploy a new function → Via Editor. Nome: `rut-avisos`. Pega o contido de `supabase/functions/rut-avisos/index.ts` e desprégaa.
   Nos axustes da función, **desactiva a verificación JWT** (a protección vai polo segredo propio).
5. **Segredos.** En Edge Functions → Secrets engade:
   - `VAPID_PUBLICA` = chave pública
   - `VAPID_PRIVADA` = chave privada
   - `AVISOS_SEGREDO` = segredo do cron
   - `VAPID_CONTACTO` = `mailto:o-teu-correo` (opcional)
6. **Cron.** Edita `avisos-cron.sql` (proxecto e segredo) e execútao no SQL Editor.
7. **En cada dispositivo.** Abre Rutinas (no iPhone/iPad, desde a icona da pantalla de inicio), vai a Axustes → «Avisos coa app pechada» → Activar.

Para comprobar que funciona: crea unha tarefa para dentro de 3 minutos con aviso «Á hora», pecha a app e agarda.
