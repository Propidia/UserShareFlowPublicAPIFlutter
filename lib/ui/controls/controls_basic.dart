import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
// ملاحظة: سنضيف دعم jhijri_picker لاحقاً بعد التأكد من واجهة الحزمة

import '../../controllers/form_controller.dart';
import '../../models/form_models.dart';

class BasicTextControl extends StatelessWidget {
  final ControlModel control;
  final FormController controller;
  const BasicTextControl({
    super.key,
    required this.control,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentValue = controller.values[control.id]?.toString() ?? '';
      final bool isLocked = controller.isLockedByConnected(control.id);
      TextInputType inputType = TextInputType.text;
      if (control.type == 3) inputType = TextInputType.number; // رقم
      if (control.type == 4) {
        inputType = const TextInputType.numberWithOptions(decimal: true);
      }
      if (isLocked) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(control.name + (control.requiredField ? ' *' : '')),
              const SizedBox(height: 6),
              Text(currentValue),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextFormField(
          initialValue: currentValue,
          keyboardType: inputType,
          decoration: InputDecoration(
            labelText: control.name + (control.requiredField ? ' *' : ''),
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => controller.setValue(control.id, v),
        ),
      );
    });
  }
}

class DateControl extends StatelessWidget {
  final ControlModel control;
  final FormController controller;
  const DateControl({
    super.key,
    required this.control,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final value = controller.values[control.id]?.toString() ?? '';
      final bool isLocked = controller.isLockedByConnected(control.id);
      if (isLocked) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${control.name} (${control.dateType ?? 'date'})'),
              const SizedBox(height: 6),
              Text(value),
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
                  labelText: '${control.name} (${control.dateType ?? 'date'})',
                  border: const OutlineInputBorder(),
                ),
                controller: TextEditingController(text: value),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final dt = control.dateType?.toLowerCase();
                if (dt == 'date_h') {
                  Get.snackbar(
                    'تنبيه',
                    'سيتم دعم التاريخ الهجري لاحقاً بعد ضبط الحزمة',
                  );
                  return;
                }
                if (dt == 'time') {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (t != null) {
                    controller.setValue(control.id, t.format(context));
                  }
                  return;
                }
                if (dt == 'datetime') {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                    initialDate: DateTime.now(),
                  );
                  if (d != null) {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (t != null) {
                      final dtVal = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        t.hour,
                        t.minute,
                      );
                      controller.setValue(control.id, dtVal.toString());
                    }
                  }
                  return;
                }
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                  initialDate: DateTime.now(),
                );
                if (d != null) {
                  controller.setValue(control.id, d.toString());
                }
              },
              child: const Text('اختيار'),
            ),
          ],
        ),
      );
    });
  }
}

class DropdownControl extends StatelessWidget {
  final ControlModel control;
  final FormController controller;
  const DropdownControl({
    super.key,
    required this.control,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> options = control.options
        .map((e) => e.toString())
        .toList();
    return Obx(() {
      final String? value = controller.values[control.id]?.toString();
      final bool isLocked = controller.isLockedByConnected(control.id);
      if (isLocked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(control.name + (control.requiredField ? ' *' : '')),
            const SizedBox(height: 6),
            Text(value ?? ''),
          ],
        );
      }
      return Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value != null && options.contains(value) ? value : null,
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) {
                if (v != null) controller.setValue(control.id, v);
              },
              decoration: InputDecoration(
                labelText: control.name + (control.requiredField ? ' *' : ''),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              controller.setValue(control.id, null);
            },
            child: const Text('مسح'),
          ),
        ],
      );
    });
  }
}

class FileControl extends StatefulWidget {
  final ControlModel control;
  final FormController controller;
  const FileControl({
    super.key,
    required this.control,
    required this.controller,
  });

  @override
  State<FileControl> createState() => _FileControlState();
}

class _FileControlState extends State<FileControl> {
  List<Map<String, dynamic>> files = [];
  List<Map<String, dynamic>> folders = [];

