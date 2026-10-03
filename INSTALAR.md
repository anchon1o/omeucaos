# Instalar O meu caos

## 1. Supabase
1. Usa o proxecto que prefiras (as táboas levan o prefixo `rut_`, así que conviven co resto).
2. SQL Editor → pega `supabase.sql` → Run. Despois, nunha consulta nova, `compartir.sql` → Run, e noutra, `mellores.sql` → Run (rachas, listas e ánimos compartidos).
3. Authentication → URL Configuration → **Site URL**: pon a dirección de Vercel (paso 3). Así o correo de confirmación da conta leva á app.
   Se non queres confirmar por correo: Authentication → Providers → Email → desactiva «Confirm email».
4. Project Settings → API: copia a **Project URL** e a chave **anon / publishable**.

## 2. A app
En `index.html`, ao principio do script, enche:
```js
const CONFIG = {
  url: "https://XXXX.supabase.co",
  chave: "a túa chave anon",
  vapid: ""   // déixao baleiro ata configurar os avisos
};
```

## 3. GitHub e Vercel
1. Crea un repositorio `rutinas` e sube todos os ficheiros desta carpeta.
2. En Vercel: Add New → Project → importa o repositorio. Framework: **Other**. Sen comando de build. Deploy.
3. Volve ao paso 1.3 e pon a dirección que che deu Vercel.

## 4. No móbil e no ordenador
- Abre a dirección, crea a conta e entra. Nos outros dispositivos, entra coa mesma conta.
- **iPhone / iPad (Safari):** Compartir → «Engadir á pantalla de inicio».
- **Android (Chrome):** menú ⋮ → «Instalar aplicación».

## 5. Avisos coa app pechada (opcional)
Cando xa funcione todo, segue `AVISOS.md`.

## 6. Calendario do móbil (opcional)
1. Supabase → Edge Functions → Deploy a new function → Via Editor. Nome: `rut-calendario`.
2. Pega o contido de `supabase/functions/rut-calendario/index.ts` e desprégaa.
3. Nos axustes da función, desactiva a verificación JWT.
4. Na app: Axustes → «Ver no calendario do móbil» → Crear a ligazón.
