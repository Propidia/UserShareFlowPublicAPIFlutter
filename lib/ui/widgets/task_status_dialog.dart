import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/task_status_service.dart';

/// Dialog لعرض حالة تنفيذ المهمة
class TaskStatusDialog extends StatelessWidget {
  final String? taskId;
  final Future<int?> Function()? pollFunction;

  const TaskStatusDialog({Key? key, this.taskId, this.pollFunction})
    : super(key: key);

  /// عرض dialog مع متابعة حالة المهمة
  static Future<TaskStatusResult> show({
    required BuildContext context,
    required String taskId,
    String? accessToken,
  }) async {
    final statusController = TaskStatusDialogController(
      taskId: taskId,
      accessToken: accessToken,
    );

    // بدء المتابعة
    statusController.startPolling();

    final result = await showDialog<TaskStatusResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _TaskStatusDialogContent(controller: statusController),
    );

    // التأكد من إيقاف المتابعة
    statusController.dispose();

    return result ?? TaskStatusResult.cancelled();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Controller لإدارة حالة Dialog
class TaskStatusDialogController extends GetxController {
  final String taskId;
  final String? accessToken;
  final statusMessage = '⏳ جاري إرسال النموذج...'.obs;
  final isLoading = true.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;
  int? resultApplyId;

  TaskStatusDialogController({required this.taskId, this.accessToken});

  Future<void> startPolling() async {
    try {
      statusMessage.value = '⏳ جاري إرسال النموذج...';
      isLoading.value = true;
      hasError.value = false;

      final applyId = await TaskStatusService.instance.pollTaskStatus(
        taskId,
        accessToken: accessToken,
        onStatusUpdate: (message) {
          statusMessage.value = message;
        },
      );

      if (applyId != null && applyId > 0) {
        resultApplyId = applyId;
        statusMessage.value = '✅ تم إرسال النموذج بنجاح!';
        isLoading.value = false;
        hasError.value = false;

        // إغلاق تلقائي بعد ثانية
        await Future.delayed(const Duration(seconds: 1));
        Get.back(result: TaskStatusResult.success(applyId));
      }
    } catch (e) {
      print('[TaskStatusDialog] Error: $e');
      statusMessage.value = '❌ فشل الإرسال';
      errorMessage.value = e.toString();
      isLoading.value = false;
      hasError.value = true;
    }
  }

  void retry() {
    startPolling();
  }

  void cancel() {
    Get.back(result: TaskStatusResult.cancelled());
  }
}

/// محتوى Dialog
class _TaskStatusDialogContent extends StatelessWidget {
  final TaskStatusDialogController controller;

  const _TaskStatusDialogContent({Key? key, required this.controller})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return WillPopScope(
        onWillPop: () async => !controller.isLoading.value,
        child: AlertDialog(
          title: Text(
            controller.hasError.value ? 'خطأ في الإرسال' : 'حالة الإرسال',
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.isLoading.value) ...[
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 20),
              ] else if (controller.hasError.value) ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 20),
              ] else ...[
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 50,
                ),
                const SizedBox(height: 20),
              ],
              Text(
                controller.statusMessage.value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              if (controller.hasError.value &&
                  controller.errorMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (controller.hasError.value) ...[
              TextButton(
                onPressed: controller.cancel,
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: controller.retry,
                child: const Text('إعادة المحاولة'),
              ),
            ] else if (!controller.isLoading.value) ...[
              ElevatedButton(
                onPressed: () {
                  Get.back(
                    result: TaskStatusResult.success(controller.resultApplyId!),
                  );
                },
                child: const Text('موافق'),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// نتيجة Dialog
class TaskStatusResult {
  final TaskDialogStatus status;
  final int? applyId;

  TaskStatusResult._({required this.status, this.applyId});

  factory TaskStatusResult.success(int applyId) {
    return TaskStatusResult._(
      status: TaskDialogStatus.success,
      applyId: applyId,
    );
  }

  factory TaskStatusResult.cancelled() {
    return TaskStatusResult._(status: TaskDialogStatus.cancelled);
  }

  bool get isSuccess => status == TaskDialogStatus.success;
  bool get isCancelled => status == TaskDialogStatus.cancelled;
}

enum TaskDialogStatus { success, cancelled }
