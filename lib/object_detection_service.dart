import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class ObjectDetectionService {
  Future<List<DetectedObject>> predictFromFilePath(String path) async {
    final detector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
    final inputImage = InputImage.fromFilePath(path);
    final result = await detector.processImage(inputImage);
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

  Future<List<DetectedObject>> livePredict({
    required CameraImage image,
    required CameraDescription cameraDesc,
  }) async {
    final detector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.stream,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
    final inputImage = _cameraImageToInputImage(image, cameraDesc);
    if (inputImage == null) return [];
    final result = await detector.processImage(inputImage);
    log(
      "Labels: ${result.map((e) => e.labels.map((l) => "Label: ${l.text}, Acc: ${l.confidence}").toList()).toList()}",
    );
    return result;
  }

  InputImage? _cameraImageToInputImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      // print('rotationCompensation: $rotationCompensation');
    }
    if (rotation == null) return null;
    // print('final rotation: $rotation');
    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }
}