  @override
  void initState() {
    super.initState();
    final v = widget.controller.values[widget.control.id];
    if (v is Map<String, dynamic>) {
      files = List<Map<String, dynamic>>.from(v['files'] ?? []);
      folders = List<Map<String, dynamic>>.from(v['folders'] ?? []);
    }
  }

  void _sync() {
    widget.controller.setValue(widget.control.id, {
      'files': files,
      'folders': folders,
    });
    setState(() {});
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.first;
      final bytes = f.bytes;
      if (bytes != null) {
        final b64 = base64Encode(bytes);
        files.add({'base64': b64, 'path': f.name});
        _sync();
      }
    }
  }

  void _addFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة مجلد'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'folder/subfolder'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      folders.add({'folder_path': name});
      _sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool isLocked = widget.controller.isLockedByConnected(widget.control.id);
      if (isLocked) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.control.name),
              const SizedBox(height: 6),
              if (folders.isNotEmpty)
                Text('المجلدات: ' + folders
                    .map((f) => f['folder_path']?.toString() ?? '')
                    .where((s) => s.isNotEmpty)
                    .join(', ')),
              if (files.isNotEmpty)
                Text('الملفات: ' + files
                    .map((f) => f['path']?.toString() ?? '')
                    .where((s) => s.isNotEmpty)
                    .join(', ')),
              if (folders.isEmpty && files.isEmpty) const Text('لا توجد بيانات'),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.control.name),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload),
                  label: const Text('إضافة ملف'),
                ),
                OutlinedButton.icon(
                  onPressed: _addFolder,
                  icon: const Icon(Icons.create_new_folder),
                  label: const Text('إضافة مجلد'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (folders.isNotEmpty) Text('المجلدات (${folders.length})'),
            ...folders.map(
              (f) => ListTile(
                dense: true,
                title: Text(f['folder_path']?.toString() ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    folders.remove(f);
                    _sync();
                  },
                ),
              ),
            ),
            if (files.isNotEmpty) Text('الملفات (${files.length})'),
            ...files.map(
              (f) => ListTile(
                dense: true,
                title: Text(f['path']?.toString() ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    files.remove(f);
                    _sync();
                  },
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class GeoControl extends StatelessWidget {
  final ControlModel control;
  final FormController controller;
  const GeoControl({
    super.key,
    required this.control,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final text = controller.values[control.id]?.toString() ?? '';
      final bool isLocked = controller.isLockedByConnected(control.id);
      if (isLocked) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(control.name),
              const SizedBox(height: 6),
              Text(text),
            ],
          ),
        );
      }
      final latController = TextEditingController();
      final lonController = TextEditingController();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(control.name),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latController,
                    decoration: const InputDecoration(
                      labelText: 'lat',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: lonController,
                    decoration: const InputDecoration(
                      labelText: 'lon',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final lat = latController.text.trim();
                    final lon = lonController.text.trim();
                    if (lat.isEmpty || lon.isEmpty) {
                      Get.snackbar('تنبيه', 'الرجاء إدخال lat و lon');
                      return;
                    }
                    controller.setValue(control.id, '$lat,$lon');
                  },
                  child: const Text('تعيين'),
                ),
              ],
            ),
            if (text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('القيمة: $text'),
              ),
          ],
        ),
      );
    });
  }
}

class CheckboxControl extends StatelessWidget {
  final ControlModel control;
  final FormController controller;
  const CheckboxControl({
    super.key,
    required this.control,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final v = (controller.values[control.id]?.toString() ?? 'لا') == 'نعم';
      final bool isLocked = controller.isLockedByConnected(control.id);
      if (isLocked) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(control.name),
              const SizedBox(height: 6),
              Text(v ? 'نعم' : 'لا'),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: CheckboxListTile(
          title: Text(control.name),
          value: v,
          onChanged: (checked) => controller.setValue(
            control.id,
            checked == true ? 'نعم' : 'لا',
          ),
        ),
      );
    });
  }
}
