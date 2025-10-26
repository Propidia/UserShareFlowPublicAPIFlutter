import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// لإلغاء المتابعة من الـ UI (عند إغلاق الديالوغ مثلاً)
class CancelToken {
  bool _isCanceled = false;
  void cancel() => _isCanceled = true;
  bool get isCanceled => _isCanceled;
}

/// خدمة متابعة حالة المهام
class TaskStatusService {
  TaskStatusService._();
  static final TaskStatusService instance = TaskStatusService._();

  /// التحقق من حالة المهمة بشكل دوري
  /// يرجّع apply_id إذا نجحت المهمة
  /// يرمي Exception إذا فشلت
  /// يحاول عند أخطاء الشبكة بهدوء بدون إظهار عدّاد للمستخدم
  Future<int?> pollTaskStatus(
    String taskId, {
    String? accessToken,
    Duration pollInterval = const Duration(seconds: 1),
    Duration overallTimeout = const Duration(minutes: 2),
    Function(String)? onStatusUpdate,
    CancelToken? cancelToken,
  }) async {
    final startedAt = DateTime.now();

    bool _timeoutOrCanceled() =>
        (DateTime.now().difference(startedAt) >= overallTimeout) ||
        (cancelToken?.isCanceled == true);

    while (true) {
      if (_timeoutOrCanceled()) {
        throw Exception('انتهى وقت الانتظار. المهمة قد تحتاج وقتاً أطول.');
      }

      try {
        final response = await ApiClient.instance.checkTaskStatus(
          taskId,
          accessToken: accessToken,
        );

        final responseStr = response.trim();
        debugPrint('[TaskStatus] $responseStr');

        // نجاح: رقم > 0
        final applyId = int.tryParse(responseStr);
        if (applyId != null && applyId > 0) {
          onStatusUpdate?.call('✅ تم الإرسال بنجاح');
          return applyId;
        }

        // حالات الانتظار/الاصطفاف
        final s = responseStr.toLowerCase();
        final isPending = s.isEmpty ||
            s == 'null' ||
            s == 'none' ||
            s == 'queued' ||
            s == 'pending' ||
            s == 'in_progress' ||
            s == 'running' ||
            s == 'processing' ||
            s.contains('wait') ||
            s.contains('queue');

        if (isPending) {
          onStatusUpdate?.call('⏳ المهمة قيد التنفيذ...');
          await Future.delayed(pollInterval);
          continue;
        }

        // أي حالة أخرى تعتبر فشل منطقي من السيرفر
        throw Exception('خطأ في تنفيذ المهمة: $responseStr');
      } catch (e) {
        // لو كان فشل منطقي صريح من السيرفر -> نرميه مباشرة
        if (e.toString().contains('خطأ في تنفيذ المهمة')) {
          rethrow;
        }
        // أخطاء الشبكة: إعادة محاولة هادئة
        debugPrint('[TaskStatus] Connection error: $e');
        onStatusUpdate?.call('⚠️ خطأ في الاتصال... يُعاد المحاولة');
        await Future.delayed(pollInterval);
      }
    }
  }

  /// استخراج task_id أو correlation_id من استجابة submitForm
  String? extractTaskId(Map<String, dynamic> response) {
    // البحث عن task داخل details
    if (response.containsKey('details') && response['details'] is Map) {
      final details = (response['details'] as Map).cast<String, dynamic>();
      if (details.containsKey('task_id')) {
        final taskId = details['task_id'];
        return taskId?.toString();
      }
      // لو احتجت لاحقاً:
      // if (details.containsKey('correlation_id')) {
      //   return details['correlation_id']?.toString();
      // }
    }

    // على المستوى الأعلى
    if (response.containsKey('correlation_id')) {
      return response['correlation_id']?.toString();
    }
    if (response.containsKey('task_id')) {
      final taskId = response['task_id'];
      return taskId?.toString();
    }

    // نجاح فوري بدون task
    if (response.containsKey('apply_id')) {
      return null;
    }

    return null;
  }

  /// استخراج access_token من استجابة submitForm
  String? extractAccessToken(Map<String, dynamic> response) {
    if (response.containsKey('details') && response['details'] is Map) {
      final details = (response['details'] as Map).cast<String, dynamic>();
      if (details.containsKey('access_token')) {
        return details['access_token'] as String?;
      }
    }
    if (response.containsKey('access_token')) {
      return response['access_token'] as String?;
    }
    return null;
  }

  /// التحقق من حالة العملية بعد الإرسال
  Future<TaskResult> checkSubmissionStatus(
    Map<String, dynamic> response,
  ) async {
    // نجاح فوري
    if (response.containsKey('apply_id')) {
      final applyId = response['apply_id'];
      if (applyId is int && applyId > 0) {
        return TaskResult.success(applyId);
      }
    }

    // مهمة غير متزامنة
    final taskId = extractTaskId(response);
    if (taskId == null || taskId.isEmpty) {
      return TaskResult.error('لم يتم إرجاع task_id أو apply_id من السيرفر');
    }

    final accessToken = extractAccessToken(response);
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
