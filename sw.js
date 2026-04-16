// Self-destruct: unregister auf activate. Keine Fetch-Interception mehr.
// Damit verhaelt sich die PWA wie eine normale Webseite.
self.addEventListener('install', function() { self.skipWaiting(); });
self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(names) {
      return Promise.all(names.map(function(name) { return caches.delete(name); }));
    }).then(function() {
      return self.registration.unregister();
    }).then(function() {
      return self.clients.matchAll();
    }).then(function(clients) {
      clients.forEach(function(c) { try { c.navigate(c.url); } catch(e) {} });
    })
  );
});
