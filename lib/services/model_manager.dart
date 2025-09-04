import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/model_type.dart';

/// Fully-offline ModelManager: copies from assets → documents dir on first use.
class ModelManager {
  final void Function(String message)? onStatusUpdate;
  ModelManager({this.onStatusUpdate});

  /// Returns the filesystem path to the requested model,
  /// copying it from bundled assets on first run.
  Future<String?> getModelPath(ModelType modelType) async {
    final modelName = modelType.modelName;

    // Android: single .tflite; iOS: zipped .mlpackage.zip → extracted folder
    final isIOS = Platform.isIOS;
    final assetExtension = isIOS ? '.mlpackage.zip' : '.tflite';
    final destExtension = isIOS ? '.mlpackage' : '.tflite';

    final docsDir = await getApplicationDocumentsDirectory();
    final destPath = '${docsDir.path}/$modelName$destExtension';

    // 1) Already-copied? Return immediately.
    final alreadyExists = isIOS
        ? await Directory(destPath).exists()
        : await File(destPath).exists();
    if (alreadyExists) {
      _updateStatus('Using cached model: $modelName');
      return destPath;
    }

    // 2) Copy from bundled asset → documents directory
    try {
      _updateStatus('Copying bundled model: $modelName');

      final byteData =
          await rootBundle.load('assets/models/$modelName$assetExtension');
      final bytes = byteData.buffer.asUint8List();

      if (isIOS) {
        // Unzip .mlpackage.zip → folder
        final archive = ZipDecoder().decodeBytes(bytes);
        final modelDir = Directory(destPath);
        await modelDir.create(recursive: true);
        for (final file in archive) {
          if (file.isFile) {
            final outFile = File('${modelDir.path}/${file.name}');
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          }
        }
      } else {
        // Write the .tflite
        final outFile = File(destPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(bytes, flush: true);
      }

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
    final isIOS = Platform.isIOS;

    for (final mt in ModelType.values) {
      final ext = isIOS ? '.mlpackage' : '.tflite';
      final path = '${docsDir.path}/${mt.modelName}$ext';
      final fileOrDir = isIOS ? Directory(path) : File(path);

      if (await fileOrDir.exists()) {
        await fileOrDir.delete(recursive: true);
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
