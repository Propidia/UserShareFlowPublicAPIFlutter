import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Dialog لعرض أول تطابق (غير قابل للإغلاق يدويًا)
Future<Map<String, dynamic>?> showFirstMatchDialog(
  Map<String, dynamic> valueMap,
) async {
  return Get.dialog<Map<String, dynamic>>(
    WillPopScope(
      onWillPop: () async => false, // يمنع زر الرجوع
      child: AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('تم العثور على تطابق'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: valueMap.isEmpty
              ? const Center(child: Text('لا توجد بيانات'))
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: valueMap.entries.map((entry) {
                            return Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.black12, width: 1),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        entry.key.toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        entry.value?.toString() ?? 'null',
                                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'عدد الحقول: ${valueMap.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
        ),
        // بدون أزرار — الإغلاق برمجياً فقط
      ),
    ),
    barrierDismissible: false,
    useSafeArea: true,
    routeSettings: const RouteSettings(name: 'first_match_dialog'),
  );
}
