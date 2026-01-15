import 'package:flutter/material.dart';

import 'package:tbs_detector/home_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF00696B)),
      ),
      home: HomePage(),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      child: Column(
        spacing: 16,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 35, height: 35, child: CircularProgressIndicator()),
          Text(message, style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

enum PredictState { predicted, predicting, notPredicted }

enum ImgSource { gallery, camera }
