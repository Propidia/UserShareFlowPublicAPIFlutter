import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/form_controller.dart';
import '../controllers/folder_processing_controller.dart';
import '../models/form_models.dart';
import 'controls/control_factory.dart';

class DynamicFormScreen extends StatefulWidget {
  final int formId;
  const DynamicFormScreen({super.key, required this.formId});

  @override
  State<DynamicFormScreen> createState() => _DynamicFormScreenState();
}

class _DynamicFormScreenState extends State<DynamicFormScreen> {
  // استخدام late لإزالة التحذير، مع العلم أنه سيتم تهيئته في initState
  late final FormController formController;
  late final FolderProcessingController folderController;

  @override
  void initState() {
    super.initState();
    // يجب أن تكون Get.find() هي الطريقة الصحيحة إذا كان Controller موجودًا بالفعل في الذاكرة
    formController = Get.find<FormController>(); 
    // Get.put() لتهيئة FolderController
    folderController = Get.put(FolderProcessingController()); 
    
    // ربط FormController بـ FolderController لتحديث قيم النموذج
    folderController.setFormController(formController);
    formController.loadFormStructure(widget.formId);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopScope(
        canPop: !folderController.isProcessing.value,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) {
            folderController.updateUIAfterStopeing();
          } else if (folderController.isProcessing.value) {
            // عرض رسالة للمستخدم عند محاولة الرجوع أثناء المعالجة
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لا يمكن الرجوع أثناء المعالجة. يرجى الانتظار حتى تنتهي المعالجة.'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
        child: Scaffold(
      appBar: AppBar(
        title: const Text('نموذج تعبئة البيانات', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        if (formController.isLoadingStructure.value ||
            formController.currentForm.value == null) {
          return const Center(child: CircularProgressIndicator(color: Colors.blue));
        }

        final FormStructureModel form = formController.currentForm.value!;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20), // زيادة التباعد حول النموذج
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Folder Processing Widget ---
              _buildFolderProcessingWidget(context),
              
              const SizedBox(height: 24), // فاصل أكبر بعد زر المعالجة

              // --- Form Title ---
              // Text(
              //   form.name,
              //   style: Theme.of(context).textTheme.titleLarge?.copyWith(
              //         fontWeight: FontWeight.bold,
              //         color: Colors.blue.shade900,
              //       ),
              // ),
              // const SizedBox(height: 16), // فاصل قبل عناصر التحكم

              // // --- Form Controls ---
              // // تم إرجاع هذا الجزء من التعليق ليكون النموذج وظيفيًا
              // ...form.controls
              //     .map((c) => ControlFactory.buildControl(c, formController))
              //     .toList(),

              // const SizedBox(height: 30), // فاصل قبل زر الإرسال

              // --- Submit Button ---
              // تم إرجاع هذا الجزء من التعليق ليكون النموذج وظيفيًا
              // Obx(
              //   () => SizedBox(
              //     width: double.infinity,
              //     height: 50,
              //     child: ElevatedButton(
              //       onPressed: formController.isSubmitting.value
              //           ? null
              //           : () => formController.submitForm(),
              //       style: ElevatedButton.styleFrom(
              //         backgroundColor: Colors.green.shade600,
              //         foregroundColor: Colors.white,
              //         shape: RoundedRectangleBorder(
              //           borderRadius: BorderRadius.circular(8),
              //         ),
              //         elevation: 4, // إضافة ظل
              //       ),
              //       child: formController.isSubmitting.value
              //           ? const Row(
              //                 mainAxisAlignment: MainAxisAlignment.center,
              //                 children: [
              //                   SizedBox(
              //                     width: 20, // حجم أكبر للمؤشر
              //                     height: 20,
              //                     child: CircularProgressIndicator(
              //                       color: Colors.white,
              //                       strokeWidth: 2.5, // سمك أكبر
              //                     ),
              //                   ),
              //                   SizedBox(width: 10),
              //                   Text('جاري إرسال النموذج...', style: TextStyle(fontSize: 16)),
              //                 ],
              //               )
              //           : const Text(
              //                 'إرسال النموذج',
              //                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              //               ),
              //     ),
              //   ),
              // ),
            ],
          ),
        );
      }),
    ),
      ),
    );
  }

  // دالة مساعدة لبناء واجهة معالجة المجلد لتحسين قراءة الكود
  Widget _buildFolderProcessingWidget(BuildContext context) {
    return Obx(
      () => Card( // استخدام Card لإضافة خلفية وظل للـ widget
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: folderController.isProcessing.value
                    ? null
                    : () => folderController.pickAndProcessFolder(),
                icon: folderController.isProcessing.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5, // زيادة سمك المؤشر
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.folder_open, size: 24),
                label: Text(
                  folderController.isProcessing.value
                      ? 'جاري المعالجة... (${folderController.processedCount.value}/${folderController.totalCount.value})'
                      : 'بدء معالجة مجلد',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15), // زيادة ارتفاع الزر
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              
              if (folderController.isProcessing.value)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0), // فاصل أكبر
                  child: Column(
                    children: [
                      // تحسين شريط التقدم الخطي
                      ClipRRect( // لإضافة حواف دائرية لشريط التقدم
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: folderController.totalCount.value > 0
                              ? folderController.processedCount.value /
                                    folderController.totalCount.value
                              : 0,
                          backgroundColor: Colors.blue.shade100, // لون خلفية فاتح
                          color: Colors.blue.shade500, // لون التقدم الأساسي
                          minHeight: 8, // ارتفاع أكبر
                        ),
                      ),
                      const SizedBox(height: 8),
                      // تحسين عرض الإحصائيات
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatText(
                            icon: Icons.check_circle,
                            label: 'نجاح: ${folderController.successCount.value}',
                            color: Colors.green.shade700,
                          ),
                          _buildStatText(
                            icon: Icons.cancel,
                            label: 'فشل: ${folderController.failureCount.value}',
                            color: Colors.red.shade700,
                          ),
                          _buildStatText(
                            icon: Icons.info,
                            label: 'المتبقي: ${folderController.totalCount.value - folderController.processedCount.value}',
                            color: Colors.grey.shade700,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة مساعدة لعرض إحصائيات المعالجة
  Widget _buildStatText({required IconData icon, required String label, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}