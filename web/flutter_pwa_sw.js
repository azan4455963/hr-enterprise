// Minimal network-first service worker.
//
// Its only job is to make the app installable as a PWA (Chrome/Edge need a
// service worker with a fetch handler to show the "Install" option). It is
// deliberately NETWORK-FIRST and never pre-caches the build, so it can never
// serve a stale version after a deploy — every request goes to the network and
// the cache is used only as an offline fallback.

self.addEventListener('install', function (event) {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', function (event) {
  if (event.request.method !== 'GET') return;
  event.respondWith(
    fetch(event.request)
      .then(function (response) {
        // Keep a copy for offline fallback only.
        const copy = response.clone();
        caches.open('hr-runtime').then(function (cache) {
          cache.put(event.request, copy);
        }).catch(function () {});
        return response;
      })
      .catch(function () {
        return caches.match(event.request);
      })
  );
});
