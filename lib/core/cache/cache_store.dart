// cache_store.dart
// Isar-backed cache that works on both Flutter web and native apps.
// Exposes generic get/set/delete/clear methods used by all services.
// Isar web uses IndexedDB under the hood — same API, same code.
// All cached data is stored with a key string and a JSON-serialised value.
// Cache is lazy: data is written on first fetch and never re-fetched
// unless explicitly invalidated. See cache_ttls.dart for expiry rules.
