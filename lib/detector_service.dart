import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:developer' as dev;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:tbs_detector/predict_result.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class DetectorService {
  static const _modelPath = "assets/models/tbs-detector-int8-meta.tflite";
  static const _inputSize = 800;
  static const _treshold = 0.4;

  static DetectorService? _instance;
  static Completer<DetectorService>? _completer;

  late final Interpreter _interprater;

  DetectorService._internal();

  static Future<DetectorService> createAsync() async {
    if (_instance != null) return _instance!;
    if (_completer != null) return _completer!.future;
    _completer = Completer<DetectorService>();
    try {
      final service = DetectorService._internal();
      await service._loadModel();
      _instance = service;
      _completer!.complete(service);
      return service;
    } catch (e) {
      _completer!.completeError(e);
      _completer = null;
      rethrow;
    }
  }

  /// Analisa gambar di background isolate untuk mencegah UI lag
  Future<List<PredictResult>> analizeImage(File imageFile) async {
    try {
      final rawImg = await imageFile.readAsBytes();
      // Jalankan prediksi di background thread menggunakan compute
      final result = await Isolate.run(
        () => _performPredictionCompute({
          'imageBytes': rawImg,
          'inputSize': _inputSize,
        }),
      );
      // final decodedImg = img.decodeImage(rawImg);
      // if (decodedImg == null) return [];
      // Jalankan model inference di main thread (karena TFLite tidak bisa di isolate)
      return _runInference(
        result['input'] as List,
        imgWidth: result["imgWidth"],
        imgHeight: result["imgHeight"],
      );
      // return _runInference(decodedImg, result['input'] as List);
    } catch (error, stacktrace) {
      dev.log("$error\n$stacktrace");
      return [];
    }
  }

  // Method untuk live detection menggunakan stream CameraImage
  Future<List<PredictResult>> predictFromCameraImage(
    CameraImage cameraImage,
  ) async {
    try {
      // Konversi CameraImage ke format yang sesuai
      final img.Image? convertedImage = _convertCameraImageToImage(cameraImage);
      if (convertedImage == null) return [];

      final resizedImg = img.copyResize(
        convertedImage,
        width: _inputSize,
        height: _inputSize,
      );

      final input = List.generate(
        1,
        (i) => List.generate(
          _inputSize,
          (y) => List.generate(_inputSize, (x) {
            final pixel = resizedImg.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          }),
        ),
      );

      final output = List.filled(1 * 5 * 13125, 0.0).reshape([1, 5, 13125]);
      _interprater.run(input, output);

      final List<PredictResult> detections = [];
      final imgWidth = convertedImage.width.toDouble();
      final imgHeight = convertedImage.height.toDouble();

      for (int i = 0; i < 13125; i++) {
        final score = output[0][4][i];
        if (score > _treshold) {
          final normCx = output[0][0][i];
          final normCy = output[0][1][i];
          final normW = output[0][2][i];
          final normH = output[0][3][i];

          final pixelCx = normCx * imgWidth;
          final pixelCy = normCy * imgHeight;
          final pixelW = normW * imgWidth;
          final pixelH = normH * imgHeight;

          final left = pixelCx - (pixelW / 2);
          final top = pixelCy - (pixelH / 2);
          final right = pixelCx + (pixelW / 2);
          final bottom = pixelCy + (pixelH / 2);

          detections.add(
            PredictResult(
              label: "TBS",
              score: score,
              rect: Rect.fromLTRB(left, top, right, bottom),
            ),
          );
        }
      }
      return _nms(detections);
    } catch (error, stacktrace) {
      dev.log("Error in predictFromCameraImage: $error\n$stacktrace");
      return [];
    }
  }

  /// Static function untuk dijalankan di background isolate
  /// Melakukan preprocessing image (decode, resize, normalize)
  static Future<Map<String, dynamic>> _performPredictionCompute(
    Map<String, dynamic> params,
  ) async {
    dev.log("Running Image Compute...");
    try {
      final imageBytes = params['imageBytes'] as List<int>?;
      final inputSize = params['inputSize'] as int? ?? 800;
      if (imageBytes == null) return {'input': [], 'error': 'No image bytes'};
      final decodedImg = img.decodeImage(Uint8List.fromList(imageBytes));
      if (decodedImg == null) {
        return {'input': [], 'error': 'Failed to decode image'};
      }
      final resizedImg = img.copyResize(
        decodedImg,
        width: inputSize,
        height: inputSize,
      );
      final input = List.generate(
        1,
        (i) => List.generate(
          inputSize,
          (y) => List.generate(inputSize, (x) {
            final pixel = resizedImg.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          }),
        ),
      );
      return {
        'input': input,
        'imgWidth': decodedImg.width.toDouble(),
        'imgHeight': decodedImg.height.toDouble(),
        'error': null,
      };
    } catch (e) {
      return {'input': [], 'error': e.toString()};
    }
  }

  /// Run inference dan post-processing di main thread
  // List<PredictResult> _runInference(img.Image decodedImg, List input) {
  List<PredictResult> _runInference(
    List input, {
    required double imgWidth,
    required double imgHeight,
  }) {
    dev.log("Running Inferece...");
    try {
      final output = List.filled(1 * 5 * 13125, 0.0).reshape([1, 5, 13125]);
      _interprater.run(input, output);
      final List<PredictResult> detections = [];
      dev.log("Looping Interprater result...");
      for (int i = 0; i < 13125; i++) {
        final score = output[0][4][i];
        if (score > _treshold) {
          final normCx = output[0][0][i];
          final normCy = output[0][1][i];
          final normW = output[0][2][i];
          final normH = output[0][3][i];

          final pixelCx = normCx * imgWidth;
          final pixelCy = normCy * imgHeight;
          final pixelW = normW * imgWidth;
          final pixelH = normH * imgHeight;

          final left = pixelCx - (pixelW / 2);
          final top = pixelCy - (pixelH / 2);
          final right = pixelCx + (pixelW / 2);
          final bottom = pixelCy + (pixelH / 2);

          detections.add(
            PredictResult(
              label: "TBS",
              score: score,
              rect: Rect.fromLTRB(left, top, right, bottom),
            ),
          );
        }
      }
      dev.log("Looping Done!");
      return _nms(detections);
    } catch (e) {
      dev.log("Error in _runInference: $e");
      return [];
    }
  }

  // Algoritma NMS (Non-Maximum Suppression) sederhana agar kotak tidak tumpang tindih
  List<PredictResult> _nms(List<PredictResult> data) {
    if (data.isEmpty) return [];
    data.sort((a, b) => b.score.compareTo(a.score));
    List<PredictResult> selected = [];
    List<bool> active = List.filled(data.length, true);
    for (int i = 0; i < data.length; i++) {
      if (active[i]) {
        selected.add(data[i]);
        for (int j = i + 1; j < data.length; j++) {
          if (active[j]) {
            double iou = _calculateIoU(data[i].rect, data[j].rect);
            if (iou > _treshold) {
              active[j] = false;
            }
          }
        }
      }
    }
    return selected;
  }

  double _calculateIoU(Rect boxA, Rect boxB) {
    final xA = max(boxA.left, boxB.left);
    final yA = max(boxA.top, boxB.top);
    final xB = min(boxA.right, boxB.right);
    final yB = min(boxA.bottom, boxB.bottom);

    final interArea = max(0, xB - xA) * max(0, yB - yA);
    final boxAArea = (boxA.right - boxA.left) * (boxA.bottom - boxA.top);
    final boxBArea = (boxB.right - boxB.left) * (boxB.bottom - boxB.top);

    return interArea / (boxAArea + boxBArea - interArea);
  }

  Future<void> _loadModel() async {
    final options = InterpreterOptions();
    if (Platform.isAndroid) {
      options.addDelegate(XNNPackDelegate());
    } else {
      options.addDelegate(GpuDelegate());
    }
    _interprater = await Interpreter.fromAsset(_modelPath);
  }

  // Helper function untuk konversi CameraImage ke Image
  img.Image? _convertCameraImageToImage(CameraImage cameraImage) {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToImage(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToImage(cameraImage);
      }
      return null;
    } catch (e) {
      print("Error converting camera image: $e");
      return null;
    }
  }

  // Konversi YUV420 ke Image (untuk Android)
  img.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
    final imgData = img.Image(width: width, height: height);

    final Plane plane0 = image.planes[0];
    final Plane plane1 = image.planes[1];
    final Plane plane2 = image.planes[2];

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() +
            (y / 2).floor() * plane1.bytesPerRow;
        final int index = y * plane0.bytesPerRow + x;

        final yp = plane0.bytes[index];
        final up = plane1.bytes[uvIndex];
        final vp = plane2.bytes[uvIndex];

        final rgba = _yuv2rgb(yp, up, vp, 255);
        final r = (rgba >> 8) & 0xFF;
        final g = (rgba >> 16) & 0xFF;
        final b = (rgba >> 24) & 0xFF;
        final a = (rgba >> 24) & 0xFF;
        imgData.setPixelRgba(x, y, r, g, b, a);
      }
    }
    return imgData;
  }

  // Konversi BGRA8888 ke Image (untuk iOS)
  img.Image _convertBGRA8888ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final imgData = img.Image(width: width, height: height);
    final plane = image.planes[0];
    final pixelStride = plane.bytesPerPixel ?? 4;

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final index = (y * plane.bytesPerRow) + (x * pixelStride);
        final b = plane.bytes[index];
        final g = plane.bytes[index + 1];
        final r = plane.bytes[index + 2];
        final a = plane.bytes[index + 3];

        imgData.setPixelRgba(x, y, r, g, b, a);
      }
    }
    return imgData;
  }

  // Helper function untuk konversi YUV ke RGB
  int _yuv2rgb(int y, int u, int v, int a) {
    int r = (y + (1.370705 * (v - 128))).round().clamp(0, 255);
    int g = (y - (0.698001 * (v - 128)) - (0.337633 * (u - 128))).round().clamp(
      0,
      255,
    );
    int b = (y + (1.732446 * (u - 128))).round().clamp(0, 255);
    return (a << 24) | (b << 16) | (g << 8) | r;
  }
}
