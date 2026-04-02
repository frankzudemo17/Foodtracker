// Self-destruct: unregister and clear all caches
self.addEventListener('install', function() { self.skipWaiting(); });
self.addEventListener('activate', function(e) {
  e.waitUntil(
    caches.keys().then(function(names) {
      return Promise.all(names.map(function(name) { return caches.delete(name); }));
    }).then(function() {
      return self.registration.unregister();
    })
  );
});
