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
  final formController = Get.find<FormController>();
  late final FolderProcessingController folderController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers
    folderController = Get.put(FolderProcessingController());
    // ربط FormController بـ FolderController لتحديث قيم النموذج
    folderController.setFormController(formController);
    formController.loadFormStructure(widget.formId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النموذج')),
      body: Obx(() {
        if (formController.isLoadingStructure.value ||
            formController.currentForm.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final FormStructureModel form = formController.currentForm.value!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Folder Processing Button
              Obx(
                () => Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: folderController.isProcessing.value
                          ? null
                          : () => folderController.pickAndProcessFolder(),
                      icon: folderController.isProcessing.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.folder_open),
                      label: folderController.isProcessing.value
                          ? Text(
                              'جاري المعالجة... (${folderController.processedCount.value}/${folderController.totalCount.value})')
                          : const Text('معالجة مجلد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    if (folderController.isProcessing.value)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: folderController.totalCount.value > 0
                                  ? folderController.processedCount.value /
                                      folderController.totalCount.value
                                  : 0,
                              backgroundColor: Colors.grey[300],
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '✅ ${folderController.successCount.value} | ❌ ${folderController.failureCount.value}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // const SizedBox(height: 16),
              // Text(form.name, style: Theme.of(context).textTheme.titleLarge),
              // const SizedBox(height: 12),
              // ...form.controls
              //     .map((c) => ControlFactory.buildControl(c, formController))
              //     .toList(),
              // const SizedBox(height: 24),
              // Obx(
              //   () => SizedBox(
              //     width: double.infinity,
              //     height: 50,
              //     child: ElevatedButton(
              //       onPressed: formController.isSubmitting.value
              //           ? null
              //           : () => formController.submitForm(),
              //       style: ElevatedButton.styleFrom(
              //         backgroundColor: Colors.green,
              //         foregroundColor: Colors.white,
              //       ),
              //       child: formController.isSubmitting.value
              //           ? const Row(
              //               mainAxisAlignment: MainAxisAlignment.center,
              //               children: [
              //                 SizedBox(
              //                   width: 16,
              //                   height: 16,
              //                   child: CircularProgressIndicator(
              //                     color: Colors.white,
              //                     strokeWidth: 2,
              //                   ),
              //                 ),
              //                 SizedBox(width: 8),
              //                 Text('جاري الإرسال...'),
              //               ],
              //             )
              //           : const Text(
              //               'إرسال النموذج',
              //               style: TextStyle(fontSize: 16),
              //             ),
              //     ),
              //   ),
              // ),
            ],
          ),
        );
      }),
    );
  }
}
