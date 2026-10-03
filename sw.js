// O meu caos: service worker (avisos coa app pechada e funcionamento sen conexión)
const CACHE = "omeucaos-v1";
const BASE = ["./", "./index.html", "./manifest.webmanifest", "./icona-192.png", "./apple-touch-icon.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(BASE)).catch(() => {}));
  self.skipWaiting();
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  // Páxina: primeiro a rede, se non hai conexión a copia gardada
  if (req.mode === "navigate"){
    e.respondWith(fetch(req).then(r => { const c = r.clone(); caches.open(CACHE).then(x => x.put("./index.html", c)); return r; })
      .catch(() => caches.match("./index.html")));
    return;
  }
  // Librarías e fontes: primeiro a copia gardada
  if (["cdn.jsdelivr.net", "fonts.googleapis.com", "fonts.gstatic.com"].includes(url.hostname)){
    e.respondWith(caches.match(req).then(m => m || fetch(req).then(r => { const c = r.clone(); caches.open(CACHE).then(x => x.put(req, c)); return r; })));
  }
});
self.addEventListener("push", e => {
  let d = {};
  try { d = e.data.json(); } catch { d = { titulo:"O meu caos", corpo: e.data ? e.data.text() : "" }; }
  e.waitUntil(self.registration.showNotification(d.titulo || "O meu caos", { body:d.corpo || "", tag:d.tag, data:{ url:d.url || "./" } }));
});
self.addEventListener("notificationclick", e => {
  e.notification.close();
  const destino = new URL(e.notification.data?.url || "./", self.registration.scope).href;
  e.waitUntil(clients.matchAll({ type:"window", includeUncontrolled:true }).then(lista => {
    for (const c of lista){ if ("navigate" in c && destino.includes("accion=")) return c.navigate(destino).then(w => w && w.focus()); if ("focus" in c) return c.focus(); }
    return clients.openWindow(destino);
  }));
});
