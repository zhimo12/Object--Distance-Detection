// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

import 'package:ultralytics_yolo/yolo_task.dart';

enum ModelType {
  detect('yolo11n_float16', YOLOTask.detect);

  final String modelName;
  final YOLOTask task;

  const ModelType(this.modelName, this.task);
}
