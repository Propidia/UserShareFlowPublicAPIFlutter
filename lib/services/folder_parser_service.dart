import '../models/folder_parsing_models.dart';

/// Service for parsing folder names according to the pattern:
/// Pattern: XX + (XX-XXXX) + (T?) + (1-99999+) + (YYYY)
/// 
/// Examples:
/// - SAPMT12342025 → SA/PM/T/1234/2025
/// - SAPM12342025 → SA/PM/1234/2025
/// - IBBPMT12342025 → IBB/PM/T/1234/2025 (IBB is special 3-letter prefix)
/// 
/// Important:
/// - T is a FLAG, not part of section
/// - T flag only recognized when followed by a digit
/// - IBB is the only city with 3-letter prefix
class FolderParserService {
  /// Attempts to parse a folder name according to the pattern
  /// Returns null if the name doesn't match the pattern
  /// 
  /// Special cases:
  /// - IBB is the only city with 3-letter prefix
  /// - T is a flag, not part of section
  ParsedFolderName? parseFolderName(String folderName,{String? department}) {
    try {
      // Validate minimum length
      if (folderName.length < 9) {
        // Minimum: XX + XX + 1 + YYYY = 9 chars
        return null;
      }

      int position = 0;

      // 1. Extract prefix (2 characters, or 3 for IBB exception)
      String prefix;
      if (folderName.startsWith('IBB') && folderName.length >= 3) {
        // Special case: IBB has 3-letter prefix
        prefix = folderName.substring(0, 3);
        position = 3;
      } else {
        // Normal case: 2-letter prefix
        if (position + 2 > folderName.length) return null;
        prefix = folderName.substring(position, position + 2);
        if (!_isAllLetters(prefix)) return null;
        position += 2;
      }

      // 2. Extract section (2-4 letters, but NOT including T flag)
      String section = '';
      int sectionLength = 0;
      for (int i = 0; i < 4 && position + i < folderName.length; i++) {
        final char = folderName[position + i];
        if (_isLetter(char)) {
          // Check if this might be the T flag (T followed by digit)
          if (char == 'T' && 
              position + i + 1 < folderName.length && 
              _isDigit(folderName[position + i + 1])) {
            // This is likely the T flag, stop here
            break;
          }
          section += char;
          sectionLength++;
        } else {
          break;
        }
      }

      if (sectionLength < 2 || sectionLength > 4) return null;
      position += sectionLength;

      // 3. Check for optional 'T' flag (only if followed by a digit)
      String? tFlag;
      if (position < folderName.length && 
          folderName[position] == 'T' &&
          position + 1 < folderName.length &&
          _isDigit(folderName[position + 1])) {
        tFlag = 'T';
        position++;
      }

      // 4. Extract number (digits until we find year - last 4 digits)
      // We need to ensure we have at least 4 digits left for the year
      if (folderName.length - position < 5) {
        // Need at least 1 digit for number + 4 for year
        return null;
      }

      // Find where the year starts (last 4 characters should be year)
      final yearStartPos = folderName.length - 4;
      final year = folderName.substring(yearStartPos);

      // Validate year is 4 digits
      if (!_isAllDigits(year)) return null;

      // Extract number (everything between current position and year)
      final number = folderName.substring(position, yearStartPos);

      // Validate number contains only digits
      if (number.isEmpty || !_isAllDigits(number)) return null;

      // Build formatted string
      final parts = <String>[prefix, section];
      if (tFlag != null) parts.add(tFlag);
      parts.addAll([number, year]);
      final formatted = parts.join('/');

      return ParsedFolderName(
        prefix: prefix,
        section: section,
        tFlag: tFlag,
        number: number,
        year: year,
        formatted: formatted,
        originalName: folderName,
      );
    } catch (e) {
      // If any error occurs during parsing, return null
      return null;
    }
  }

  /// Checks if a string contains only letters
  bool _isAllLetters(String str) {
    if (str.isEmpty) return false;
    return RegExp(r'^[a-zA-Z]+$').hasMatch(str);
  }

  /// Checks if a single character is a letter
  bool _isLetter(String char) {
    return RegExp(r'^[a-zA-Z]$').hasMatch(char);
  }

  /// Checks if a single character is a digit
  bool _isDigit(String char) {
    return RegExp(r'^\d$').hasMatch(char);
  }

  /// Checks if a string contains only digits
  bool _isAllDigits(String str) {
    if (str.isEmpty) return false;
    return RegExp(r'^\d+$').hasMatch(str);
  }

