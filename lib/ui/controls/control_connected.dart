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
    // استخراج الاعتمادية من meta
    // 1) الصيغة الجديدة: meta.quick_usage.get_data_form.params.filtersDepends
    // 2) fallback للصيغة القديمة: meta.filters.placeholders
    final requiredControls = <int>[];
    final quick = control.quickUsageMeta;
    if (quick != null) {
      final dynamic getDataForm = quick['get_data_form'];
      if (getDataForm is Map) {
        final dynamic params = getDataForm['params'];
        if (params is Map) {
          final dynamic filtersDepends = params['filtersDepends'];
          if (filtersDepends is List) {
            for (final dep in filtersDepends) {
              if (dep is Map && dep['control_id'] is int) {
                requiredControls.add(dep['control_id'] as int);
              }
            }
            // تسجيل الاعتمادية في المتحكم العام للنموذج حتى يمكن قفل الحقول عندما تُختار قيمة في أداة الربط
            controller.registerConnectedDependencies(control.id, requiredControls);
          }
        }
      }
    }
    return Obx(() {
      final currentText = controller.values[control.id]?.toString() ?? '';
      final display = currentText;
      final missing = <int>[];
      for (final depId in requiredControls) {
        final v = controller.values[depId];
        if (v == null || v.toString().trim().isEmpty) {
          missing.add(depId);
        }
      }
      final bool canChange = controller.canChangeValue(control.id);
      final bool isLocked = missing.isNotEmpty || !canChange;

      if (isLocked) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(control.name + (control.requiredField ? ' *' : '')),
              const SizedBox(height: 6),
              Text(display),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: control.name + (control.requiredField ? ' *' : ''),
                  border: const OutlineInputBorder(),
                ),
                controller: TextEditingController(text: display),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final selected = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => _ConnectedOptionsDialog(
                    control: control,
                    formId: controller.currentForm.value!.id,
                    controller: controller,
                  ),
                );
                if (selected != null) {
                  controller.setValue(control.id, jsonEncode(selected));
                }
              },
              child: const Text('اختيار'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                controller.clearValue(control.id);
              },
              child: const Text('مسح'),
            ),
          ],
        ),
      );
    });
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
    optionsController.load(
      table_id: widget.control.tableId!,
      controlId: widget.control.id,
      filters: widget.control.meta,
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
                        table_id: widget.control.tableId!,
                        controlId: widget.control.id,
                        flitter: widget.control.meta,
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
                      table_id: widget.control.tableId!,
                      controlId: widget.control.id,
                      flitter: widget.control.meta,
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
                  List<Map<String, dynamic>> item = [];
                  item.assignAll(items);

                  return ListView.builder(
                    itemCount: item.length,
                    itemBuilder: (context, index) {
                      final currentMap = item[index];

                      final firstEntry = (currentMap as Map).entries.first;
                      final secondEntry = (currentMap as Map).entries.last;

                      return ListTile(
                        title: Text(
                          firstEntry.value.toString(),
                        ), // القيمة الأولى
                        subtitle: Text(
                          secondEntry.value.toString(),
                        ), // القيمة الثانية
                        onTap: () {
                          widget.controller.setValue(widget.control.id, firstEntry.value);
                          Navigator.of(context).pop();
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
                              table_id: widget.control.tableId!,
                              controlId: widget.control.id,
                              flitter: widget.control.meta,
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
