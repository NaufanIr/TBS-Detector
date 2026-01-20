import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tbs_detector/detector_service.dart';

import 'package:tbs_detector/main.dart';
import 'package:tbs_detector/predict_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? image;
  ImgSource source = ImgSource.camera;
  PredictState state = PredictState.notPredicted;
  List<PredictResult> predictions = [];
  bool isCamReady = false;
  bool isLivePredict = false;
  bool isLivePredictBusy = false;

  // final predictor = ObjectDetectionService();
  late final CameraController camController;
  late final DetectorService detectorService;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    super.dispose();
    camController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Flex(
          direction: Axis.vertical,
          children: [
            // CHIPS
            Flexible(
              flex: 4,
              child: Center(
                child: Builder(
                  builder: (context) {
                    return switch (state) {
                      PredictState.notPredicted => SizedBox(height: 32),
                      PredictState.predicting => Chip(
                        label: Text("Analizing image..."),
                      ),
                      PredictState.predicted => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          spacing: 16,
                          children: [
                            Chip(label: Text("TBS: ${predictions.length}")),
                            Chip(label: Text("Avg.acc: 75%")),
                          ],
                        ),
                      ),
                    };
                  },
                ),
              ),
            ),
            // CAMERA/IMAGE PREVIEW
            Flexible(
              flex: 30,
              child: Container(
                color: Color(0XFF131313),
                child: Builder(
                  builder: (context) {
                    if (!isCamReady) {
                      return LoadingView(message: "Loading...");
                    }
                    if (isLivePredict) {}
                    if (state == PredictState.notPredicted) {
                      return CameraPreview(camController);
                    }
                    return PredictView(
                      image: image!,
                      predictions: predictions,
                      state: state,
                      isLiveMode: isLivePredict,
                    );
                  },
                ),
              ),
            ),
            // ACTION BUTTONS
            Flexible(
              flex: 7,
              child: Center(
                child: Builder(
                  builder: (context) {
                    if (state == PredictState.notPredicted) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // IMAGE PICKER
                            Builder(
                              builder: (context) {
                                if (isLivePredict) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15.5,
                                    ),
                                    child: Text(
                                      "LIVE",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  );
                                }
                                return IconButton.filled(
                                  padding: EdgeInsets.all(15),
                                  icon: Icon(
                                    Icons.image_search_rounded,
                                    size: 30,
                                  ),
                                  style: IconButton.styleFrom(
                                    foregroundColor: Color(0xFF00696B),
                                    backgroundColor: Color(0xFFCCE8E8),
                                  ),
                                  onPressed: isCamReady ? _selectImage : null,
                                );
                              },
                            ),
                            // CAMERA SHUTTER
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: CircleBorder(),
                                fixedSize: Size(80, 80),
                                side: BorderSide(
                                  width: 5,
                                  color: Color(0xFF00696B),
                                ),
                              ),
                              onPressed: isCamReady ? _takePicture : null,
                              child: SizedBox(),
                            ),
                            // LIVE MODE TOGGLE
                            IconButton.filled(
                              iconSize: 30,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    isLivePredict
                                        ? Color(0xFF00696B)
                                        : Colors.white,
                                foregroundColor:
                                    isLivePredict
                                        ? Colors.white
                                        : Color(0xFF00696B),
                              ),
                              padding: EdgeInsets.all(16),
                              icon: Icon(
                                isLivePredict
                                    ? Icons.center_focus_weak_rounded
                                    : Icons.center_focus_strong,
                              ),
                              onPressed: _livePredict,
                            ),
                          ],
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.white54),
                        iconSize: 50,
                        style: IconButton.styleFrom(fixedSize: Size(80, 80)),
                        onPressed: () {
                          setState(() => state = PredictState.notPredicted);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _init() async {
    try {
      // 1. Init Camera
      final cameras = await availableCameras();
      camController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await camController.initialize();
      isCamReady = true;
      // 2. Init Detector Service
      detectorService = await DetectorService.createAsync();
      if (mounted) setState(() {});
    } catch (error, stacktrace) {
      log("$error\n$stacktrace");
    }
  }

  _selectImage() async {
    final imgPicker = ImagePicker();
    final selectedImg = await imgPicker.pickImage(source: ImageSource.gallery);
    if (selectedImg == null) return;
    setState(() {
      image = File(selectedImg.path);
      state = PredictState.predicting;
      source = ImgSource.gallery;
    });
    predictions = await detectorService.analizeImage(File(selectedImg.path));
    log("${predictions.map((e) => e.toMap()).toList()}");
    // predictions = await predictor.predictFromFilePath(selectedImg.path);
    await Future.delayed(Duration(seconds: 5));
    setState(() => state = PredictState.predicted);
  }

  _takePicture() async {
    try {
      final capturedPict = await camController.takePicture();
      setState(() {
        image = File(capturedPict.path);
        state = PredictState.predicting;
        source = ImgSource.camera;
      });
      // predictions = await predictor.predictFromFilePath(capturedPict.path);
      await Future.delayed(Duration(seconds: 5));
      setState(() => state = PredictState.predicted);
    } catch (error, stacktrace) {
      log("$error\n$stacktrace");
    }
  }

  _livePredict() async {
    setState(() => isLivePredict = !isLivePredict);
    if (isLivePredict) {
      await camController.startImageStream((image) async {
        log("LIVE PREDICT");
        // if (isLivePredictBusy) return;
        // setState(() => isLivePredictBusy = true);
        // predictions = await predictor.livePredict(
        //   image: image,
        //   cameraDesc: camController.description,
        // );
        // setState(() => isLivePredictBusy = false);
      });
    } else {
      await camController.stopImageStream();
      setState(() => isLivePredictBusy = false);
    }
  }
}
