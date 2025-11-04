import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';


/// A utility class for logging error messages into local files.
///
/// Logs are stored under the app's documents directory in a subfolder named "Logs",
/// inside a file named "E_Log.txt". Each log entry is timestamped and written
/// asynchronously using an isolate to avoid UI thread blocking.
///
/// This class is ideal for capturing exception traces, debug messages,
/// or backend response logs in a production-safe way.
class LogServices {
  static const String _folder_name = "Logs";
  static const String _file_name = "API_Log.txt";

  /// Cached path to avoid repeated I/O on every log write.
  static String? _cachedPath;

  /// Writes a log entry asynchronously to the local file.
  ///
  /// The log content will be prefixed with the current timestamp.
  /// Heavy I/O is offloaded using [compute] to prevent UI jank.
  ///
  /// - [errorContent]: The content/message to log.
  static Future<void> write(String errorContent) async {
    try {
      _cachedPath ??= await _findLocalPath();
      final path = _cachedPath;
      if (path == null) return;

      final now = DateTime.now();
      final timeStamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      final fullLine =
          "***********************\nTime: [$timeStamp] $errorContent\n**************************************\n";

      // Write log in background isolate to avoid blocking the main thread
      unawaited(
        compute<_LogParams, void>(_writeInIsolate, _LogParams(path, fullLine)),
      );
    } catch (e) {
      const String errorMessage =
          "Error in LogServices while attempting to write to log file.";
      debugPrint(errorMessage);
      // funcs.tostmsg(errorMessage);
    }
  }

  /// Determines and returns the app's documents directory path.
  ///
  /// Returns `null` if access fails.
  static Future<String?> _findLocalPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      debugPrint("Failed to get application documents directory: $e");
      return null;
    }
  }
}

/// Internal class to wrap parameters passed to the isolate.
class _LogParams {
  final String basePath;
  final String line;

  _LogParams(this.basePath, this.line);
}

/// Writes a log line to the appropriate file inside an isolate.
///
/// This keeps heavy file operations off the main thread.
Future<void> _writeInIsolate(_LogParams p) async {
  final logDir = Directory('${p.basePath}/${LogServices._folder_name}');
  await logDir.create(recursive: true);

  final file = File('${logDir.path}/${LogServices._file_name}');
  await file.writeAsString(p.line, mode: FileMode.append, flush: true);
}
