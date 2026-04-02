const CACHE_NAME = 'aufgetischt-v3';
const ASSETS = [
  './',
  './index.html',
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/apple-touch-icon.png'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE_NAME).then(c => c.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(names =>
      Promise.all(names.filter(n => n !== CACHE_NAME).map(n => caches.delete(n)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  // Don't intercept API/CDN calls — let them go straight to network
  if (e.request.url.includes('openfoodfacts.org') || 
      e.request.url.includes('supabase.co') ||
      e.request.url.includes('anthropic.com') ||
      e.request.url.includes('cdn.jsdelivr.net') ||
      e.request.url.includes('unpkg.com')) {
    return;
  }
  // Network first, fallback to cache for app assets only
  e.respondWith(
    fetch(e.request).then(resp => {
      if (resp && resp.status === 200) {
        const clone = resp.clone();
        caches.open(CACHE_NAME).then(c => c.put(e.request, clone));
      }
      return resp;
    }).catch(() => caches.match(e.request))
  );
});
