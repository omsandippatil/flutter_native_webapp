// flow_models.dart
// Dart representations of the flow JSON schema.
// FlowStep: one step in a flow — has a type (message, action, branch, activity).
// FlowMessage: a bot message with optional audioId and text content.
// FlowAction: a user-facing action (tap option, input text, proceed).
// FlowBranch: conditional next-step logic based on prior user input.
// AudioSlot: references a prerecorded audio asset by ID.
// All classes have fromJson constructors — no code generation needed.
