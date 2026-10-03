// O meu caos: calendario subscrito (Supabase Edge Function "rut-calendario")
// Devolve os bloques e as tarefas en formato iCalendar para Google, Apple ou Outlook.
// Acceso: ?t=TOKEN (o token créase en Axustes da app). Desactiva a verificación JWT.
import { createClient } from "npm:@supabase/supabase-js@2";

const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

const pad = (n: number) => String(n).padStart(2, "0");
const sumarDias = (iso: string, n: number) => {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d) + n * 864e5).toISOString().slice(0, 10);
};
const hoxeEn = (zona: string) => {
  const p = new Intl.DateTimeFormat("en-CA", { timeZone: zona, year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(new Date());
  const g = (t: string) => p.find((x) => x.type === t)?.value;
  return `${g("year")}-${g("month")}-${g("day")}`;
};
function bloquesDaData(E: any, iso: string) {
  const d = new Date(iso + "T00:00:00Z").getUTCDay(), ex = E.excepcions?.[iso] || {};
  const canc = ex.canceladas || [], mod = ex.mod || {};
  return (E.bloques || []).filter((b: any) => b.dias.includes(d) && !canc.includes(b.id))
    .map((b: any) => (mod[b.id] ? { ...b, ...mod[b.id] } : b))
    .concat(ex.extra || []);
}
const txt = (s: string) => String(s || "").replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\r?\n/g, "\\n");
const dt = (iso: string, hora: string) => `${iso.replace(/-/g, "")}T${hora.replace(":", "")}00`;
function dobrar(l: string) {
  const b = new TextEncoder().encode(l);
  if (b.length <= 74) return l;
  const out: string[] = []; let actual = "";
  for (const ch of l) {
    if (new TextEncoder().encode(actual + ch).length > (out.length ? 73 : 74)) { out.push(actual); actual = ""; }
    actual += ch;
  }
  out.push(actual);
  return out.join("\r\n ");
}

Deno.serve(async (req) => {
  const t = new URL(req.url).searchParams.get("t") || "";
  if (t.length < 20) return new Response("Non atopado", { status: 404 });
  const { data } = await sb.from("rut_estado").select("datos").eq("datos->axustes->>icsToken", t).maybeSingle();
  if (!data) return new Response("Non atopado", { status: 404 });

  const E = data.datos || {}, zona = E.axustes?.zona || "Europe/Madrid";
  const cats = Object.fromEntries((E.categorias || []).map((c: any) => [c.id, c.nome]));
  const stamp = new Date().toISOString().replace(/[-:]/g, "").slice(0, 15) + "Z";
  const hoxe = hoxeEn(zona);
  const L = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//O meu caos//GL", "CALSCALE:GREGORIAN", "METHOD:PUBLISH",
    "X-WR-CALNAME:O meu caos", `X-WR-TIMEZONE:${zona}`, "REFRESH-INTERVAL;VALUE=DURATION:PT1H", "X-PUBLISHED-TTL:PT1H"];

  for (let i = -7; i <= 45; i++) {
    const iso = sumarDias(hoxe, i);
    for (const b of bloquesDaData(E, iso)) {
      L.push("BEGIN:VEVENT", `UID:b-${b.id}-${iso}@omeucaos`, `DTSTAMP:${stamp}`,
        `DTSTART;TZID=${zona}:${dt(iso, b.ini)}`, `DTEND;TZID=${zona}:${dt(iso, b.fin)}`,
        `SUMMARY:${txt(b.titulo)}`);
      if (cats[b.cat]) L.push(`CATEGORIES:${txt(cats[b.cat])}`);
      if (b.notas) L.push(`DESCRIPTION:${txt(b.notas)}`);
      L.push("END:VEVENT");
    }
  }
  const desde = sumarDias(hoxe, -7), ata = sumarDias(hoxe, 90);
  for (const tr of E.tarefas || []) {
    if (tr.feita || !tr.data || tr.data < desde || tr.data > ata) continue;
    L.push("BEGIN:VEVENT", `UID:t-${tr.id}-${tr.data}@omeucaos`, `DTSTAMP:${stamp}`, `SUMMARY:${txt("Tarefa: " + tr.titulo)}`);
    if (tr.hora) {
      const [h, m] = tr.hora.split(":").map(Number), fin = Math.min(h * 60 + m + 30, 23 * 60 + 59);
      L.push(`DTSTART;TZID=${zona}:${dt(tr.data, tr.hora)}`, `DTEND;TZID=${zona}:${dt(tr.data, `${pad(Math.floor(fin / 60))}:${pad(fin % 60)}`)}`);
    } else {
      L.push(`DTSTART;VALUE=DATE:${tr.data.replace(/-/g, "")}`, `DTEND;VALUE=DATE:${sumarDias(tr.data, 1).replace(/-/g, "")}`, "TRANSP:TRANSPARENT");
    }
    if (tr.notas) L.push(`DESCRIPTION:${txt(tr.notas)}`);
    L.push("END:VEVENT");
  }
  L.push("END:VCALENDAR");

  return new Response(L.map(dobrar).join("\r\n") + "\r\n", {
    headers: { "Content-Type": "text/calendar; charset=utf-8", "Cache-Control": "max-age=600", "Access-Control-Allow-Origin": "*" },
  });
});
