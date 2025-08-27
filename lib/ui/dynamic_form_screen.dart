import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/form_controller.dart';
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

  @override
  void initState() {
    super.initState();
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
              Text(form.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...form.controls
                  .map((c) => ControlFactory.buildControl(c, formController))
                  .toList(),
              const SizedBox(height: 24),
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: formController.isSubmitting.value
                        ? null
                        : () => formController.submitForm(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: formController.isSubmitting.value
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('جاري الإرسال...'),
                            ],
                          )
                        : const Text(
                            'إرسال النموذج',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
