import 'package:get/get.dart';

enum ProcState { pending, success, error}

class ProcessingTask {
  final String name;
  final String path;
  final Rx<ProcState> state = ProcState.pending.obs;
  int? applyId;
  String? error;

  ProcessingTask({required this.name, required this.path});
}
class ProcessResult {
  final ProcState state;
  final int? applyId;
  final String? error;
  const ProcessResult(this.state, {this.applyId, this.error});
}
