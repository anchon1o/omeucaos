# Instalar Rutinas

## 1. Supabase
1. Usa o proxecto que prefiras (as táboas levan o prefixo `rut_`, así que conviven co resto).
2. SQL Editor → pega `supabase.sql` → Run.
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