  /// Validates that a parsed result makes sense
  bool validateParsedName(ParsedFolderName parsed) {
    // Prefix should be 2 letters (or 3 for IBB)
    if (parsed.prefix == 'IBB') {
      if (parsed.prefix.length != 3) return false;
    } else {
      if (parsed.prefix.length != 2) return false;
    }

    // Section should be 2-4 letters
    if (parsed.section.length < 2 || parsed.section.length > 4) return false;

    // Year should be 4 digits
    if (parsed.year.length != 4) return false;

    // Number should be at least 1 digit
    if (parsed.number.isEmpty) return false;

    return true;
  }
}









// import '../models/folder_parsing_models.dart';

// /// Refactor: pattern-driven FolderParserService
// /// - لكل قسم (department) قائمة أنماط (regex strings)
// /// - كل regex يجب أن يستخدم مجموعات التقاط ترتيبية بالترتيب:
// ///   1) prefix, 2) section, 3) tFlag (optional, or empty), 4) number, 5) year
// /// - الأمثلة المرفقة تُظهر كيفية تمثيل حالات مثل IBB و T-followed-by-digit
// class FolderParserService {
//   /// خريطة: اسم القسم -> قائمة أنماط (regex strings)
//   /// كل regex يبدأ بـ ^ وينتهي بـ $ لضمان مطابقة الكل.
//   /// لاحظ: نستخدم مجموعات التقاط ترتيبية (Dart RegExp لا تدعم named groups).
//   final Map<String, List<String>> departmentPatterns = {
//     // قسم التأمين (أمثلة من سؤالك)
//     'سيارات_تكافلي': [
//         // ([A-Z]{2}) ثم section 2-4 أحرف لكن نضمن أن يلي section إما T+digit أو digit (lookahead)
//       r'^([A-Z]{2})([A-Z]{2,4})(?=T?\d)(T(?=\d))?(\d+)(\d{4})$',
//       r'^(SA)(CVC)(?=T?\d)(T(?=\d))?(\d+)(\d{4})$',
//       r'^(IBB|[A-Z]{2})([A-Z]{2,4})(?=T?\d)(T(?=\d))?(\d+)(\d{4})$',
//     ],
//     // مثال لقسم ثاني (مثال: TZ/FR/2415/2020)
//     'other': [
//       r'^(TZ)(FR)(\d+)(\d{4})$', // هنا ما في T flag، فالمجموعة الثالثة = number
//       // إذا أردنا نفس الترتيب العام (prefix, section, tFlag?, number, year)
//       r'^(TZ)(FR)(T(?=\d))?(\d+)(\d{4})$',
//     ],
//     // تصاميم عامة/افتراضية تحاول التقاط الأنماط الشائعة
//     'default': [
//       r'^(IBB|[A-Z]{2})([A-Z]{2,4})(T(?=\d))?(\d+)(\d{4})$',
//     ],
//   };

//   /// لو حاب تربط نمط معين لقسم ديناميكيًا:
//   void addPatternForDepartment(String dept, String regex) {
//     departmentPatterns.putIfAbsent(dept, () => []);
//     departmentPatterns[dept]!.insert(0, regex); // أدرج بنقطة أعلى الأسبقية
//   }

//   /// يحاول تحليل اسم باستخدام أنماط القسم المحدد أولًا ثم الافتراضي
//   ParsedFolderName? parseFolderName(String folderName, {String? department}) {
//     final name = folderName.trim().toUpperCase();

//     // تحضير قائمة أنماط مراد تجربتها (أولوية للقسم لو موجود)
//     final List<String> patternsToTry = [];
//     if (department != null && departmentPatterns.containsKey(department)) {
//       patternsToTry.addAll(departmentPatterns[department]!);
//     }
//     // ثم الأنماط العامة
//     if (departmentPatterns.containsKey('default')) {
//       patternsToTry.addAll(departmentPatterns['default']!);
//     }
//     // أخيراً جميع أنماط باقي الأقسام كـ fallback
//     for (final entry in departmentPatterns.entries) {
//       if (entry.key == department || entry.key == 'default') continue;
//       for (final p in entry.value) {
//         if (!patternsToTry.contains(p)) patternsToTry.add(p);
//       }
//     }

