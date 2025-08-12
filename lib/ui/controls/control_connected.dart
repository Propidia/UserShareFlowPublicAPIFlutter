import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/form_controller.dart';
import '../../controllers/connected_options_controller.dart';
import '../../models/form_models.dart';

class ConnectedControl extends StatelessWidget {
  final ControlModel control;
  final FormController controller;
  const ConnectedControl({
    super.key,
    required this.control,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // استخراج الاعتمادية من meta.placeholders
    final requiredControls = <int>[];
    final meta = control.meta;
    if (meta is Map) {
      final filters = (meta as Map)['filters'];
      List<dynamic> placeholders = const [];
      if (filters is Map) {
        final phs = filters['placeholders'];
        if (phs is List) {
          placeholders = phs;
        }
      }
      for (final p in placeholders) {
        if (p is Map && p['required'] == true && p['control_id'] is int) {
          requiredControls.add(p['control_id'] as int);
        }
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Obx(() {
              final currentText =
                  controller.values[control.id]?.toString() ?? '';
              // عرض قيمة مختصرة للأداة إذا كانت من نوع connected
              final display = () {
                if (currentText.isEmpty) return '';
                // currentText قد يكون JSON لكائن {value, keys, label, display}
                if (currentText.startsWith('{') && currentText.endsWith('}')) {
                  try {
                    final obj = jsonDecode(currentText);
                    if (obj is Map) {
                      if (obj['label'] != null &&
                          obj['label'].toString().trim().isNotEmpty) {
                        return obj['label'].toString();
                      }
                      if (obj['display'] is Map &&
                          (obj['display'] as Map).isNotEmpty) {
                        final first = (obj['display'] as Map).entries.first;
                        return first.value?.toString() ?? currentText;
                      }
                      if (obj['value'] != null) return obj['value'].toString();
                    }
                  } catch (_) {}
                }
                return currentText;
              }();
              return TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: control.name + (control.requiredField ? ' *' : ''),
                  border: const OutlineInputBorder(),
                ),
                controller: TextEditingController(text: display),
              );
            }),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              // التحقق من الاعتمادية: جميع الحقول المطلوبة يجب أن تكون مملوءة
              final missing = <int>[];
              for (final depId in requiredControls) {
                final v = controller.values[depId];
                if (v == null || v.toString().trim().isEmpty) {
                  missing.add(depId);
                }
              }
              if (missing.isNotEmpty) {
                Get.snackbar(
                  'تنبيه',
                  'لا يمكن فتح أداة الربط قبل تعبئة الحقول المطلوبة: ${missing.join(', ')}',
                );
                return;
              }
              if (!controller.canChangeValue(control.id)) {
                Get.snackbar(
                  'تنبيه',
                  'لا يمكن تغيير القيمة قبل مسح قيم الأدوات التابعة',
                );
                return;
              }
              final selected = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (_) => _ConnectedOptionsDialog(
                  control: control,
                  formId: controller.currentForm.value!.id,
                  controller: controller,
                ),
              );
              if (selected != null) {
                // تحويل القيمة المختارة إلى JSON string للحفظ
                controller.setValue(control.id, jsonEncode(selected));
              }
            },
            child: const Text('اختيار'),
          ),
        ],
      ),
    );
  }
}

class _ConnectedOptionsDialog extends StatefulWidget {
  final ControlModel control;
  final int formId;
  final FormController controller;
  const _ConnectedOptionsDialog({
    required this.control,
    required this.formId,
    required this.controller,
  });

  @override
  State<_ConnectedOptionsDialog> createState() =>
      _ConnectedOptionsDialogState();
}

class _ConnectedOptionsDialogState extends State<_ConnectedOptionsDialog> {
  late final ConnectedOptionsController optionsController;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    optionsController = Get.put(ConnectedOptionsController());
    optionsController.page = 1;
    optionsController.load(
      formId: widget.formId,
      controlId: widget.control.id,
      controlValues: widget.controller.buildControlValuesPayload(),
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<ConnectedOptionsController>()) {
      Get.delete<ConnectedOptionsController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 800,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'بحث...',
                      ),
                      onSubmitted: (q) => optionsController.search(
                        q,
                        formId: widget.formId,
                        controlId: widget.control.id,
                        controlValues: widget.controller
                            .buildControlValuesPayload(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => optionsController.search(
                      searchController.text.trim(),
                      formId: widget.formId,
                      controlId: widget.control.id,
                      controlValues: widget.controller
                          .buildControlValuesPayload(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  final loading = optionsController.isLoading.value;
                  final items = optionsController.items;
                  if (loading && items.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (items.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج'));
                  }
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final it = items[index];
                      final displayText = (it.display.isEmpty)
                          ? (it.value?.toString() ?? '')
                          : it.display.entries
                                .map((e) => '${e.key}: ${e.value ?? ''}')
                                .join(' | ');
                      return ListTile(
                        title: Text(
                          (it.label.isNotEmpty
                                  ? it.label
                                  : it.value?.toString() ?? '')
                              .trim(),
                        ),
                        subtitle: Text(displayText),
                        onTap: () {
                          final selected = {
                            'value': it.value,
                            'keys': it.fks,
                            'label': it.label,
                            'display': it.display,
                          };
                          Navigator.pop(context, selected);
                        },
                      );
                    },
                  );
                }),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: Navigator.of(context).pop,
                    child: const Text('إغلاق'),
                  ),
                  Obx(
                    () => TextButton(
                      onPressed:
                          (optionsController.hasMore.value &&
                              !optionsController.isLoading.value)
                          ? () => optionsController.nextPage(
                              formId: widget.formId,
                              controlId: widget.control.id,
                              controlValues: widget.controller
                                  .buildControlValuesPayload(),
                            )
                          : null,
                      child: const Text('المزيد'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
