import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
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

  Future<List<PredictResult>> analizeImage(File image) async {
    final rawImg = await image.readAsBytes();
    final decodedImg = img.decodeImage(rawImg);
    final resizedImg = img.copyResize(
      decodedImg!,
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
    // final List<Map<String, dynamic>> detections = [];
    final List<PredictResult> detections = [];
    for (int i = 0; i < 13125; i++) {
      final score = output[0][4][i];
      if (score > _treshold) {
        // Ambil koordinat (Normalized 0-1 relative to 800x800)
        final xCenter = output[0][0][i];
        final yCenter = output[0][1][i];
        final width = output[0][2][i];
        final height = output[0][3][i];

        // Konversi dari center (xywh) ke topleft (xyxy)
        final xMin =
            (xCenter - (width / 2)) *
            decodedImg.width /
            _inputSize; // Scale balik ke ukuran asli
        final yMin = (yCenter - (height / 2)) * decodedImg.height / _inputSize;
        final xMax = (xCenter + (width / 2)) * decodedImg.width / _inputSize;
        final yMax = (yCenter + (height / 2)) * decodedImg.height / _inputSize;
        detections.add(
          PredictResult(
            label: "TBS",
            score: score,
            rect: Rect.fromLTRB(xMin, yMin, xMax, yMax),
          ),
        );
        // detections.add({
        //   "label": "TBS",
        //   "score": score,
        //   "rect": <double>[
        //     xMin,
        //     yMin,
        //     xMax,
        //     yMax,
        //   ], // Format [left, top, right, bottom]
        // });
      }
    }
    return _nms(detections);
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

  void close() => _interprater.close();

  Future<void> _loadModel() async {
    final options = InterpreterOptions();
    if (Platform.isAndroid) {
      options.addDelegate(XNNPackDelegate());
    } else {
      options.addDelegate(GpuDelegate());
    }
    _interprater = await Interpreter.fromAsset(_modelPath);
  }
}

class PredictResult {
  final String label;
  final double score;
  final Rect rect;

  PredictResult({required this.label, required this.score, required this.rect});

  toMap() {
    return {"label": label, "score": score, "rect": rect};
  }
}
