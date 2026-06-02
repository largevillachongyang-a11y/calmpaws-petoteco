'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "4d284f6c1d7d168f02ec4fd303e5ceda",
"index.html": "7b79c1d255186714f23ceb2945fa6d19",
"/": "7b79c1d255186714f23ceb2945fa6d19",
"main.dart.js": "b953dcfe84fac141f15610131c055d2a",
"version.json": "6834bd9dff9df06ce75206e56126c0d6",
"assets/assets/icons/app_icon.png": "a91eb61a3ef566b301dde3ac64b465f5",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/fonts/MaterialIcons-Regular.otf": "4e8387e8ec07a2d2d73a1359efbb90d6",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.json": "de3d7b674b765bc11bf09826c34da118",
"assets/AssetManifest.bin": "020703847b40593280b940c56dc832d4",
"assets/AssetManifest.bin.json": "3ed0d2218b53c4ea843b245fb1d7b294",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/NOTICES": "f20b5da79be45fe5b4c7775fb64a6e96",
"favicon.png": "990b81e15d64b923ab6920e2341163af",
"icons/Icon-192.png": "36e0c4fb79464bb43be626b198bf49b4",
"icons/Icon-512.png": "db376b3160679b7a7793b7ccf6cc094f",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"manifest.json": "23a558966cfbdf3eecd533655f017536",
".git/hooks/applypatch-msg.sample": "ce562e08d8098926a3862fc6e7905199",
".git/hooks/commit-msg.sample": "579a3c1e12a1e74a98169175fb913012",
".git/hooks/fsmonitor-watchman.sample": "a0b2633a2c8e97501610bd3f73da66fc",
".git/hooks/post-update.sample": "2b7ea5cee3c49ff53d41e00785eb974c",
".git/hooks/pre-applypatch.sample": "054f9ffb8bfe04a599751cc757226dda",
".git/hooks/pre-commit.sample": "305eadbbcd6f6d2567e033ad12aabbc4",
".git/hooks/pre-merge-commit.sample": "39cb268e2a85d436b9eb6f47614c3cbc",
".git/hooks/pre-push.sample": "2c642152299a94e05ea26eae11993b13",
".git/hooks/pre-rebase.sample": "56e45f2bcbc8226d2b4200f7c46371bf",
".git/hooks/pre-receive.sample": "2ad18ec82c20af7b5926ed9cea6aeedd",
".git/hooks/prepare-commit-msg.sample": "2b5c047bdb474555e1787db32b2d2fc5",
".git/hooks/push-to-checkout.sample": "c7ab00c7784efeadad3ae9b228d4b4db",
".git/hooks/update.sample": "647ae13c682f7827c22f5fc08a03674e",
".git/info/exclude": "036208b4a1ab4a235d75c181e685e5a3",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/refs/heads/gh-pages": "a80ab846929ab5d502e560ec255c224c",
".git/refs/remotes/origin/gh-pages": "a80ab846929ab5d502e560ec255c224c",
".git/objects/43/c9596589876eec062fae7c012d66709cc4e187": "ce9d3bbfc3dddca9f4e554c1a3e6e5ac",
".git/objects/a2/348d017a7fc24ace66d0732ad9ee37610d651d": "fc13b02ce4a257b0c6a3738986e1a914",
".git/objects/56/3203617a8fa86903a40c015107605c09850902": "3b65c4eb6fa51f74656168f4af201f49",
".git/objects/b5/4c81980090d4272249a7fda04d0b594437e574": "1a6463951dad10df6d6092abd07e426a",
".git/objects/46/4ab5882a2234c39b1a4dbad5feba0954478155": "2e52a767dc04391de7b4d0beb32e7fc4",
".git/objects/77/e44ac5fcd01364631fcd8f600376725a177dd0": "12c647afd85cdbc8847a301dd9833b48",
".git/objects/ff/42c64a2c51de38aa28c4a2b29abdaa7743bc79": "19b82da934c96aa30b8c1679d289b5be",
".git/objects/e6/9de29bb2d1d6434b8b29ae775ad8c2e48c5391": "c70c34cbeefd40e7c0149b7a0c2c64c2",
".git/objects/c7/39755074c56028bac2c9292b915c14a796d523": "8c0957a478d60decfa715ed18f1f4787",
".git/objects/e9/94225c71c957162e2dcc06abe8295e482f93a2": "2eed33506ed70a5848a0b06f5b754f2c",
".git/objects/d4/3532a2348cc9c26053ddb5802f0e5d4b8abc05": "3dad9b209346b1723bb2cc68e7e42a44",
".git/objects/7a/6c1911dddaea52e2dbffc15e45e428ec9a9915": "f1dee6885dc6f71f357a8e825bda0286",
".git/objects/98/0d49437042d93ffa850a60d02cef584a35a85c": "8e18e4c1b6c83800103ff097cc222444",
".git/objects/4d/bf9da7bcce5387354fe394985b98ebae39df43": "534c022f4a0845274cbd61ff6c9c9c33",
".git/objects/b6/b8806f5f9d33389d53c2868e6ea1aca7445229": "b14016efdbcda10804235f3a45562bbf",
".git/objects/9b/3ef5f169177a64f91eafe11e52b58c60db3df2": "91d370e4f73d42e0a622f3e44af9e7b1",
".git/objects/29/f22f56f0c9903bf90b2a78ef505b36d89a9725": "e85914d97d264694217ae7558d414e81",
".git/objects/ca/3bba02c77c467ef18cffe2d4c857e003ad6d5d": "316e3d817e75cf7b1fd9b0226c088a43",
".git/objects/c4/016f7d68c0d70816a0c784867168ffa8f419e1": "fdf8b8a8484741e7a3a558ed9d22f21d",
".git/objects/ed/b55d4deb8363b6afa65df71d1f9fd8c7787f22": "886ebb77561ff26a755e09883903891d",
".git/objects/20/3a3ff5cc524ede7e585dff54454bd63a1b0f36": "4b23a88a964550066839c18c1b5c461e",
".git/objects/9e/3b4630b3b8461ff43c272714e00bb47942263e": "accf36d08c0545fa02199021e5902d52",
".git/objects/4f/fbe6ec4693664cb4ff395edf3d949bd4607391": "2beb9ca6c799e0ff64e0ad79f9e55e69",
".git/objects/27/459392ecfcc316f4a46c35e4f5c351d449df4d": "ed47a254799f22f14502c1f42884ef2a",
".git/objects/fe/3b987e61ed346808d9aa023ce3073530ad7426": "dc7db10bf25046b27091222383ede515",
".git/objects/13/b89f10bb3474ec48e82a69ecf8d46d4270add8": "35c411d9c4563acdf2758201382b43d0",
".git/objects/2b/fded8f5033645b85b7b760d2d2e7fa8f98d70a": "287b01387175a1f8cd3c43c5ba36c357",
".git/objects/ba/5e13d4ebb289ccecba65cc8900818aef878ac4": "17ed98adbea27192cadd5e6129392d1a",
".git/objects/7b/6ecf3a5968180603d472f416762c5e33d93412": "baf972845cdc117626022135058d7c3f",
".git/objects/eb/9b4d76e525556d5d89141648c724331630325d": "37c0954235cbe27c4d93e74fe9a578ef",
".git/objects/d6/9c56691fbdb0b7efa65097c7cc1edac12a6d3e": "868ce37a3a78b0606713733248a2f579",
".git/objects/cb/84b74fc2f49703831cfbea29071f458a824db8": "4245c140f22eee6bee7d13d357fc14f7",
".git/objects/38/9cf75739bccd91cddf40d385b83e4e718c1f00": "785c26b9fbdc4e87e89b60107d4097a2",
".git/objects/36/7284a217b644510301fb56fd7a162330031561": "a7f48f61918145a6693600cc05d080e7",
".git/objects/ea/af0982c0fa10c1b16cddbf0b07b068170a330e": "d306abd289afc891d9e7e48a01565997",
".git/objects/ec/ea727448f29c858e69657b641b8798f76ae5d1": "26117e83d03be20449d0011594fbfbbc",
".git/objects/d5/64d0bc3dd917926892c55e3706cc116d5b165e": "ab5f20dcd5b558888db7d80b0f979f8a",
".git/objects/04/cad685fbb38d8539a61b95eca10b39652c3d1c": "867043d7639b25f3c2ce6a84a9fd8572",
".git/objects/a5/10fe701b3eb127bdb6c2d57b3c925428cdeeb0": "1af11f9126049c7b356e02db0d490667",
".git/objects/6b/9862a1351012dc0f337c9ee5067ed3dbfbb439": "85896cd5fba127825eb58df13dfac82b",
".git/objects/f5/72b90ef57ee79b82dd846c6871359a7cb10404": "e68f5265f0bb82d792ff536dcb99d803",
".git/objects/d7/7cfefdbe249b8bf90ce8244ed8fc1732fe8f73": "9c0876641083076714600718b0dab097",
".git/objects/f2/04823a42f2d890f945f70d88b8e2d921c6ae26": "6b47f314ffc35cf6a1ced3208ecc857d",
".git/objects/2c/af982ac019adb3adce990050e4a7caf8dc483d": "567b391030f7536fe3cbbb9354b4b790",
".git/objects/e3/e9ee754c75ae07cc3d19f9b8c1e656cc4946a1": "14066365125dcce5aec8eb1454f0d127",
".git/objects/02/1d4f3579879a4ac147edbbd8ac2d91e2bc7323": "9e9721befbee4797263ad5370cd904ff",
".git/objects/e2/bd4f4415585de6b449ba8b992d7d0d64af93ec": "0b83350df2c8a18ece5c8b98cf41fbae",
".git/objects/89/5cad31a7a12643ccf5356cfe94f70caa02ec84": "2c4350155e8b4738865ce21e776fe4ba",
".git/objects/8f/9bc9dfb5df31dec2c1926c7a4c2ec3243759e0": "342f00699228efe107ae339bc0e205c4",
".git/HEAD": "5ab7a4355e4c959b0c5c008f202f51ec",
".git/config": "f775322557e3e4279a839d2c2ae48203",
".git/index": "bdca93be0956024f46be3186cb582946",
".git/COMMIT_EDITMSG": "5cb2bef1afeced2d5f233b7d7d722852",
".git/logs/HEAD": "a6328d40baeb7ff5429175dfc480ceb8",
".git/logs/refs/heads/gh-pages": "a6328d40baeb7ff5429175dfc480ceb8",
".git/logs/refs/remotes/origin/gh-pages": "f857f082da2f6b551cc204138b3e2d1a",
"cat_training_v3_clean.zip": "1a74b2f21cfef96214141eed85692b3e",
"cat_data_extractor_v3.py": "6e798eda142faed15c4a891a66242297",
"cat_data_extractor_v4.py": "270d465f9ea7c0f8fcb3a3069e83013f",
"cat_data_extractor_v4_1.py": "46b6d182b2f9af2b913be3769d74b6be",
"PROJECT_STATUS.md": "1ae0eda1d0af442a69df55d20829f758",
"cat_data_extractor_v4_2.py": "d6325ad3930e4982bba93dbcd24e4aef",
"rename_v4_2.py": "df1713293fcd418e43017c6bf59f195b",
"cat_data_extractor_v4_3.py": "51e6b929649432588df40a8a0096f340",
"augment_pacing.py": "4fcc5187c63c83a8379be12e1c8ff17d",
"balance_dataset.py": "c2558ec1b232e07cc341cb8da5caa8ae",
"CalmPaws_%E4%B8%83%E5%A4%A7%E7%8A%B6%E6%80%81%E6%8A%80%E6%9C%AF%E8%AF%B4%E6%98%8E_%E7%8C%AB_v1.0.md": "62738860f060a67dc2da6bc3eb6eab9f",
"WORK_LOG_2025.md": "bb34cc0073627788eedbb412ae13c057",
"output/calmpaws_firmware_plan.html": "c340b5593aaf93a1f21cf67bac513a65"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
