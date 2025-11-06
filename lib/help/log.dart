import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

/// A utility class for logging error messages into local files with rotation support.
///
/// Logs are stored under the app's documents directory in a subfolder named "Logs".
/// When the primary log file (API_Log.txt) exceeds 10 MB, it is renamed
/// sequentially (e.g., API_Log_1.txt) and a new primary log file is created.
class LogServices {
  // --- Constants for File Management ---
  static const String _folder_name = "Logs";
  static const String _base_file_name = "API_Log";
  static const String _file_extension = ".txt";
  static const String _file_name = "$_base_file_name$_file_extension"; // API_Log.txt
  static const int _max_file_size_bytes = 10 * 1024 * 1024; // 10 MB Limit

  /// Cached path to avoid repeated I/O on every log write.
  static String? _cachedPath;

  /// Writes a log entry asynchronously to the local file, checking for rotation.
  ///
  /// The log content will be prefixed with the current timestamp.
  /// Heavy I/O is offloaded using [compute] to prevent UI jank.
  ///
  /// - [errorContent]: The content/message to log.
  static Future<void> write(String errorContent) async {
    // This check ensures we only proceed if we're not running on the web
    // where dart:io is unavailable.
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
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
        // Log locally if file write failed
        debugPrint("Error in LogServices while attempting to write to log file: $e");
      }
    } else {
      // Fallback for non-supported platforms or web
      debugPrint("LogServices.write called on unsupported platform (Web/Desktop/etc): $errorContent");
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

/// Writes a log line to the appropriate file inside an isolate, handling rotation.
///
/// This keeps heavy file operations off the main thread.
Future<void> _writeInIsolate(_LogParams p) async {
  try {
    final logDir = Directory('${p.basePath}/${LogServices._folder_name}');
    // Ensure the log directory exists
    await logDir.create(recursive: true);

    final currentFilePath = '${logDir.path}/${LogServices._file_name}';
    final currentFile = File(currentFilePath);

    // 1. Check for file size and perform rotation if necessary
    if (await currentFile.exists()) {
      final size = await currentFile.length();

      if (size > LogServices._max_file_size_bytes) {
        debugPrint('Log file ${LogServices._file_name} size (${size / (1024 * 1024)} MB) exceeds limit. Starting rotation.');

        // Find the next available sequential index (1, 2, 3...)
        int rotationIndex = 1;
        String rotatedPath;
        do {
          rotatedPath =
              '${logDir.path}/${LogServices._base_file_name}_$rotationIndex${LogServices._file_extension}';
          rotationIndex++;
        } while (await File(rotatedPath).exists());

        // The target index is (rotationIndex - 1)
        final targetRotationPath =
            '${logDir.path}/${LogServices._base_file_name}_${rotationIndex - 1}${LogServices._file_extension}';

        // Rename API_Log.txt to API_Log_N.txt
        await currentFile.rename(targetRotationPath);
        debugPrint('Log file rotated to: $targetRotationPath');
      }
    }

    // 2. Append the new log line to the current file (which is API_Log.txt)
    await currentFile.writeAsString(p.line, mode: FileMode.append, flush: true);
  } catch (e) {
    // Cannot use debugPrint() here as it relies on Flutter's context, 
    // but in an isolate, we fall back to standard print/stderr.
    // However, since we are in a Flutter environment running compute, debugPrint 
    // might still work by routing back to the main thread's logging mechanism.
    debugPrint("FATAL: Error during isolate log writing or rotation: $e");
  }
}

// import 'dart:async';
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:intl/intl.dart';
// import 'package:flutter/foundation.dart';


// /// A utility class for logging error messages into local files.
// ///
// /// Logs are stored under the app's documents directory in a subfolder named "Logs",
// /// inside a file named "E_Log.txt". Each log entry is timestamped and written
// /// asynchronously using an isolate to avoid UI thread blocking.
// ///
// /// This class is ideal for capturing exception traces, debug messages,
// /// or backend response logs in a production-safe way.
// class LogServices {
//   static const String _folder_name = "Logs";
//   static const String _file_name = "API_Log.txt";

//   /// Cached path to avoid repeated I/O on every log write.
//   static String? _cachedPath;

//   /// Writes a log entry asynchronously to the local file.
//   ///
//   /// The log content will be prefixed with the current timestamp.
//   /// Heavy I/O is offloaded using [compute] to prevent UI jank.
//   ///
//   /// - [errorContent]: The content/message to log.
//   static Future<void> write(String errorContent) async {
//     try {
//       _cachedPath ??= await _findLocalPath();
//       final path = _cachedPath;
//       if (path == null) return;

//       final now = DateTime.now();
//       final timeStamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
//       final fullLine =
//           "***********************\nTime: [$timeStamp] $errorContent\n**************************************\n";

//       // Write log in background isolate to avoid blocking the main thread
//       unawaited(
//         compute<_LogParams, void>(_writeInIsolate, _LogParams(path, fullLine)),
//       );
//     } catch (e) {
//       const String errorMessage =
//           "Error in LogServices while attempting to write to log file.";
//       debugPrint(errorMessage);
//       // funcs.tostmsg(errorMessage);
//     }
//   }

//   /// Determines and returns the app's documents directory path.
//   ///
//   /// Returns `null` if access fails.
//   static Future<String?> _findLocalPath() async {
//     try {
//       final directory = await getApplicationDocumentsDirectory();
//       return directory.path;
//     } catch (e) {
//       debugPrint("Failed to get application documents directory: $e");
//       return null;
//     }
//   }
// }

// /// Internal class to wrap parameters passed to the isolate.
// class _LogParams {
//   final String basePath;
//   final String line;

//   _LogParams(this.basePath, this.line);
// }

// /// Writes a log line to the appropriate file inside an isolate.
// ///
// /// This keeps heavy file operations off the main thread.
// Future<void> _writeInIsolate(_LogParams p) async {
//   final logDir = Directory('${p.basePath}/${LogServices._folder_name}');
//   await logDir.create(recursive: true);

//   final file = File('${logDir.path}/${LogServices._file_name}');
//   await file.writeAsString(p.line, mode: FileMode.append, flush: true);
// }
