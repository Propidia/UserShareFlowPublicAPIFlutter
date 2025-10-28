import 'dart:convert';
import 'dart:io';

import 'package:useshareflowpublicapiflutter/models/folder_parsing_models.dart';

/// Pure Dart store for persisting success and failure records to JSON files.
class RecordStore {
  final String failuresFilePath;
  final String successesFilePath;

  const RecordStore({
    required this.failuresFilePath,
    required this.successesFilePath,
  });

  Future<void> saveFailure(Record record) async {
    try {
      final file = File(failuresFilePath);
      FailuresData data;
      if (await file.exists()) {
        final content = await file.readAsString();
        try {
          final json = jsonDecode(content);
          data = FailuresData.fromJson(json as Map<String, dynamic>);
        } catch (_) {
          data = FailuresData(failures: []);
        }
      } else {
        data = FailuresData(failures: []);
      }

      data.failures.add(record);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data.toJson()),
      );
    } catch (_) {
      // Swallow errors to avoid crashing caller; controller may log
    }
  }

  Future<void> saveSuccess(Record record) async {
    try {
      final file = File(successesFilePath);
      SuccessData data;
      if (await file.exists()) {
        final content = await file.readAsString();
        try {
          final json = jsonDecode(content);
          data = SuccessData.fromJson(json as Map<String, dynamic>);
        } catch (_) {
          data = SuccessData(successes: []);
        }
      } else {
        data = SuccessData(successes: []);
      }

      data.successes.add(record);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data.toJson()),
      );
    } catch (_) {
      // Swallow errors to avoid crashing caller; controller may log
    }
  }

  Future<void> clearFailures() async {
    try {
      final file = File(failuresFilePath);
      final emptyData = FailuresData(failures: []);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(emptyData.toJson()),
      );
    } catch (_) {
      // Swallow errors
    }
  }
}


