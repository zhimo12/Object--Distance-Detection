import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/model_type.dart';

/// Fully-offline ModelManager (Android only): copies .tflite from assets → documents dir on first use.
class ModelManager {
  final void Function(String message)? onStatusUpdate;
  ModelManager({this.onStatusUpdate});

  /// Returns the filesystem path to the requested .tflite model,
  /// copying it from bundled assets on first run.
  Future<String?> getModelPath(ModelType modelType) async {
    final modelName = modelType.modelName;
    final docsDir = await getApplicationDocumentsDirectory();
    final destPath = '${docsDir.path}/$modelName.tflite';

    // Already copied? Return immediately.
    if (await File(destPath).exists()) {
      _updateStatus('Using cached model: $modelName');
      return destPath;
    }

    // Copy from bundled asset → documents directory
    try {
      _updateStatus('Copying bundled model: $modelName');

      final byteData =
          await rootBundle.load('assets/models/$modelName.tflite');
      final bytes = byteData.buffer.asUint8List();

      final outFile = File(destPath);
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(bytes, flush: true);

      _updateStatus('Model ready: $modelName');
      return destPath;
    } catch (e) {
      _updateStatus('Error copying model: $e');
      return null;
    }
  }

  /// Deletes all copied models from the documents directory.
  Future<void> clearCache() async {
    final docsDir = await getApplicationDocumentsDirectory();
    for (final mt in ModelType.values) {
      final path = '${docsDir.path}/${mt.modelName}.tflite';
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        _updateStatus('Deleted cached model: ${mt.modelName}');
      }
    }
    _updateStatus('All caches cleared');
  }

  void _updateStatus(String msg) {
    debugPrint('ModelManager: $msg');
    onStatusUpdate?.call(msg);
  }
}
