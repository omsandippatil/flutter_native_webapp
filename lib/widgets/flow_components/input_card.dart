// input_card.dart
// Renders a structured input form as a chat card — used in onboarding flows.
// Supports: single text field, numeric field, date picker.
// Field type and label come from the flow step's input_config.
// On submit: validates input, calls flow_provider.advance(inputValue).
// After submission: field becomes read-only, value echoed as user message.
