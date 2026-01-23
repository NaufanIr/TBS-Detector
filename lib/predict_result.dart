import 'dart:ui';

class PredictResult {
  final String label;
  final double score;
  final Rect rect;

  PredictResult({required this.label, required this.score, required this.rect});

  toMap() {
    return {"label": label, "score": score, "rect": rect};
  }
}
