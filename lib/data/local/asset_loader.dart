// asset_loader.dart
// Reads files from the Flutter asset bundle at runtime.
// loadJson(path): returns the decoded JSON map for a given asset path.
// loadAudioBytes(path): returns ByteData for an audio asset (for caching).
// All paths come from flow_resolver.dart — never hard-coded here.
// Wraps rootBundle.loadString and rootBundle.load with error handling.
