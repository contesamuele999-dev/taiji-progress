const C = 'taiji-progress-v22';
const ASSETS = ['./index.html', './test-camera-recognition.html', './riferimento-forma18.json', './manifest.webmanifest', './icon.svg'];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(C).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== C).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request;
  let url;
  try { url = new URL(req.url); } catch (_) { return; }
  // Non interferire con le richieste esterne (Supabase, font, CDN): vanno sempre in rete.
  if (url.origin !== location.origin) return;
  // HTML/navigazione: prima la rete (così gli aggiornamenti si vedono subito), cache di riserva offline.
  if (req.mode === 'navigate' || url.pathname.endsWith('/') || url.pathname.endsWith('index.html')) {
    e.respondWith(
      fetch(req).then(r => { const cp = r.clone(); caches.open(C).then(c => c.put(req, cp)); return r; })
                .catch(() => caches.match(req).then(r => r || caches.match('./index.html')))
    );
    return;
  }
  // Altri asset locali (incluse le immagini delle figure): cache, poi rete; salva in cache per l'offline.
  e.respondWith(caches.match(req).then(r => r || fetch(req).then(rr => {
    if (rr && rr.ok && req.method === 'GET') { const cp = rr.clone(); caches.open(C).then(c => c.put(req, cp)); }
    return rr;
  })));
});
