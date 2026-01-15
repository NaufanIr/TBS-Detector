import 'dart:developer';

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class ObjectDetectionService {
  final _detector = ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );

  Future<List<DetectedObject>> predictFromFilePath(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final result = await _detector.processImage(inputImage);
    log(
      "Labels: ${result.map((e) => e.labels.map((l) => "Label: ${l.text}, Acc: ${l.confidence}").toList()).toList()}",
    );
    // log(
    //   "${result.map((e) => "Rect(top: ${e.boundingBox.top}, bottom: ${e.boundingBox.bottom}, left: ${e.boundingBox.left}, right: ${e.boundingBox.right})\n").toList()}",
    // );
    return result;
    // final predicts = await _detector.processImage(inputImage);
    // for (var predict in predicts) {
    //   final labels =
    //       predict.labels.map((label) {
    //         return "Label(text: ${label.text}, confidance: ${label.confidence})";
    //       }).toList();
    //   log("$labels");
    //   // final boundingBox = predict.boundingBox;
    // }
  }
}
