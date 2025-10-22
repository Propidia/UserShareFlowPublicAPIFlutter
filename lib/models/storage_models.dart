/// ملف نماذج البيانات المتعلقة بالملفات والتخزين
/// يحتوي على جميع النماذج المستخدمة في إدارة الملفات

/// ## تعداد حالات الملفات في التخزين
///
/// يحدد الحالة الحالية للملف في نظام التخزين
/// يُستخدم لتتبع تغييرات الملفات وتحديد ما إذا كانت تحتاج رفع
enum StorageStatus {
  /// الملف جديد ولم يتم رفعه بعد
  added,
  
  /// الملف موجود بالفعل في التخزين
  existing,
  
  /// تم تعديل الملف بعد الرفع الأولي
  modified,
  
  /// تم نقل الملف إلى موقع جديد
  moved,
  
  /// تم نقل الملف وتعديله
  movedModeified,
  
  /// تم نقل الملف وإعادة تسميته
  movedRenamed,
  
  /// تم إعادة تسمية الملف فقط
  renamed,
  
  /// تم حذف الملف
  deleted,
  
  /// حالة غير معروفة أو خطأ
  unknown
}

/// ## نموذج بيانات الملف
///
/// يمثل ملف واحد في النظام مع جميع معلوماته
class FileModel {
  /// اسم الملف الأصلي
  String name;
  
  /// المسار المحلي للملف أو الرابط في التخزين السحابي
  String? path;
  
  /// بيانات الملف (يمكن أن تكون bytes أو رابط)
  dynamic fileBytes;
  
  /// امتداد الملف
  String? fileExtension;
  
  /// حجم الملف بالبايت
  int? fileSize;
  
  /// نوع الملف (MIME type)
  String? mimeType;
  
  /// حالة الملف في التخزين
  StorageStatus status;
  
  /// هل تم إنشاء الملف في هذه الجلسة؟
  bool? createdInThisSession;
  
  /// تاريخ إنشاء الملف
  DateTime? createdAt;
  
  /// تاريخ آخر تعديل
  DateTime? modifiedAt;
  
  /// معرف فريد للملف
  String? id;
  
  /// بيانات إضافية للملف
  Map<String, dynamic>? metadata;

  FileModel({
    required this.name,
    this.path,
    this.fileBytes,
    this.fileExtension,
    this.fileSize,
    this.mimeType,
    this.status = StorageStatus.added,
    this.createdInThisSession,
    this.createdAt,
    this.modifiedAt,
    this.id,
    this.metadata,
  });

  /// إنشاء نموذج ملف من JSON
  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      name: json['name'] ?? '',
      path: json['path'],
      fileBytes: json['fileBytes'],
      fileExtension: json['fileExtension'],
      fileSize: json['fileSize'],
      mimeType: json['mimeType'],
      status: _parseStorageStatus(json['status']),
      createdInThisSession: json['createdInThisSession'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      modifiedAt: json['modifiedAt'] != null ? DateTime.parse(json['modifiedAt']) : null,
      id: json['id'],
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
    );
  }

  /// تحويل نموذج الملف إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'fileBytes': fileBytes,
      'fileExtension': fileExtension,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'status': status.toString().split('.').last,
      'createdInThisSession': createdInThisSession,
      'createdAt': createdAt?.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
      'id': id,
      'metadata': metadata,
    };
  }

  /// تحليل حالة التخزين من نص
  static StorageStatus _parseStorageStatus(dynamic status) {
    if (status == null) return StorageStatus.unknown;
    
    String statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'added':
        return StorageStatus.added;
      case 'existing':
        return StorageStatus.existing;
      case 'modified':
        return StorageStatus.modified;
      case 'moved':
        return StorageStatus.moved;
      case 'movedmodeified':
        return StorageStatus.movedModeified;
      case 'movedrenamed':
        return StorageStatus.movedRenamed;
      case 'renamed':
        return StorageStatus.renamed;
      case 'deleted':
        return StorageStatus.deleted;
      default:
        return StorageStatus.unknown;
    }
  }

  /// التحقق من أن الملف يحتاج رفع
  bool needsUpload() {
    return status == StorageStatus.added ||
           status == StorageStatus.modified ||
           status == StorageStatus.moved ||
           status == StorageStatus.movedModeified ||
           status == StorageStatus.movedRenamed ||
           status == StorageStatus.renamed ||
           createdInThisSession == true;
  }

  /// التحقق من أن الملف موجود بالفعل في التخزين السحابي
  bool isAlreadyUploaded() {
    return path != null && 
           (path!.startsWith('http://') || 
            path!.startsWith('https://') ||
            path!.contains('/'));
  }

  /// طباعة معلومات الملف
  void printInfo() {
    print('📄 معلومات الملف:');
    print('📝 الاسم: $name');
    print('📍 المسار: $path');
    print('📊 الحجم: ${fileSize ?? 'غير محدد'} بايت');
    print('🔧 الامتداد: ${fileExtension ?? 'غير محدد'}');
    print('📋 الحالة: ${status.toString().split('.').last}');
    print('🆕 جديد في الجلسة: ${createdInThisSession ?? false}');
  }
}

/// ## نموذج بيانات النموذج
///
/// يمثل نموذج كامل مع جميع عناصر التحكم والملفات المرفقة
class FormModel {
  /// معرف النموذج
  int id;
  
  /// اسم النموذج
  String name;
  
