import 'dart:async';
import 'dart:convert';

import 'package:useshareflowpublicapiflutter/services/api_client.dart';

enum SubmissionStatus { success, pending, error }

class SubmissionCheckResult {
  final SubmissionStatus status;
  final int? applyId;
  final String? taskId;
  final String? accessToken;
  final String? errorMessage;

  const SubmissionCheckResult._({
    required this.status,
    this.applyId,
    this.taskId,
    this.accessToken,
    this.errorMessage,
  });

  factory SubmissionCheckResult.success(int applyId) =>
      SubmissionCheckResult._(status: SubmissionStatus.success, applyId: applyId);

  factory SubmissionCheckResult.pending(String taskId, String? accessToken) =>
      SubmissionCheckResult._(
        status: SubmissionStatus.pending,
        taskId: taskId,
        accessToken: accessToken,
      );

  factory SubmissionCheckResult.error(String message) =>
      SubmissionCheckResult._(status: SubmissionStatus.error, errorMessage: message);
}

class SubmissionService {
  const SubmissionService._();

  /// Convert a heterogeneous API value to a flat map
  static Map<String, dynamic>? asValueMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  /// Count how many controls contain files entries
  static int countUploadedFiles(dynamic controls) {
    if (controls is List) {
      int cnt = 0;
      for (final item in controls) {
        if (item is Map && item['value'] is Map && (item['value'] as Map)['files'] != null) {
          cnt = (item['value'] as Map)['files'].length;
        }
      }
      return cnt;
    }
    if (controls is Map) {
      int cnt = 0;
      for (final entry in controls.values) {
        if (entry is Map && entry['value'] is Map && (entry['value'] as Map)['files'] != null) {
          cnt++;
        }
      }
      return cnt;
    }
    return 0;
  }

  /// Inspect submitForm response to determine immediate success or pending task
  static SubmissionCheckResult checkSubmissionStatus(Map<String, dynamic> response) {
    if (response.containsKey('apply_id')) {
      final applyId = response['apply_id'];
      if (applyId is int && applyId > 0) {
        return SubmissionCheckResult.success(applyId);
      }
    }

    final taskId = _extractTaskId(response);
    if (taskId == null || taskId.isEmpty) {
      return SubmissionCheckResult.error('لم يتم إرجاع task_id أو apply_id من السيرفر');
    }
    final accessToken = _extractAccessToken(response);
    return SubmissionCheckResult.pending(taskId, accessToken);
  }

  /// Small grace-period poll that queries status quickly without UI deps
   static Future<SubmissionCheckResult> pollForGracePeriod({
    required String taskId,
    String? accessToken,
    Duration grace = const Duration(seconds: 5),
    Duration pollInterval = const Duration(seconds: 1),
    Duration perAttemptTimeout = const Duration(seconds: 1),
  }) async {
    final deadline = DateTime.now().add(grace);

    while (DateTime.now().isBefore(deadline)) {
      try {
        // اجلب النتيجة من ApiClient - قد تُعيد String أو Map أو JSON-string
        final raw = await ApiClient.instance
            .checkTaskStatus(taskId, accessToken: accessToken)
            .timeout(perAttemptTimeout);

        // نحاول أن نتعامل مع كل الحالات الممكنة:
        // 1) String نصي
        // 2) JSON string -> نحاول decode
        // 3) Map مُحلّل أصلاً
        String trimmed = '';
        dynamic parsed;
        if (raw == null) {
          trimmed = '';
        } else if (raw is String) {
          trimmed = raw.trim();
          // حاول decode إذا كان JSON محاطًا بأقواس
          if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
            try {
              parsed = jsonDecode(trimmed);
            } catch (_) {
              parsed = null;
            }
          }
        } else if (raw is Map || raw is List) {
          parsed = raw;
        } else {
          // fallback to toString
          trimmed = raw.toString().trim();
        }

        // 1) إذا وجدنا apply_id ضمن parsed (Map) -> نجاح
        if (parsed is Map) {
          // حاول استخراج apply_id بأكثر من مفتاح ممكن
          final apply = parsed['apply_id'] ?? parsed['applyId'] ?? parsed['id'] ?? parsed['result'];
          final maybe = apply is int ? apply : int.tryParse('${apply ?? ''}');
          if (maybe != null && maybe > 0) {
            return SubmissionCheckResult.success(maybe);
          }

          // وإلا: حاول استخراج رسائل/كود حالة لو موجودة
          final stateStr = (parsed['status'] ?? parsed['state'] ?? parsed['result'] ?? '').toString().toLowerCase();
          final isPending = stateStr.isEmpty ||
              stateStr == 'null' ||
              stateStr == 'none' ||
              stateStr == 'queued' ||
              stateStr == 'pending' ||
              stateStr == 'in_progress' ||
              stateStr == 'running' ||
              stateStr.contains('wait') ||
              stateStr.contains('queue');

          if (!isPending && stateStr.isNotEmpty) {
            return SubmissionCheckResult.error('خطأ في تنفيذ المهمة: $stateStr');
          }
        }

        // 2) إذا parsed هو List حاول أخذ أول عنصر إن كان Map
        if (parsed is List && parsed.isNotEmpty && parsed.first is Map) {
          final maybeApply = (parsed.first as Map)['apply_id'] ?? (parsed.first as Map)['applyId'];
          final ap = maybeApply is int ? maybeApply : int.tryParse('${maybeApply ?? ''}');
          if (ap != null && ap > 0) return SubmissionCheckResult.success(ap);
        }

        // 3) إذا مجرد نص (trimmed) جرب تحويله لعدد أو استخدم قواعد السلاسل
        if (trimmed.isNotEmpty) {
          final applyId = int.tryParse(trimmed);
          if (applyId != null && applyId > 0) {
            return SubmissionCheckResult.success(applyId);
          }

          final s = trimmed.toLowerCase();
          final isPending = s == 'null' ||
              s == 'none' ||
              s == 'queued' ||
              s == 'pending' ||
              s == 'in_progress' ||
              s == 'running' ||
              s == 'processing' ||
              s.isEmpty ||
              s.contains('wait') ||
              s.contains('queue');

          if (!isPending) {
            return SubmissionCheckResult.error('خطأ في تنفيذ المهمة: $trimmed');
          }
        }
      } catch (e) {
        // تجاهل الأخطاء المؤقتة (timeout، network...) واستمر حتى انتهاء ال grace
        print('Error polling for grace period: $e');
      }

      await Future.delayed(pollInterval);
    }

    // اذا انتهت النافذة الزمنية نُعيد pending باستخدام الـ taskId الأصلي
    return SubmissionCheckResult.pending(taskId, accessToken);
  }

  static String? _extractTaskId(Map<String, dynamic> response) {
    if (response.containsKey('details') && response['details'] is Map) {
      final details = (response['details'] as Map).cast<String, dynamic>();
      if (details.containsKey('task_id')) {
        final taskId = details['task_id'];
        return taskId?.toString();
      }
    }
    if (response.containsKey('correlation_id')) {
      return response['correlation_id']?.toString();
    }
    if (response.containsKey('task_id')) {
      final taskId = response['task_id'];
      return taskId?.toString();
    }
    if (response.containsKey('apply_id')) {
      return null;
    }
    return null;
  }

  static String? _extractAccessToken(Map<String, dynamic> response) {
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
}


