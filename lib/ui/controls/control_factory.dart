import 'package:flutter/material.dart';
import '../../controllers/form_controller.dart';
import '../../models/form_models.dart';
import 'controls_basic.dart';
import 'control_connected.dart';
import 'control_table.dart';

class ControlFactory {
  static Widget buildControl(
    ControlModel c,
    FormController controller, {
    List<Map<String, dynamic>>? currentRowControls,
  }) {
    switch (c.type) {
      case 1:
      case 2:
      case 3:
      case 4:
        return BasicTextControl(control: c, controller: controller);
      case 5:
        return DateControl(control: c, controller: controller);
      case 6:
        return DropdownControl(control: c, controller: controller);
      case 7:
        return FileControl(control: c, controller: controller);
      case 8:
        return TableControl(control: c, controller: controller);
      case 16:
        return ConnectedControl(
          control: c,
          controller: controller,
          currentRowControls: currentRowControls,
        );
      case 17:
        return GeoControl(control: c, controller: controller);
      case 20:
        return CheckboxControl(control: c, controller: controller);
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('نوع غير مدعوم (${c.type}) - ${c.name}'),
        );
    }
  }
}