  /// قائمة عناصر التحكم في النموذج
  List<ControlModel>? controls;
  
  /// معرف المستخدم
  int? userId;
  
  /// معرف التطبيق
  int? applicationId;
  
  /// تاريخ إنشاء النموذج
  DateTime? createdAt;
  
  /// تاريخ آخر تعديل
  DateTime? modifiedAt;
  
  /// حالة النموذج
  String? status;
  
  /// بيانات إضافية للنموذج
  Map<String, dynamic>? metadata;

  FormModel({
    required this.id,
    required this.name,
    this.controls,
    this.userId,
    this.applicationId,
    this.createdAt,
    this.modifiedAt,
    this.status,
    this.metadata,
  });

  /// إنشاء نموذج من JSON
  factory FormModel.fromJson(Map<String, dynamic> json) {
    List<ControlModel>? controlsList;
    if (json['controls'] != null) {
      controlsList = (json['controls'] as List)
          .map((e) => ControlModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return FormModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      controls: controlsList,
      userId: json['userId'],
      applicationId: json['applicationId'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      modifiedAt: json['modifiedAt'] != null ? DateTime.parse(json['modifiedAt']) : null,
      status: json['status'],
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
    );
  }

  /// تحويل النموذج إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'controls': controls?.map((e) => e.toJson()).toList(),
      'userId': userId,
      'applicationId': applicationId,
      'createdAt': createdAt?.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
      'status': status,
      'metadata': metadata,
    };
  }

  /// الحصول على جميع الملفات في النموذج
  List<FileModel> getAllFiles() {
    List<FileModel> files = [];
    
    for (var control in controls ?? []) {
      if (control.type == 7 && control.files != null) {
        files.addAll(control.files!);
      }
    }
    
    return files;
  }

  /// الحصول على الملفات التي تحتاج رفع
  List<FileModel> getFilesNeedingUpload() {
    return getAllFiles().where((file) => file.needsUpload()).toList();
  }

  /// طباعة معلومات النموذج
  void printInfo() {
    print('📋 معلومات النموذج:');
    print('🆔 المعرف: $id');
    print('📝 الاسم: $name');
    print('🎛️ عدد عناصر التحكم: ${controls?.length ?? 0}');
    print('📄 عدد الملفات: ${getAllFiles().length}');
    print('📤 ملفات تحتاج رفع: ${getFilesNeedingUpload().length}');
    print('👤 معرف المستخدم: ${userId ?? 'غير محدد'}');
    print('📱 معرف التطبيق: ${applicationId ?? 'غير محدد'}');
  }
}

/// ## نموذج عنصر التحكم المحدث
///
/// يمثل عنصر تحكم في النموذج مع دعم الملفات
class ControlModel {
  /// معرف عنصر التحكم
  int id;
  
  /// نوع عنصر التحكم
  int type;
  
  /// اسم عنصر التحكم
  String name;
  
  /// هل الحقل مطلوب؟
  bool requiredField;
  
  /// قيمة عنصر التحكم
  dynamic value;
  
  /// قائمة الخيارات (للقوائم المنسدلة)
  List<dynamic> options;
  
  /// نوع التاريخ (للحقول التاريخية)
  String? dateType;
  
  /// معرف الجدول (لأدوات الربط)
  int? tableId;
  
  /// المفاتيح الخارجية
  List<String> fks;
  
  /// بيانات إضافية
  Map<String, dynamic>? meta;
  
  /// عناصر التحكم الفرعية
  List<ControlModel> children;
  
  /// قائمة الملفات المرفقة (لعناصر التحكم من نوع ملف)
  List<FileModel>? files;

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
    this.files,
  });

  /// إنشاء عنصر تحكم من JSON
  factory ControlModel.fromJson(Map<String, dynamic> json) {
    // معالجة العناصر الفرعية
    List<ControlModel> parsedChildren = <ControlModel>[];
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

    // معالجة الملفات
    List<FileModel>? filesList;
    if (json['files'] != null) {
      filesList = (json['files'] as List)
          .map((e) => FileModel.fromJson(e as Map<String, dynamic>))
          .toList();
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
      meta: json['meta'] is Map
          ? Map<String, dynamic>.from(json['meta'] as Map)
          : null,
      children: parsedChildren,
      files: filesList,
    );
  }

  /// تحويل عنصر التحكم إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'required': requiredField,
      'value': value,
      'options': options,
      'DateType': dateType,
      'table_id': tableId,
      'fks': fks,
      'meta': meta,
      'children': children.map((e) => e.toJson()).toList(),
      'files': files?.map((e) => e.toJson()).toList(),
    };
  }

  /// تحويل نوع عنصر التحكم من نص إلى رقم
  static int _mapType(dynamic t) {
    if (t is int) return t;
    
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

  /// التحقق من أن عنصر التحكم من نوع ملف
  bool get isFileType => type == 7;

  /// التحقق من وجود ملفات مرفقة
  bool get hasFiles => files != null && files!.isNotEmpty;

  /// طباعة معلومات عنصر التحكم
  void printInfo() {
    print('🎛️ معلومات عنصر التحكم:');
    print('🆔 المعرف: $id');
    print('📝 الاسم: $name');
    print('🔢 النوع: $type');
    print('✅ مطلوب: $requiredField');
    print('📄 عدد الملفات: ${files?.length ?? 0}');
    print('🔗 عدد العناصر الفرعية: ${children.length}');
  }
}
