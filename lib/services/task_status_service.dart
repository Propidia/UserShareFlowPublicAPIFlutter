import 'dart:async';
import 'api_client.dart';

/// خدمة متابعة حالة المهام
class TaskStatusService {
  TaskStatusService._();
  static final TaskStatusService instance = TaskStatusService._();

  /// التحقق من حالة المهمة بشكل دوري
  /// يرجع apply_id إذا نجحت المهمة
  /// يرمي Exception إذا فشلت
  /// يرجع null إذا كانت المهمة ما زالت قيد التنفيذ
  Future<int?> pollTaskStatus(
    String taskId, {
    String? accessToken,
    Duration pollInterval = const Duration(seconds: 2),
    int maxAttempts = 10, // 2 دقيقة كحد أقصى
    Function(String)? onStatusUpdate,
  }) async {
    int attempts = 0;

    while (attempts < maxAttempts) {
      attempts++;

      try {
        final response = await ApiClient.instance.checkTaskStatus(
          taskId,
          accessToken: accessToken,
        );
        final responseStr = response.trim();

        print('[TaskStatus] Attempt $attempts: $responseStr');

        // فحص إذا كانت قابلة للتحويل لرقم > 0 (نجاح)
        final applyId = int.tryParse(responseStr);
        if (applyId != null && applyId > 0) {
          onStatusUpdate?.call('✅ تم الإرسال بنجاح');
          return applyId;
        }

        // فحص إذا كانت حالة pending أو queued
        final lowerResponse = responseStr.toLowerCase();
        if (lowerResponse == 'null' ||
            lowerResponse == 'none' ||
            lowerResponse == 'queued' ||
            lowerResponse == 'pending' ||
            lowerResponse.isEmpty) {
          onStatusUpdate?.call(
            '⏳ المهمة قيد التنفيذ... (محاولة $attempts/$maxAttempts)',
          );
          await Future.delayed(pollInterval);
          continue;
        }

        // أي حالة أخرى تعتبر خطأ
        throw Exception('خطأ في تنفيذ المهمة: $responseStr');
      } catch (e) {
        if (e.toString().contains('خطأ في تنفيذ المهمة')) {
          // خطأ من السيرفر
          rethrow;
        }
        // خطأ في الاتصال - نحاول مرة أخرى
        print('[TaskStatus] Connection error: $e');
        onStatusUpdate?.call(
          '⚠️ خطأ في الاتصال... (محاولة $attempts/$maxAttempts)',
        );
        await Future.delayed(pollInterval);
      }
    }

    // انتهى الوقت
    throw Exception('انتهى وقت الانتظار. المهمة قد تحتاج وقتاً أطول.');
  }

  /// استخراج task_id أو correlation_id من استجابة submitForm
  String? extractTaskId(Map<String, dynamic> response) {
    // البحث عن correlation_id في details أولاً
    if (response.containsKey('details') && response['details'] is Map) {
      final details = response['details'] as Map<String, dynamic>;

      // if (details.containsKey('correlation_id')) {
      //   return details['correlation_id'] as String?;
      // }

      if (details.containsKey('task_id')) {
        final taskId = details['task_id'];
        return taskId?.toString();
      }
    }

    // البحث عن correlation_id على المستوى الأعلى
    if (response.containsKey('correlation_id')) {
      return response['correlation_id'] as String?;
    }

    // البحث عن task_id على المستوى الأعلى
    if (response.containsKey('task_id')) {
      final taskId = response['task_id'];
      return taskId?.toString();
    }

    // قد يكون apply_id مباشرة (بدون task)
    if (response.containsKey('apply_id')) {
      return null; // لا يوجد task، العملية تمت مباشرة
    }

    return null;
  }

  /// استخراج access_token من استجابة submitForm
  String? extractAccessToken(Map<String, dynamic> response) {
    // البحث عن access_token في details
    if (response.containsKey('details') && response['details'] is Map) {
      final details = response['details'] as Map<String, dynamic>;

      if (details.containsKey('access_token')) {
        return details['access_token'] as String?;
      }
    }

    // البحث عن access_token على المستوى الأعلى (احتياطي)
    if (response.containsKey('access_token')) {
      return response['access_token'] as String?;
    }

    return null;
  }

  /// التحقق من حالة العملية بعد الإرسال
  Future<TaskResult> checkSubmissionStatus(
    Map<String, dynamic> response,
  ) async {
    // فحص إذا كان هناك apply_id مباشرة (نجاح فوري)
    if (response.containsKey('apply_id')) {
      final applyId = response['apply_id'];
      if (applyId is int && applyId > 0) {
        return TaskResult.success(applyId);
      }
    }

    // فحص إذا كان هناك task_id أو correlation_id (عملية غير متزامنة)
    final taskId = extractTaskId(response);
    if (taskId == null || taskId.isEmpty) {
      // لا يوجد task_id ولا apply_id - خطأ
      return TaskResult.error('لم يتم إرجاع task_id أو apply_id من السيرفر');
    }

    // استخراج access_token للاستخدام في التحقق من الحالة
    final accessToken = extractAccessToken(response);

    // العملية قيد التنفيذ - نحتاج للمتابعة
    return TaskResult.pending(taskId, accessToken);
  }
}

/// نتيجة المهمة
class TaskResult {
  final TaskStatus status;
  final int? applyId;
  final String? taskId;
  final String? accessToken;
  final String? errorMessage;

  TaskResult._({
    required this.status,
    this.applyId,
    this.taskId,
    this.accessToken,
    this.errorMessage,
  });

  factory TaskResult.success(int applyId) {
    return TaskResult._(status: TaskStatus.success, applyId: applyId);
  }

  factory TaskResult.pending(String taskId, String? accessToken) {
    return TaskResult._(
      status: TaskStatus.pending,
      taskId: taskId,
      accessToken: accessToken,
    );
  }

  factory TaskResult.error(String message) {
    return TaskResult._(status: TaskStatus.error, errorMessage: message);
  }
}

enum TaskStatus { success, pending, error }
