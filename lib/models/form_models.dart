class FormStructureModel {
  final int id;
  final String name;
  final List<ControlModel> controls;

  FormStructureModel({
    required this.id,
    required this.name,
    required this.controls,
  });

  factory FormStructureModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> ctrls = json['controls'] ?? [];
    return FormStructureModel(
      id: json['id'] as int,
      name: json['name'] as String,
      controls: ctrls
          .map((e) => ControlModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ControlModel {
  final int id;
  final int type;
  final String name;
  final bool requiredField;
  final dynamic value;
  final List<dynamic> options; // للأداة 6
  final String? dateType; // للأداة 5: date/time/datetime/date_h
  final int? tableId; // للأداة 16
  final List<String> fks; // للأداة 16
  final Map<String, dynamic>? meta; // للأداة 16
  final List<ControlModel> children; // للأداة 8

  ControlModel({
    required this.id,
    required this.type,
    required this.name,
    required this.requiredField,
    this.value,
    this.options = const [],
    this.dateType,
    this.tableId,
    this.fks = const [],
    this.meta,
    this.children = const [],
  });

  factory ControlModel.fromJson(Map<String, dynamic> json) {
    // required = not bool(self.required) في الباك، فالقيمة القادمة تعني جاهزة مباشرة
    final List<ControlModel> parsedChildren = <ControlModel>[];
    if (json['rows'] is List && (json['rows'] as List).isNotEmpty) {
      final firstRow = (json['rows'] as List).first;
      if (firstRow is Map && firstRow['controls'] is List) {
        parsedChildren.addAll(
          (firstRow['controls'] as List).map(
            (e) => ControlModel.fromJson(e as Map<String, dynamic>),
          ),
        );
      }
    }

    final dynamic options = json['options'];
    return ControlModel(
      id: json['id'] as int,
      type: _mapType(json['type']),
      name: json['name']?.toString() ?? '',
      requiredField: json['required'] == true,
      value: json['value'],
      options: options is List ? options : const [],
      dateType: json['DateType']?.toString(),
      tableId: json['table_id'] is int ? json['table_id'] as int : null,
      fks: (json['value'] is Map)
          ? List<String>.from(
              (json['value'] as Map).keys.map((e) => e.toString()),
            )
          : <String>[],
      meta: json['meta'] is Map<String, dynamic>
          ? json['meta'] as Map<String, dynamic>
          : null,
      children: parsedChildren,
    );
  }

  static int _mapType(dynamic t) {
    if (t is int) return t;
    // في بعض الحالات قد يأتي كاسم نصي، نحاول تعيينه
    switch (t?.toString()) {
      case 'نص عادي':
        return 1;
      case 'نص كبير':
        return 2;
      case 'رقم':
        return 3;
      case 'رقم عشري':
        return 4;
      case 'تاريخ':
        return 5;
      case 'قائمة منسدلة':
        return 6;
      case 'ملف':
        return 7;
      case 'جدول':
        return 8;
      case 'أداة ربط':
        return 16;
      case 'الموقع الجغرافي':
        return 17;
      case 'اختيار':
        return 20;
      default:
        return -1;
    }
  }
}

class ConnectedOptionItem {
  final dynamic value;
  final String label;
  final Map<String, dynamic> display;
  final Map<String, dynamic> fks;
  final Map<String, dynamic> controls;

  ConnectedOptionItem({
    required this.value,
    required this.label,
    required this.display,
    required this.fks,
    required this.controls,
  });

  factory ConnectedOptionItem.fromJson(Map<String, dynamic> json) {
    return ConnectedOptionItem(
      value: json['value'],
      label: (json['label']?.toString().isNotEmpty ?? false)
          ? json['label'].toString()
          // fallback: إن لم يوجد label جرّب أول display
          : _firstDisplay(json) ?? '',
      display: Map<String, dynamic>.from(json['display'] ?? {}),
      fks: Map<String, dynamic>.from(json['fks'] ?? {}),
      controls: Map<String, dynamic>.from(json['controls'] ?? {}),
    );
  }

  static String? _firstDisplay(Map<String, dynamic> json) {
    final d = json['display'];
    if (d is Map && d.isNotEmpty) {
      final first = d.entries.first;
      return first.value?.toString();
    }
    return null;
  }
}

class ConnectedOptionsResponse {
  final int formId;
  final int controlId;
  final int tableId;
  final Map<String, dynamic> schema;
  final List<ConnectedOptionItem> items;
  final Map<String, dynamic> pagination;

  ConnectedOptionsResponse({
    required this.formId,
    required this.controlId,
    required this.tableId,
    required this.schema,
    required this.items,
    required this.pagination,
  });

  factory ConnectedOptionsResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> its = json['items'] ?? [];
    return ConnectedOptionsResponse(
      formId: json['form_id'] as int,
      controlId: json['control_id'] as int,
      tableId: json['table_id'] as int,
      schema: Map<String, dynamic>.from(json['schema'] ?? {}),
      items: its
          .map((e) => ConnectedOptionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: Map<String, dynamic>.from(json['pagination'] ?? {}),
    );
  }
}