//     for (final pat in patternsToTry) {
//       final reg = RegExp(pat);
//       final m = reg.firstMatch(name);
//       if (m != null) {
//         // حسب الاتفاق: مجموعات التقاط يجب أن تكون في ترتيب:
//         // 1 prefix, 2 section, 3 tFlag (قد تكون مجموعة فارغة أو غير موجودة), 4 number, 5 year
//         // لكن بعض regex لقسم معين قد لا تحتوي على المجموعة الثالثة (تختلف بنمط)
//         // فسنتعامل مع طول المجموعات الموجود.
//         try {
//           String prefix = '';
//           String section = '';
//           String? tFlag;
//           String number = '';
//           String year = '';

//           // المجموعات متاحة عبر groupCount و group(n)
//           final gc = m.groupCount;
//           if (gc >= 2) {
//             prefix = m.group(1) ?? '';
//             section = m.group(2) ?? '';
//           }

//           if (gc == 4) {
//             // نمط بدون tFlag: (1)prefix (2)section (3)number (4)year
//             number = m.group(3) ?? '';
//             year = m.group(4) ?? '';
//           } else if (gc >= 5) {
//             // نمط مع tFlag: (1)prefix (2)section (3)tFlag? (4)number (5)year
//             final maybeT = m.group(3);
//             if (maybeT != null && maybeT.isNotEmpty) {
//               tFlag = maybeT;
//             }
//             number = m.group(4) ?? '';
//             year = m.group(5) ?? '';
//           } else {
//             // حالات أخرى: نحاول تعيين من الخلف (last 4 chars = year)
//             final whole = name;
//             if (whole.length >= 4) {
//               year = whole.substring(whole.length - 4);
//               final beforeYear = whole.substring(0, whole.length - 4);
//               // نحاول استخراج prefix & section & t من البداية بطريقة بسيطة
//               final simple = _simpleSplitPrefixSection(beforeYear);
//               prefix = simple['prefix'] ?? '';
//               section = simple['section'] ?? '';
//               tFlag = simple['t'] ?? null;
//               number = simple['number'] ?? '';
//             }
//           }

//           // تحقق أساسي
//           if (prefix.isEmpty || section.length < 2 || year.length != 4 || number.isEmpty) {
//             // لو فشل التحقق تابع لنمط آخر
//             continue;
//           }

//           final formattedParts = <String>[prefix, section];
//           if (tFlag != null) formattedParts.add(tFlag);
//           formattedParts.addAll([number, year]);
//           final formatted = formattedParts.join('/');

//           return ParsedFolderName(
//             prefix: prefix,
//             section: section,
//             tFlag: tFlag,
//             number: number,
//             year: year,
//             formatted: formatted,
//             originalName: folderName,
//           );
//         } catch (e) {
//           // تجاهل وحاول النمط التالي
//           continue;
//         }
//       }
//     }

//     // لو ما لقى أي نمط
//     return null;
//   }

//   /// مساعدة بسيطة لاستخراج prefix/section/number عندما لا تتوافق المجموعات
//   Map<String, String?> _simpleSplitPrefixSection(String s) {
//     // محاولة بسيطة: إذا يبدأ بـ IBB خذه ثلاثي، وإلا خذه اثنين
//     String prefix = '';
//     String section = '';
//     String? t;
//     String number = '';

//     if (s.startsWith('IBB')) {
//       prefix = 'IBB';
//       s = s.substring(3);
//     } else if (s.length >= 2) {
//       prefix = s.substring(0, 2);
//       s = s.substring(2);
//     }

//     // تحقق من وجود T كعلم قبل الأرقام
//     final tIndex = s.indexOf('T');
//     if (tIndex != -1) {
//       // تأكد أن يليها رقم
//       if (tIndex + 1 < s.length && RegExp(r'^\d').hasMatch(s[tIndex + 1])) {
//         t = 'T';
//         section = s.substring(0, tIndex);
//         number = s.substring(tIndex + 1);
//       } else {
//         // T جزء من section
//         // حاول أخذ أول 2-4 حروف كـ section
//         final secLen = s.length >= 4 ? 4 : (s.length >= 2 ? 2 : s.length);
//         section = s.substring(0, secLen);
//         number = s.substring(secLen);
//       }
//     } else {
//       // لا T: خذ section 2-4 أحرف
//       final secLen = s.length >= 4 ? 4 : (s.length >= 2 ? 2 : s.length);
//       section = s.substring(0, secLen);
//       number = s.substring(secLen);
//     }

//     return {
//       'prefix': prefix,
//       'section': section,
//       't': t,
//       'number': number,
//     };
//   }
// }
