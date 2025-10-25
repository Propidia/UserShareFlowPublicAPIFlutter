import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/folder_parsing_models.dart';
import '../services/folder_parser_service.dart';
import '../services/api_client.dart';

/// Controller for processing folders and their subfolders
class FolderProcessingController extends GetxController {
  final _parserService = FolderParserService();
  final _apiClient = ApiClient.instance;

  // Observable state
  final isProcessing = false.obs;
  final processedCount = 0.obs;
  final successCount = 0.obs;
  final failureCount = 0.obs;

  /// Path to failures.json file
  String? _failuresFilePath;

  @override
  void onInit() {
    super.onInit();
    _initFailuresFile();
  }

  /// Initialize failures.json file path
  Future<void> _initFailuresFile() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dataDir = Directory('${appDir.path}/data');

      // Create data directory if it doesn't exist
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }

      _failuresFilePath = '${dataDir.path}/failures.json';

      // Create failures.json if it doesn't exist
      final failuresFile = File(_failuresFilePath!);
      if (!await failuresFile.exists()) {
        final emptyData = FailuresData(failures: []);
        await failuresFile.writeAsString(jsonEncode(emptyData.toJson()));
      }
    } catch (e) {
      print('Error initializing failures file: $e');
    }
  }

  /// Main method: Pick a folder and process all subfolders
  Future<void> pickAndProcessFolder() async {
    try {
      // Pick directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        _showSnackBar('لم يتم اختيار أي مجلد', false);
        return;
      }

      // Start processing
      await processFolder(Directory(selectedDirectory));
    } catch (e) {
      _showSnackBar('خطأ في اختيار المجلد: $e', false);
    }
  }

  /// Process a folder and all its subfolders
  Future<void> processFolder(Directory folder) async {
    try {
      isProcessing.value = true;
      processedCount.value = 0;
      successCount.value = 0;
      failureCount.value = 0;

      // Get all subdirectories
      final subdirs = folder
          .listSync()
          .whereType<Directory>()
          .toList();

      if (subdirs.isEmpty) {
        _showSnackBar('لا توجد مجلدات فرعية للمعالجة', false);
        isProcessing.value = false;
        return;
      }

      _showSnackBar('بدء معالجة ${subdirs.length} مجلد...', true);

      // Process each subfolder
      for (final subdir in subdirs) {
        await processSingleSubfolder(subdir);
        processedCount.value++;
      }

      // Show final summary
      _showSnackBar(
        'اكتملت المعالجة: ${successCount.value} نجح، ${failureCount.value} فشل',
        successCount.value > 0,
      );
    } catch (e) {
      _showSnackBar('خطأ في معالجة المجلدات: $e', false);
    } finally {
      isProcessing.value = false;
    }
  }

  /// Process a single subfolder
  Future<void> processSingleSubfolder(Directory subfolder) async {
    final folderName = subfolder.path.split(Platform.pathSeparator).last;

    try {
      // Step 1: Parse folder name
      final parsed = _parserService.parseFolderName(folderName);

      if (parsed == null) {
        // Parsing failed - invalid pattern
        await _saveFailure(FailureRecord(
          originalName: folderName,
          parsedName: null,
          errorMessage: 'اسم المجلد لا يتطابق مع النمط المطلوب',
          timestamp: DateTime.now(),
          folderPath: subfolder.path,
        ));
        _showSnackBar('⚠️ نمط غير صحيح: $folderName', false);
        failureCount.value++;
        return;
      }

      // Step 2: Send to API
      try {
        await _apiClient.getFirstMatch(parsed.formatted);

        // Success
        _showSnackBar('✅ نجح: ${parsed.formatted}', true);
        successCount.value++;
      } catch (apiError) {
        // API call failed
        await _saveFailure(FailureRecord(
          originalName: folderName,
          parsedName: parsed.formatted,
          errorMessage: apiError.toString(),
          timestamp: DateTime.now(),
          folderPath: subfolder.path,
        ));
        _showSnackBar('❌ فشل API: ${parsed.formatted}', false);
        failureCount.value++;
      }
    } catch (e) {
      // Unexpected error
      await _saveFailure(FailureRecord(
        originalName: folderName,
        parsedName: null,
        errorMessage: 'خطأ غير متوقع: ${e.toString()}',
        timestamp: DateTime.now(),
        folderPath: subfolder.path,
      ));
      _showSnackBar('⚠️ خطأ: $folderName', false);
      failureCount.value++;
    }
  }

  /// Save failure record to failures.json
  Future<void> _saveFailure(FailureRecord record) async {
    try {
      if (_failuresFilePath == null) {
        print('Failures file path not initialized');
        return;
      }

      final file = File(_failuresFilePath!);

      // Read existing data
      FailuresData data;
      if (await file.exists()) {
        final content = await file.readAsString();
        try {
          final json = jsonDecode(content);
          data = FailuresData.fromJson(json as Map<String, dynamic>);
        } catch (e) {
          // If parsing fails, start with empty data
          data = FailuresData(failures: []);
        }
      } else {
        data = FailuresData(failures: []);
      }

      // Add new failure
      data.failures.add(record);

      // Write back to file
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data.toJson()),
      );
    } catch (e) {
      print('Error saving failure: $e');
    }
  }

  /// Show snackbar with message
  void _showSnackBar(String message, bool isSuccess) {
    Get.snackbar(
      isSuccess ? 'نجاح' : 'فشل',
      message,
      backgroundColor: isSuccess ? Colors.green.withOpacity(0.9) : Colors.red.withOpacity(0.9),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(8),
    );
  }

  /// Get path to failures.json for viewing
  String? get failuresFilePath => _failuresFilePath;

  /// Clear all failures
  Future<void> clearFailures() async {
    try {
      if (_failuresFilePath == null) return;

      final file = File(_failuresFilePath!);
      final emptyData = FailuresData(failures: []);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(emptyData.toJson()),
      );

      _showSnackBar('تم مسح سجل الفشل', true);
    } catch (e) {
      _showSnackBar('خطأ في مسح سجل الفشل: $e', false);
    }
  }
}

