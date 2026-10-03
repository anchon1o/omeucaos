// O meu caos: función de avisos coa app pechada (Supabase Edge Function "rut-avisos")
// Segredos necesarios: VAPID_PUBLICA, VAPID_PRIVADA, AVISOS_SEGREDO (opcional: VAPID_CONTACTO)
import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
webpush.setVapidDetails(
  Deno.env.get("VAPID_CONTACTO") || "mailto:rutinas@example.com",
  Deno.env.get("VAPID_PUBLICA")!,
  Deno.env.get("VAPID_PRIVADA")!,
);

const VENTA = 3 * 60000; // marxe de 3 minutos por se o cron se atrasa
const mins = (h: string) => { const [a, b] = (h || "0:0").split(":").map(Number); return a * 60 + b; };

// Hora local do usuario expresada como "UTC inxenuo" para comparar sen zonas
function agora(zona: string) {
  const p = new Intl.DateTimeFormat("en-CA", { timeZone: zona, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).formatToParts(new Date());
  const g = (t: string) => p.find((x) => x.type === t)?.value || "0";
  const y = +g("year"), mo = +g("month"), d = +g("day"), h = +g("hour"), mi = +g("minute");
  return { iso: `${g("year")}-${g("month")}-${g("day")}`, min: h * 60 + mi, dow: new Date(Date.UTC(y, mo - 1, d)).getUTCDay(), naive: Date.UTC(y, mo - 1, d, h, mi) };
}
const naiveDe = (iso: string, hora: string) => {
  const [y, m, d] = iso.split("-").map(Number);
  const [h, mi] = (hora || "09:00").split(":").map(Number);
  return Date.UTC(y, m - 1, d, h, mi);
};
const sumarDias = (iso: string, n: number) => new Date(naiveDe(iso, "00:00") + n * 864e5).toISOString().slice(0, 10);
function semanaISO(iso: string) {
  const d = new Date(iso + "T00:00:00Z");
  const dn = d.getUTCDay() || 7; d.setUTCDate(d.getUTCDate() + 4 - dn);
  const y = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return `${d.getUTCFullYear()}-S${String(Math.ceil(((+d - +y) / 864e5 + 1) / 7)).padStart(2, "0")}`;
}
// Mesma regra ca na app: semana tipo + cambios dese día
function bloquesDaData(E: any, iso: string) {
  const d = new Date(iso + "T00:00:00Z").getUTCDay(), ex = E.excepcions?.[iso] || {};
  const canc = ex.canceladas || [], mod = ex.mod || {};
  return (E.bloques || []).filter((b: any) => b.dias.includes(d) && !canc.includes(b.id))
    .map((b: any) => (mod[b.id] ? { ...b, ...mod[b.id] } : b))
    .concat(ex.extra || []);
}

type Evento = { chave: string; titulo: string; corpo: string; url?: string };

function eventos(E: any): Evento[] {
  const ax = E.axustes || {}, ag = agora(ax.zona || "Europe/Madrid"), out: Evento[] = [];
  const toca = (n: number) => ag.naive >= n && ag.naive < n + VENTA;

  const antes = Number(ax.avisoBloque ?? 5);
  if (antes >= 0) for (const b of bloquesDaData(E, ag.iso)) {
    if (toca(naiveDe(ag.iso, b.ini) - antes * 60000))
      out.push({ chave: `b${b.id}${ag.iso}`, titulo: `${b.ini} ${b.titulo}`, corpo: antes ? `Comeza en ${antes} min` : "Comeza agora" });
  }

  for (const t of E.tarefas || []) {
    if (t.feita || !t.data || t.aviso === "" || t.aviso == null) continue;
    if (!toca(naiveDe(t.data, t.hora || "09:00") - Number(t.aviso) * 60000)) continue;
    const cando = t.data === ag.iso ? "Para hoxe" : t.data === sumarDias(ag.iso, 1) ? "Para mañá" : `Para o ${t.data.split("-").reverse().join("/")}`;
    out.push({ chave: `t${t.id}${t.data}${t.hora || ""}`, titulo: t.titulo, corpo: `${cando}${t.hora ? " ás " + t.hora : ""}` });
  }

  for (const h of ax.lembrarEstado || []) {
    const recente = (E.estados || []).some((x: any) => x.data === ag.iso && ag.min - mins(x.hora) >= 0 && ag.min - mins(x.hora) < 90);
    if (!recente && toca(naiveDe(ag.iso, h)))
      out.push({ chave: `e${h}${ag.iso}`, titulo: "Como estás agora?", corpo: "Rexistra a túa enerxía e o teu ánimo en dez segundos.", url: "./?accion=estado" });
  }

  if (ag.dow === 0 && !E.revisions?.[semanaISO(ag.iso)] && toca(naiveDe(ag.iso, "19:00")))
    out.push({ chave: `rev${ag.iso}`, titulo: "Revisión semanal", corpo: "Bo momento para pechar a semana e preparar a seguinte." });

  return out;
}

Deno.serve(async (req) => {
  if (req.headers.get("x-rut-segredo") !== Deno.env.get("AVISOS_SEGREDO")) return new Response("Non autorizado", { status: 401 });

  const { data: subs, error: e1 } = await sb.from("rut_subscricions").select("endpoint, user_id, sub");
  if (e1) return Response.json({ erro: e1.message }, { status: 500 });
  if (!subs?.length) return Response.json({ enviados: 0 });

  const ids = [...new Set(subs.map((s) => s.user_id))];
  const { data: filas, error: e2 } = await sb.from("rut_estado").select("user_id, datos").in("user_id", ids);
  if (e2) return Response.json({ erro: e2.message }, { status: 500 });

  let enviados = 0;
  for (const fila of filas || []) {
    for (const ev of eventos(fila.datos || {})) {
      const { error } = await sb.from("rut_avisos_enviados").insert({ user_id: fila.user_id, chave: ev.chave });
      if (error) continue; // xa se enviou antes
      for (const s of subs.filter((x) => x.user_id === fila.user_id)) {
        try {
          await webpush.sendNotification(s.sub, JSON.stringify({ titulo: ev.titulo, corpo: ev.corpo, tag: ev.chave, url: ev.url || "./" }));
          enviados++;
        } catch (e: any) {
          if (e?.statusCode === 404 || e?.statusCode === 410) await sb.from("rut_subscricions").delete().eq("endpoint", s.endpoint);
        }
      }
    }
  }

  if (new Date().getUTCMinutes() === 0)
    await sb.from("rut_avisos_enviados").delete().lt("enviado_en", new Date(Date.now() - 3 * 864e5).toISOString());

  return Response.json({ enviados });
});
