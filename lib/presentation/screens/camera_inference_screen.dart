// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import '../../models/model_type.dart';
import '../../services/model_manager.dart';

/// A screen that demonstrates real-time YOLO inference using the device camera.
class CameraInferenceScreen extends StatefulWidget {
  const CameraInferenceScreen({super.key});

  @override
  State<CameraInferenceScreen> createState() => _CameraInferenceScreenState();
}

class _CameraInferenceScreenState extends State<CameraInferenceScreen> {
  bool _isModelLoading = false;
  String? _modelPath;
  String _loadingMessage = '';

  final _yoloController = YOLOViewController();
  late final ModelManager _modelManager;

  @override
  void initState() {
    super.initState();
    _modelManager = ModelManager(
      onStatusUpdate: (message) {
        if (mounted) setState(() => _loadingMessage = message);
      },
    );
    _loadModelFromAssets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera view with YOLO detection
          if (_modelPath != null && !_isModelLoading)
            YOLOView(
              controller: _yoloController,
              modelPath: _modelPath!,
              task: ModelType.detect.task,
            ),

          // Loading indicator
          if (_isModelLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    _loadingMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),

          
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadModelFromAssets() async {
    setState(() {
      _isModelLoading = true;
      _loadingMessage = 'Loading ${ModelType.detect.modelName} model from assets...';
    });

    try {
      // Load model from assets (make sure your ModelManager supports this)
      final modelPath = await _modelManager.getModelPath(ModelType.detect);
      
      if (mounted) {
        setState(() {
          _modelPath = modelPath;
          _isModelLoading = false;
        });
        
        if (modelPath == null) {
          _showErrorDialog('Model Not Available');
        }
      }
    } catch (e) {
      print("❌ Model loading error: $e");
      if (mounted) {
        setState(() => _isModelLoading = false);
        _showErrorDialog('Model Loading Error', e.toString());
      }
    }
  }

  void _showErrorDialog(String title, [String? content]) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          content ??
              'Failed to load ${ModelType.detect.modelName} model from assets. Please ensure the model file is in the assets folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}