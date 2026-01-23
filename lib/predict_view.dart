import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tbs_detector/bounding_box_painter.dart';
import 'package:tbs_detector/main.dart';
import 'package:tbs_detector/predict_result.dart';

class PredictView extends StatefulWidget {
  const PredictView({
    super.key,
    required this.image,
    required this.predictions,
    required this.state,
    required this.isLiveMode,
  });

  final File image;
  final List<PredictResult> predictions;
  final PredictState state;
  final bool isLiveMode;

  @override
  State<PredictView> createState() => _PredictViewState();
}

class _PredictViewState extends State<PredictView> {
  Size? _imageSize;
  bool _showBoundingBoxes = true;

  @override
  void initState() {
    super.initState();
    _calculateImageSize();
  }

  @override
  Widget build(BuildContext context) {
    if (_imageSize == null) return LoadingView(message: "Loading...");
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = _imageSize!.aspectRatio;
        final widgetSize = Size(
          constraints.maxWidth,
          constraints.maxWidth / aspectRatio,
        );
        if (widget.isLiveMode) {
          return Stack(
            alignment: AlignmentDirectional.center,
            children: [
              SizedBox(
                width: double.maxFinite,
                height: widgetSize.width / aspectRatio,
                child: CustomPaint(
                  painter: BoundingBoxPainter(
                    widget.predictions.map((e) => e.rect).toList(),
                    _imageSize!,
                    widgetSize,
                  ),
                ),
              ),
            ],
          );
        }
        return GestureDetector(
          child: Stack(
            alignment: AlignmentDirectional.center,
            children: [
              // IMAGE with long-press handlers to hide/show bounding boxes
              Image.file(widget.image, fit: BoxFit.contain),
              // BACKGROUND BLUR (State == Predicting)
              Builder(
                builder: (context) {
                  if (widget.state == PredictState.predicting) {
                    return Shimmer.fromColors(
                      baseColor: Colors.black54,
                      highlightColor: Color(0x33CCE8E8),
                      period: Duration(milliseconds: 900),
                      direction: ShimmerDirection.ltr,
                      child: Container(color: Colors.black),
                    );
                  }
                  return SizedBox();
                },
              ),
              // LOTTIE (State == Predicting)
              Center(
                child: Builder(
                  builder: (context) {
                    if (widget.state == PredictState.predicting) {
                      return Shimmer.fromColors(
                        baseColor: Color(0xFF00696B),
                        highlightColor: Color(0xFF8AD1E6),
                        period: Duration(milliseconds: 1800),
                        direction: ShimmerDirection.ltr,
                        child: LottieBuilder.asset(
                          "assets/ai-loading.json",
                          width: 100,
                          height: 100,
                        ),
                      );
                    }
                    return SizedBox();
                  },
                ),
              ),
              // BOUNDING BOX (State == Predicted) — only paint when allowed
              Visibility(
                visible:
                    widget.state == PredictState.predicted &&
                    _showBoundingBoxes,
                child: SizedBox(
                  width: double.maxFinite,
                  height: widgetSize.width / aspectRatio,
                  child: CustomPaint(
                    painter: BoundingBoxPainter(
                      widget.predictions.map((e) => e.rect).toList(),
                      _imageSize!,
                      widgetSize,
                    ),
                  ),
                ),
              ),
            ],
          ),
          onLongPressStart: (_) {
            setState(() => _showBoundingBoxes = false);
          },
          onLongPressEnd: (_) {
            setState(() => _showBoundingBoxes = true);
          },
        );
      },
    );
  }

  Future<void> _calculateImageSize() async {
    final data = await widget.image.readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    setState(() {
      _imageSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    });
  }
}
