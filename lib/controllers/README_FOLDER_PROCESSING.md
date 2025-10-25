# Folder Processing Feature

## نظرة عامة
هذه الميزة تسمح بمعالجة دفعية للمجلدات الفرعية، حيث يتم:
1. اختيار مجلد أب
2. معالجة جميع المجلدات الفرعية
3. تحليل أسماء المجلدات حسب نمط محدد
4. إرسال الأسماء المحللة إلى API
5. عرض النتائج في SnackBar
6. حفظ الفشل في ملف JSON

## النمط المدعوم
الأسماء يجب أن تتبع هذا النمط:

```
[2 أحرف][2-4 أحرف][T اختياري][1+ رقم][4 أرقام للسنة]
```

### أمثلة صحيحة:
- `SAPMT12342025` → `SA/PM/T/1234/2025`
- `SAPM12342025` → `SA/PM/1234/2025`
- `ADPMX11112024` → `AD/PMX/1111/2024`
- `MKPMTXT99992023` → `MK/PMTX/T/9999/2023`
- `SAPM12022` → `SA/PM/1/2022`

### أمثلة غير صحيحة:
- `SAPM123` - قصير جداً
- `S1PMT12342025` - البادئة تحتوي على رقم
- `SAP12342025` - القسم قصير جداً (يجب 2-4 أحرف)
- `SAPMT1234202` - السنة ليست 4 أرقام

## الملفات المتضمنة

### Models
- `lib/models/folder_parsing_models.dart`
  - `ParsedFolderName` - البيانات المحللة من اسم المجلد
  - `FailureRecord` - سجل فشل واحد
  - `FailuresData` - حاوية لجميع سجلات الفشل

### Services
- `lib/services/folder_parser_service.dart`
  - يحلل أسماء المجلدات حسب النمط
  - يتحقق من صحة البيانات

### Controllers
- `lib/controllers/folder_processing_controller.dart`
  - يدير عملية المعالجة الدفعية
  - يتعامل مع اختيار المجلد
  - يحفظ سجلات الفشل

### API
- تم إضافة `getFirstMatch()` في `lib/services/api_client.dart`

## ملف الفشل
يتم حفظ الفشل في:
```
{Application Documents Directory}/data/failures.json
```

### هيكل ملف failures.json:
```json
{
  "failures": [
    {
      "originalName": "SAPMT12342025",
      "parsedName": "SA/PM/T/1234/2025",
      "errorMessage": "API returned 404",
      "timestamp": "2025-10-25T14:30:00.000Z",
      "folderPath": "C:/Users/..."
    }
  ]
}
```

## الاستخدام

### في UI:
1. افتح شاشة النموذج الديناميكي
2. اضغط على زر "معالجة مجلد" في الأعلى
3. اختر المجلد الأب
4. انتظر حتى تكتمل المعالجة
5. ستظهر رسائل SnackBar لكل مجلد:
   - ✅ أخضر للنجاح
   - ❌ أحمر للفشل

### برمجياً:
```dart
// Initialize controller
final controller = Get.put(FolderProcessingController());

// Pick and process folder
await controller.pickAndProcessFolder();

// Or process specific folder
await controller.processFolder(Directory('/path/to/folder'));

// Clear failures
await controller.clearFailures();
```

## Unit Tests
Tests في: `test/folder_parser_test.dart`

لتشغيل الاختبارات:
```bash
flutter test test/folder_parser_test.dart
```

## التعامل مع الأخطاء

### أنواع الفشل:
1. **فشل التحليل**: الاسم لا يطابق النمط
   - يتم حفظه مع `parsedName: null`

2. **فشل API**: التحليل نجح لكن API فشل
   - يتم حفظه مع الاسم المحلل

3. **خطأ غير متوقع**: أي خطأ آخر
   - يتم حفظه مع وصف الخطأ

### المعالجة المستمرة:
- عند فشل مجلد واحد، تستمر المعالجة للمجلدات الأخرى
- لا يتوقف البرنامج عند الفشل

## الإحصائيات
خلال المعالجة، يتم تتبع:
- `processedCount` - عدد المجلدات المعالجة
- `successCount` - عدد النجاحات
- `failureCount` - عدد الفشل

## الملاحظات
- يدعم جميع المنصات (Windows, Linux, macOS, Android, iOS)
- يستخدم GetX للإدارة التفاعلية
- يحفظ الفشل في JSON منسق للقراءة السهلة
- يعرض تقدم المعالجة في الوقت الفعلي

