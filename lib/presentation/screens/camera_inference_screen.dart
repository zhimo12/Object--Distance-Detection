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

  // void _onDetectionResults(List<YOLOResult> results) async {
  //   if (!mounted) return;

  //   // final now = DateTime.now();
  //   // if (results.isNotEmpty && now.difference(_lastSpoken).inSeconds > 3) {
  //   //   final top = results.reduce((a, b) => a.confidence > b.confidence ? a : b);
  //   //   await _flutterTts.stop();
  //   //   await _flutterTts.speak('Detected ${top.className}');
  //   //   _lastSpoken = now;
  //   // }

  //   final detectedObject = results
  //       .where((r) => r.className.toLowerCase() == detectedObjectName)
  //       .firstOrNull;

  //   if (detectedObject != null) {
  //      final pixelHeight = detectedObject.boundingBox.height;
  //     if (pixelHeight > 0) {
  //       final realHeightMm = realObjectHeightCm;
  //       final distanceMm = (realHeightMm * focalLengthMm) / pixelHeight;
  //       if (mounted) {
  //         setState(() => _objectDistance = distanceMm);
  //       }
  //     }
  //   } else {
  //     if (mounted) {
  //       setState(() => _objectDistance = null);
  //     }
  //   }
  // }
  void _onDetectionResults(List<YOLOResult> results) async {
    if (results.isEmpty) return;

    final detectedObject = results
        .where((r) => r.className.toLowerCase() == detectedObjectName)
        .firstOrNull;
    if (detectedObject == null) return;

    final context = this.context;
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    // 1) pull out raw box coords
    final box = detectedObject.boundingBox;
    final bx1 = box.left;
    final by1 = box.top;
    final bw = box.width;
    final bh = box.height;
    final bxx = box.center;

    // // 2) compute the box center
    final cx = bx1 ;
    final cy = by1 ; // center y is top + half height

    //3) compute the window boundaries
    final winW = w / 2; // 2/4 = 1/2 of width
    final winH = h / 2; // 2/4 = 1/2 of height
    final x1 = (w - winW+60) / 2; // left boundary
    final x2 = x1 + winW-60; // right boundary
    final y1 = (h - winH-60) / 2; // top boundary
    final y2 = (y1 + winH)/2; // bottom boundary

    print('y1: $y1, y2: $y2, h: $h, winW: $winW, cx: $cx, cy: $cy, bxx: $bxx');

    if (detectedObject != null) {
      final pixelHeight = detectedObject.boundingBox.height;
      if (pixelHeight > 0) {
        final realHeightMm = realObjectHeightCm;
        final distanceMm = (realHeightMm * focalLengthMm) / pixelHeight;
        if (mounted) {
          setState(() => _objectDistance = distanceMm);
        }
      }
    } else {
      if (mounted) {
        setState(() => _objectDistance = null);
      }
    }

    final now = DateTime.now();
    // only speak at most once every 3 seconds
    if (now.difference(_lastSpoken).inSeconds < 3) return;

    final parts = <String>[];

    if (cx < x1) {
      parts.add('go left');
    } else if (cx > x2) {
      parts.add('go right');
    }
    if (cy < y1) {
      parts.add('go up');
    } else if (cy > y2) {
      parts.add('go down');
    }
    if (cx >= x1 && cx <= x2 && cy >= y1 && cy <= y2) {
      parts.add('$detectedObjectName at the center');
    }

    // combine into one sentence
    final instruction = parts.join(' and ');

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
