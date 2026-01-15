import 'package:flutter/material.dart';

class ShimmerView extends StatefulWidget {
  final double width;
  final double height;
  final ShapeBorder shapeBorder;

  const ShimmerView.rectangular({
    super.key,
    this.width = double.infinity,
    required this.height,
  }) : shapeBorder = const RoundedRectangleBorder();

  const ShimmerView.circular({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.shapeBorder = const CircleBorder(),
  });

  @override
  _ShimmerViewState createState() => _ShimmerViewState();
}

class _ShimmerViewState extends State<ShimmerView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(); // Membuat animasi berjalan selamanya
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [Colors.red[300]!, Colors.red[100]!, Colors.red[300]!],
              stops: const [0.1, 0.5, 0.9],
              begin: Alignment(-1.5 + _controller.value * 3, -0.3),
              end: Alignment(1.0 + _controller.value * 3, 0.3),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: ShapeDecoration(
              color: Colors.red[400], // Warna dasar widget
              shape: widget.shapeBorder,
            ),
          ),
        );
      },
    );
  }
}
