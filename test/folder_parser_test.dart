import 'package:flutter_test/flutter_test.dart';
import 'package:useshareflowpublicapiflutter/services/folder_parser_service.dart';

void main() {
  late FolderParserService parserService;

  setUp(() {
    parserService = FolderParserService();
  });

  group('FolderParserService Tests', () {
    test('Parse valid folder name with T flag', () {
      // SAPMT12342025 → SA/PM/T/1234/2025
      final result = parserService.parseFolderName('SAPMT12342025');

      expect(result, isNotNull);
      expect(result!.prefix, equals('SA'));
      expect(result.section, equals('PM'));
      expect(result.tFlag, equals('T'));
      expect(result.number, equals('1234'));
      expect(result.year, equals('2025'));
      expect(result.formatted, equals('SA/PM/T/1234/2025'));
    });

    test('Parse valid folder name without T flag', () {
      // SAPM12342025 → SA/PM/1234/2025
      final result = parserService.parseFolderName('SAPM12342025');

      expect(result, isNotNull);
      expect(result!.prefix, equals('SA'));
      expect(result.section, equals('PM'));
      expect(result.tFlag, isNull);
      expect(result.number, equals('1234'));
      expect(result.year, equals('2025'));
      expect(result.formatted, equals('SA/PM/1234/2025'));
    });

    test('Parse folder with 3-letter section', () {
      // ADPMX11112024 → AD/PMX/1111/2024
      final result = parserService.parseFolderName('ADPMX11112024');

      expect(result, isNotNull);
      expect(result!.prefix, equals('AD'));
      expect(result.section, equals('PMX'));
      expect(result.tFlag, isNull);
      expect(result.number, equals('1111'));
      expect(result.year, equals('2024'));
      expect(result.formatted, equals('AD/PMX/1111/2024'));
    });

    test('Parse folder with 4-letter section and T flag', () {
      // MKPMTXT99992023 → MK/PMTX/T/9999/2023
      final result = parserService.parseFolderName('MKPMTXT99992023');

      expect(result, isNotNull);
      expect(result!.prefix, equals('MK'));
      expect(result.section, equals('PMTX'));
      expect(result.tFlag, equals('T'));
      expect(result.number, equals('9999'));
      expect(result.year, equals('2023'));
      expect(result.formatted, equals('MK/PMTX/T/9999/2023'));
    });

    test('Parse folder with single digit number', () {
      // SAPM12022 → SA/PM/1/2022
      final result = parserService.parseFolderName('SAPM12022');

      expect(result, isNotNull);
      expect(result!.prefix, equals('SA'));
      expect(result.section, equals('PM'));
      expect(result.tFlag, isNull);
      expect(result.number, equals('1'));
      expect(result.year, equals('2022'));
      expect(result.formatted, equals('SA/PM/1/2022'));
    });

    test('Parse folder with large number', () {
      // SAPMT999992025 → SA/PM/T/99999/2025
      final result = parserService.parseFolderName('SAPMT999992025');

      expect(result, isNotNull);
      expect(result!.prefix, equals('SA'));
      expect(result.section, equals('PM'));
      expect(result.tFlag, equals('T'));
      expect(result.number, equals('99999'));
      expect(result.year, equals('2025'));
      expect(result.formatted, equals('SA/PM/T/99999/2025'));
    });

    test('Parse IBB (3-letter prefix exception) with T flag', () {
      // IBBPMT12342025 → IBB/PM/T/1234/2025
      final result = parserService.parseFolderName('IBBPMT12342025');

      expect(result, isNotNull);
      expect(result!.prefix, equals('IBB'));
      expect(result.section, equals('PM'));
      expect(result.tFlag, equals('T'));
      expect(result.number, equals('1234'));
      expect(result.year, equals('2025'));
      expect(result.formatted, equals('IBB/PM/T/1234/2025'));
    });

    test('Parse IBB without T flag', () {
      // IBBPM12342025 → IBB/PM/1234/2025
      final result = parserService.parseFolderName('IBBPM12342025');

      expect(result, isNotNull);
      expect(result!.prefix, equals('IBB'));
      expect(result.section, equals('PM'));
      expect(result.tFlag, isNull);
      expect(result.number, equals('1234'));
      expect(result.year, equals('2025'));
      expect(result.formatted, equals('IBB/PM/1234/2025'));
    });

    test('Parse IBB with 3-letter section', () {
      // IBBPMXT12342025 → IBB/PMX/T/1234/2025
      final result = parserService.parseFolderName('IBBPMXT12342025');

      expect(result, isNotNull);
      expect(result!.prefix, equals('IBB'));
      expect(result.section, equals('PMX'));
      expect(result.tFlag, equals('T'));
      expect(result.number, equals('1234'));
      expect(result.year, equals('2025'));
      expect(result.formatted, equals('IBB/PMX/T/1234/2025'));
    });

    test('T should be flag, not part of section (PMT with T flag)', () {
      // SAPMTT12342025 should parse as SA/PMT/T/1234/2025, not SA/PM/TT/1234/2025
      // But based on logic, PMT is section, then T is flag
      final result = parserService.parseFolderName('SAPMTT12342025');

      expect(result, isNotNull);
      expect(result!.prefix, equals('SA'));
      expect(result.section, equals('PMT'));
      expect(result.tFlag, equals('T'));
      expect(result.number, equals('1234'));
      expect(result.year, equals('2025'));
      expect(result.formatted, equals('SA/PMT/T/1234/2025'));
    });

    test('Reject folder name that is too short', () {
      final result = parserService.parseFolderName('SAPM123');
      expect(result, isNull);
    });

    test('Reject folder name with invalid prefix (contains digits)', () {
      final result = parserService.parseFolderName('S1PMT12342025');
      expect(result, isNull);
    });

    test('Reject folder name with section too short', () {
      final result = parserService.parseFolderName('SAP12342025');
      expect(result, isNull);
    });

    test('Reject folder name with invalid year (not 4 digits)', () {
      final result = parserService.parseFolderName('SAPMT1234202');
      expect(result, isNull);
    });

    test('Reject folder name with non-numeric number', () {
      final result = parserService.parseFolderName('SAPMTABC2025');
      expect(result, isNull);
    });

    test('Reject folder name with non-numeric year', () {
      final result = parserService.parseFolderName('SAPMT1234ABCD');
      expect(result, isNull);
    });

    test('Reject empty folder name', () {
      final result = parserService.parseFolderName('');
      expect(result, isNull);
    });

    test('Validate correctly parsed name', () {
      final result = parserService.parseFolderName('SAPMT12342025');
      expect(result, isNotNull);
      expect(parserService.validateParsedName(result!), isTrue);
    });

    // Patterns for Currency (USD, YER, SAR)
    test('Parse Currency Pattern USD -> SA/USD', () {
      final result = parserService.parseFolderName('USD12342020');
      expect(result, isNotNull);
      expect(result!.prefix, equals('USD'));
      expect(result.formatted, equals('SA/USD/1234/2020'));
      expect(parserService.validateParsedName(result), isTrue);
    });

    test('Parse Currency Pattern YER -> SA/YER', () {
      final result = parserService.parseFolderName('YER12342020');
      expect(result, isNotNull);
      expect(result!.prefix, equals('YER'));
      expect(result.formatted, equals('SA/YER/1234/2020'));
      expect(parserService.validateParsedName(result), isTrue);
    });

    test('Parse Currency Pattern SAR -> SA/SAR', () {
      final result = parserService.parseFolderName('SAR12342023');
      expect(result, isNotNull);
      expect(result!.prefix, equals('SAR'));
      expect(result.formatted, equals('SA/SAR/1234/2023'));
      expect(parserService.validateParsedName(result), isTrue);
    });

    test('Parse Currency Pattern USD with T flag -> SA/USD/T', () {
      final result = parserService.parseFolderName('USDT12342023');
      expect(result, isNotNull);
      expect(result!.prefix, equals('USD'));
      expect(result.tFlag, equals('T'));
      expect(result.formatted, equals('SA/USD/T/1234/2023'));
      expect(parserService.validateParsedName(result), isTrue);
    });
  });
}
