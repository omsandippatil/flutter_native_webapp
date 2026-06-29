// flow_service.dart
// The core flow engine — loads, parses, and steps through any flow by ID.
// loadFlow(flowId): checks Isar cache first, falls back to asset_loader, then caches forever.
// currentStep: the FlowStep at the current cursor position.
// advance(): moves cursor forward, handles branching by evaluating FlowBranch conditions.
// When a step has type "activity", delegates to activity_service.dart.
// When a step has type "audio", triggers audio_service.dart.
// Flow state (cursor position) lives in flow_provider — not in this service.
