// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo_result.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import '../../models/model_type.dart';
import '../../services/model_manager.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  double _downloadProgress = 0.0;

  final _yoloController = YOLOViewController();

  late final ModelManager _modelManager;
  final FlutterTts _flutterTts = FlutterTts();
  DateTime _lastSpoken = DateTime.fromMillisecondsSinceEpoch(0);

  double realObjectHeightCm = 27.5; // Editable real height in cm
  double focalLengthMm = 518; // Focal length in mm
  double? _objectDistance; // Last calculated distance in cm
  String detectedObjectName = 'bottle';

  @override
  void initState() {
    super.initState();
    _modelManager = ModelManager(
      onStatusUpdate: (message) {
        if (mounted) setState(() => _loadingMessage = message);
      },
    );
    _loadModelForPlatform();
  }

void _onDetectionResults(List<YOLOResult> results) async {
  if (!mounted || results.isEmpty) return;

  final detectedObject = results
      .where((r) => r.className.toLowerCase() == detectedObjectName)
      .firstOrNull;

  // If the object is not found, clear the distance and stop.
  if (detectedObject == null) {
    if (_objectDistance != null) setState(() => _objectDistance = null);
    return;
  }
  
  // --- Distance Calculation (This part remains the same) ---
  final pixelHeight = detectedObject.boundingBox.height;
  if (pixelHeight > 0) {
    final distanceCm = (realObjectHeightCm * focalLengthMm) / pixelHeight;
    setState(() => _objectDistance = distanceCm);
  }

  // --- Start of Simplified Directional Logic ---
  final now = DateTime.now();
  if (now.difference(_lastSpoken).inSeconds < 3) return;

  // 1. GET THE OBJECT'S CENTER in the model's 640x640 coordinate space.
  final box = detectedObject.boundingBox;
  final double objectCenterX = box.left + (box.width / 2);
  final double objectCenterY = box.top + (box.height / 2);

  // 2. DEFINE A "TARGET ZONE" in the center of the 640x640 space.
  // The center is 320. Let's create a zone +/- 100 pixels from the center.
  const double targetLeft = 220;   // 320 - 100
  const double targetRight = 420;  // 320 + 100
  const double targetTop = 220;
  const double targetBottom = 420;

  // 3. COMPARE DIRECTLY!
  final parts = <String>[];
  if (objectCenterX < targetLeft) {
    parts.add('go left');
  } else if (objectCenterX > targetRight) {
    parts.add('go right');
  }

  if (objectCenterY < targetTop) {
    parts.add('go up');
  } else if (objectCenterY > targetBottom) {
    parts.add('go down');
  }

  String instruction;
  if (parts.isEmpty) {
    instruction = '$detectedObjectName is centered';
  } else {
    instruction = parts.join(' and ');
  }

  // Speak the instruction
  await _flutterTts.speak(instruction);
  _lastSpoken = now;
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_modelPath != null && !_isModelLoading)
            YOLOView(
              controller: _yoloController,
              modelPath: _modelPath!,
              task: ModelType.detect.task,
              onResult: _onDetectionResults,
              onImageSize: (size) { // <-- ADD THIS CALLBACK
                    if (mounted) {
                      setState(() {
                        _imageSize = size;
                      });
                    }
              },
            ),

          if (_objectDistance != null)
            Positioned(
              top: 40,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: Text(
                  'Distance: ${_objectDistance!.toStringAsFixed(1)} cm',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            )
          else
            Positioned(
              top: 40,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: Text(
                  'No $detectedObjectName detected',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          Center(
            child: FractionallySizedBox(
              widthFactor: 2 / 4,
              heightFactor: 2 / 4,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadModelForPlatform() async {
    setState(() {
      _isModelLoading = true;
      _loadingMessage = 'Loading ${ModelType.detect.modelName} model...';
      _downloadProgress = 0.0;
    });

    try {
      final modelPath = await _modelManager.getModelPath(ModelType.detect);
      if (mounted) {
        setState(() {
          _modelPath = modelPath;
          _isModelLoading = false;
        });
        if (modelPath == null) _showErrorDialog('Model Not Available');
      }
    } catch (e) {
      _showErrorDialog('Model Loading Error', e.toString());
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
              'Failed to load ${ModelType.detect.modelName} model. Please check your internet connection and try again.',
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
