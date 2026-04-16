// Aufgetischt — Network-First Service Worker
// Holt immer zuerst die aktuelle Version vom Server.
// Nur wenn offline: Fallback auf Cache. Verhindert dass
// die PWA alte Versionen festhält.
const CACHE = 'aufgetischt-v2';

self.addEventListener('install', function(e) {
  self.skipWaiting();
});

self.addEventListener('activate', function(e) {
  e.waitUntil(
    Promise.all([
      caches.keys().then(function(keys) {
        return Promise.all(keys.filter(function(k) { return k !== CACHE; })
                               .map(function(k) { return caches.delete(k); }));
      }),
      self.clients.claim()
    ])
  );
});

self.addEventListener('fetch', function(e) {
  if (e.request.method !== 'GET') return;
  var url = new URL(e.request.url);
  // Nur eigene Origin cachen — Supabase, OFF, CDNs bleiben direkt
  if (url.origin !== self.location.origin) return;

  e.respondWith(
    fetch(e.request).then(function(resp) {
      if (resp && resp.ok) {
        var copy = resp.clone();
        caches.open(CACHE).then(function(c) { c.put(e.request, copy); }).catch(function(){});
      }
      return resp;
    }).catch(function() {
      return caches.match(e.request).then(function(m) {
        return m || new Response('Offline', { status: 503, statusText: 'Offline' });
      });
    })
  );
});
