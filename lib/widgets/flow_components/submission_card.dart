// submission_card.dart
// Renders a submission prompt inside the chat for activity submission slots.
// Slot config determines type: text, image, or text+image.
// Text: a multi-line input field with a submit button.
// Image: a camera/gallery picker (web uses file input, native uses image_picker).
// On submit: calls activity_provider.submitSlot(submissionData).
// After submission: card becomes read-only, shows a "Submitted ✓" confirmation.
