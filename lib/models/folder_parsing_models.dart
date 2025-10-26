/// Models for folder parsing and processing
class ParsedFolderName {
  /// Prefix: SA, AD, MK, etc (2 characters)
  final String prefix;

  /// Section: PM, PMT, PMTX, etc (2-4 characters)
  final String section;

  /// T flag: 'T' or null
  final String? tFlag;

  /// Number: 1-99999+
  final String number;

  /// Year: YYYY
  final String year;

  /// Formatted output: SA/PM/T/1234/2025
  final String formatted;

  /// Original folder name
  final String originalName;

  ParsedFolderName({
    required this.prefix,
    required this.section,
    this.tFlag,
    required this.number,
    required this.year,
    required this.formatted,
    required this.originalName,
  });

  Map<String, dynamic> toJson() => {
        'prefix': prefix,
        'section': section,
        'tFlag': tFlag,
        'number': number,
        'year': year,
        'formatted': formatted,
        'originalName': originalName,
      };

  @override
  String toString() => formatted;
}

/// Record for failed folder processing
class Record {
  /// Original folder name
  final String originalName;

  /// Parsed name if parsing succeeded, null if parsing failed
  final String? parsedName;

  /// Error message describing what went wrong
  final String errorMessage;

  /// Timestamp when the failure occurred
  final DateTime timestamp;

  /// Full path to the folder
  final String folderPath;
Record({
    required this.originalName,
    this.parsedName,
    required this.errorMessage,
    required this.timestamp,
    required this.folderPath,
  });

  Map<String, dynamic> toJson() => {
        'originalName': originalName,
        'parsedName': parsedName,
        'errorMessage': errorMessage,
        'timestamp': timestamp.toIso8601String(),
        'folderPath': folderPath,
      };

  factory Record.fromJson(Map<String, dynamic> json) => Record(
        originalName: json['originalName'] as String,
        parsedName: json['parsedName'] as String?,
        errorMessage: json['errorMessage'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        folderPath: json['folderPath'] as String,
      );
}

/// Container for multiple failure records
class FailuresData {
  final List<Record> failures;

  FailuresData({required this.failures});

  Map<String, dynamic> toJson() => {
        'failures': failures.map((f) => f.toJson()).toList(),
      };

  factory FailuresData.fromJson(Map<String, dynamic> json) => FailuresData(
        failures: (json['failures'] as List<dynamic>)
            .map((f) => Record.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
}

class SuccessData {
  final List<Record> successes;

  SuccessData({required this.successes});

  Map<String, dynamic> toJson() => {
        'successes': successes.map((s) => s.toJson()).toList(),
      };

  factory SuccessData.fromJson(Map<String, dynamic> json) => SuccessData(
        successes: (json['successes'] as List<dynamic>)
            .map((s) => Record.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
} 