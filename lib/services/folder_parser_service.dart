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
  ParsedFolderName? parseFolderName(String folderName) {
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

