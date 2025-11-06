enum ProcessingStatus { Pending, Processing, Success, Empty, Error }

class ProcessingResult {
  final ProcessingStatus status;
  final int? applyId;
  final String? errorMessage;
  final String? taskId;
  final String? accessToken;
  final String? refreshToken;

  ProcessingResult(this.status, {this.applyId, this.errorMessage, this.taskId, this.accessToken, this.refreshToken});
}