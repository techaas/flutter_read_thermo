// Copyright 2021, Techaas.com. All rights reserved.
//

import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as imglib;

import 'detect_view.dart';

part 'utils.dart';

typedef HandleDetection<T> = Future<T> Function(InputImage image);

class CameraView extends StatefulWidget {
  final CameraDescription camera;

  const CameraView({
    Key? key,
    required this.camera,
  }) : super(key: key);

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  final TextDetector _detector = GoogleMlKit.vision.textDetector();

  Size? _imageSize;
  List<TextElement> _elements = [];
  String? _detectedDigit;
  Uint8List? _detectedImage;

  bool _isStreaming = false;
  bool _isDetecting = false;

  // Initializes camera controller to preview on screen
  void _initializeCamera() async {
    debugPrint('initializeCamera');
    final CameraController cameraController = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _controller = cameraController;
    _initializeControllerFuture = _controller!.initialize().then((_) {
      _start();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance!.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _stop(true).then((value) => _controller?.dispose());
    } else if (state == AppLifecycleState.resumed && _isStreaming) {
      _initializeCamera();
    }
  }

  Future<void> _stop(bool silently) {
    debugPrint("_stop");
    final completer = Completer();
    scheduleMicrotask(() async {
      if (_controller?.value.isStreamingImages == true && mounted) {
        debugPrint("stop streaming");
        await _controller?.stopImageStream().catchError((_) {});
      }

      if (silently) {
        _isStreaming = false;
      } else {
        setState(() {
          _isStreaming = false;
        });
      }
      completer.complete();
    });
    return completer.future;
  }

  void _start() {
    _controller?.startImageStream(_processImage);
    setState(() {
      _isStreaming = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Camera Preview'),
        ),
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (_imageSize != null && snapshot.connectionState == ConnectionState.done) {
              return Stack(children: [
                Center(
                  child: CustomPaint(
                    foregroundPainter: TextDetectorPainter(
                      _imageSize!,
                      _elements,
                    ),
                    child: CameraPreview(_controller!),
                  ),
                ),
                if (_detectedDigit != null) ...[
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                        width: double.infinity,
                        height: 100,
                        color: Colors.white,
                        child: Stack(children: [
                          Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                  margin: EdgeInsets.only(right: 80),
                                  height: 80,
                                  width: MediaQuery.of(context).size.width / 2,
                                  child: FittedBox(
                                      fit: BoxFit.fitHeight,
                                      child: Image.memory(_detectedImage!)))),
                          Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(_detectedDigit!))),
                        ])),
                  ),
                ],
              ]);
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            try {
              await _initializeControllerFuture;
              await _controller?.stopImageStream().catchError((_) {});

              final image = await _controller?.takePicture();
              debugPrint('Picture: ${image?.path}');
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DetectView(
                    imagePath: image!.path,
                  ),
                ),
              );
            } catch (e) {
              // If an error occurs, log the error to the console.
              debugPrint('Picture Error: Error: ${e}');
            }
          },
          child: const Icon(Icons.camera_alt),
        ));
  }

  void _processImage(CameraImage cameraImage) async {
    if (!_isDetecting && mounted) {
      _isDetecting = true;
      try {
        final rotation = _rotationIntToImageRotation(widget.camera.sensorOrientation);
        final RegExp regEx = RegExp(r"[0-9\.]*");

        final RecognisedText recognisedText =
            await _detect(cameraImage, _detector.processImage, rotation!);

        List<TextElement> _detectedElements = [];
        for (TextBlock block in recognisedText.blocks) {
          // print('block: ${block.text}');
          for (TextLine line in block.lines) {
            // print('text: ${line.text}');
            for (TextElement element in line.elements) {
              if (regEx.hasMatch(line.text)) {
                final matches = regEx.allMatches(line.text);
                final matchStrings = matches.map((element) => element.group(0));
                final String result = matchStrings.join();
                if (result.length > 0) {
                  final digits = double.parse(result);
                  print('result: "$digits" ${element.rect}');
                  if (digits > 100 && _detectedDigit != result) {
                    final croppedImage = _getCroppedImage(
                        cameraImage, widget.camera.sensorOrientation, element.rect);
                    debugPrint('${croppedImage.width} x ${croppedImage.height}');
                    final decodedBytes = Uint8List.fromList(imglib.encodePng(croppedImage));
                    setState(() {
                      _detectedImage = decodedBytes;
                      _detectedDigit = result;
                    });
                  }
                }
              }
              _detectedElements.add(element);
            }
          }
        }

        setState(() {
          _imageSize = Size(cameraImage.height.toDouble(), cameraImage.width.toDouble());
          _elements = _detectedElements;
        });
        // 250msスリープさせて負荷を下げる. (本来なら、backpressure掛ける方が良いかも)
        await Future.delayed(Duration(milliseconds: 250));
      } catch (ex, stack) {
        debugPrint('$ex, $stack');
      }
      _isDetecting = false;
    }
  }
}
