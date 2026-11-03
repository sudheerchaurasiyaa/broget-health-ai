const CACHE = 'broget-public-v2';
const PUBLIC = ['/manifest.json', '/icons/Icon-192.png', '/icons/Icon-512.png', '/branding/brogetai_full_logo.png'];
self.addEventListener('install', event => event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(PUBLIC))));
self.addEventListener('activate', event => event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))));
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  // Private requests and authenticated application HTML are never cached.
  if (url.origin !== self.location.origin || !PUBLIC.includes(url.pathname) || event.request.method !== 'GET') return;
  event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request)));
});
