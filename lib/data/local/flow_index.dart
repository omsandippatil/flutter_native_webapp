// flow_index.dart
// Loads assets/flows/flow_manifest.json and builds an in-memory ID → path map.
// Initialised once by flow_provider at startup.
// Provides: pathForFlowId(id), pathForAudioId(id), allFlowIds().
// If a requested ID is absent from the manifest, throws a descriptive error.
