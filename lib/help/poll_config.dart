
class _PollConfig {
  final Duration grace;
  final Duration pollInterval;
  final Duration perAttemptTimeout;
  _PollConfig(this.grace, this.pollInterval, this.perAttemptTimeout);
}

_PollConfig pollConfigForSizeBytes(int bytes) {
  const mb = 1024 * 1024;
  if (bytes < 10 * mb) {
    // صغير: 5s window
    return _PollConfig(const Duration(seconds: 5), const Duration(seconds: 1), const Duration(seconds: 2));
  } else if (bytes < 100 * mb) {
    // متوسط: 30s
    return _PollConfig(const Duration(seconds: 30), const Duration(seconds: 2), const Duration(seconds: 4));
  } else if (bytes < 500 * mb) {
    // كبير: 2 minutes
    return _PollConfig(const Duration(minutes: 2), const Duration(seconds: 3), const Duration(seconds: 6));
  } else {
    // جداً كبير: 5 minutes
    return _PollConfig(const Duration(minutes: 5), const Duration(seconds: 4), const Duration(seconds: 10));
  }
}
