import 'package:flutter/material.dart';
import '../../controllers/form_controller.dart';
import '../../models/form_models.dart';
import 'control_factory.dart';

class TableControl extends StatefulWidget {
  final ControlModel control;
  final FormController controller;
  const TableControl({
    super.key,
    required this.control,
    required this.controller,
  });

  @override
  State<TableControl> createState() => _TableControlState();
}

class _TableControlState extends State<TableControl> {
  final List<List<ControlModel>> rows = [];

  @override
  void initState() {
    super.initState();
    // صف ابتدائي واحد
    rows.add(widget.control.children.map((e) => e).toList());
    _updateRowCount();
  }

  void _addRow() {
    rows.add(widget.control.children.map((e) => e).toList());
    _updateRowCount();
    setState(() {});
  }

  void _removeRow(int index) {
    if (rows.length <= 1) return;
    rows.removeAt(index);
    _updateRowCount();
    setState(() {});
  }

  void _updateRowCount() {
    widget.controller.updateTableRowCount(widget.control.id, rows.length);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.control.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                label: const Text('إضافة صف'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (context, rowIndex) {
              final controls = rows[rowIndex];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('صف ${rowIndex + 1}'),
                      if (rows.length > 1)
                        IconButton(
                          onPressed: () => _removeRow(rowIndex),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...controls.map((c) {
                    if (c.type == 8) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('تحذير: لا يمكن وضع جدول داخل جدول'),
                      );
                    }

                    // تحويل أدوات الصف الحالي إلى Map لتمريرها لأدوات الربط
                    final currentRowControls = controls
                        .map(
                          (control) => {
                            'id': control.id,
                            'name': control.name,
                            'type': control.type,
                            'value': widget.controller.values[control.id],
                            if (control.meta != null) 'meta': control.meta,
                          },
                        )
                        .toList();

                    return ControlFactory.buildControl(
                      c,
                      widget.controller,
                      currentRowControls: currentRowControls,
                    );
                  }).toList(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
