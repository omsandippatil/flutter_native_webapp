enum ChatAction {
  watchVideo,
  startQuiz,
  submitAnswer,
  continueFlow,
  retrySubmission,
  retrySave,
  finishUnit,
  watchAnother,
  maybeLater,
  openHome,
  editProfile,
  enrollCourse,
  saveProfile,
  completeOnboarding,
  aiCall,
  submitFreeText,
}

class ChatActionResult {
  const ChatActionResult({
    required this.success,
    this.errorMessage,
    this.payload,
  });

  final bool success;
  final String? errorMessage;
  final Map<String, Object?>? payload;

  factory ChatActionResult.ok({Map<String, Object?>? payload}) =>
      ChatActionResult(success: true, payload: payload);

  factory ChatActionResult.failure(String message) =>
      ChatActionResult(success: false, errorMessage: message);
}

abstract class ChatActionHandler {
  Future<ChatActionResult> handle(
    ChatAction action, {
    Map<String, Object?>? data,
  });
}