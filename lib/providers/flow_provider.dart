// flow_provider.dart
// Riverpod StateNotifier — drives the active flow execution.
// startFlow(flowId): loads the flow via flow_service, resets cursor, starts stepping.
// currentStep: exposes the FlowStep at the cursor for the chat screen to render.
// advance(userInput): records user input, evaluates branches, moves to next step.
// When step type is "activity": delegates to activity_provider and awaits completion.
// When flow is complete: notifies progress_provider to save, returns to home.
