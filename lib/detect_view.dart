// Copyright 2021, Techaas.com. All rights reserved.
//
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:google_ml_kit/google_ml_kit.dart';

class DetectView extends StatefulWidget {
  final String imagePath;

  const DetectView({Key? key, required this.imagePath}) : super(key: key);

  @override
  _DetectViewState createState() => _DetectViewState();
}

class _DetectViewState extends State<DetectView> {
  late final String _imagePath;
  late final TextDetector _textDetector;

  Size? _imageSize;
  List<TextElement> _elements = [];

  Future<void> _getImageSize(File imageFile) async {
    final Completer<Size> completer = Completer<Size>();

    final Image image = Image.file(imageFile);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
      }),
    );

    final Size imageSize = await completer.future;
    debugPrint("size: ${imageSize}");
    setState(() {
      _imageSize = imageSize;
    });
  }

  void _recognizeText() async {
    _getImageSize(File(_imagePath));

    final inputImage = InputImage.fromFilePath(_imagePath);
    final RecognisedText recognisedText = await _textDetector.processImage(inputImage);

    // Finding and storing the text String(s) and the TextElement(s)
    for (TextBlock block in recognisedText.blocks) {
      print('block: ${block.text}');
      for (TextLine line in block.lines) {
        print('text: ${line.text}');
        for (TextElement element in line.elements) {
          _elements.add(element);
        }
        // }
      }
    }

    setState(() {});
  }

  @override
  void initState() {
    _imagePath = widget.imagePath;
    _textDetector = GoogleMlKit.vision.textDetector();
    _recognizeText();
    super.initState();
  }

  @override
  void dispose() {
    _textDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Picture')),
      body: _imageSize != null
          ? Container(
              color: Colors.black,
              child: Center(
                child: CustomPaint(
                  foregroundPainter: TextDetectorPainter(
                    _imageSize!,
                    _elements,
                  ),
                  child: AspectRatio(
                    aspectRatio: _imageSize!.aspectRatio,
                    child: Image.file(
                      File(_imagePath),
                    ),
                  ),
                ),
              ))
          : Container(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
    );
  }
}

class TextDetectorPainter extends CustomPainter {
  TextDetectorPainter(this.absoluteImageSize, this.elements);

  final Size absoluteImageSize;
  final List<TextElement> elements;
  final TextPainter painter = TextPainter(
    // textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    Rect _scaleRect(TextElement container) {
      return Rect.fromLTRB(
        container.rect.left * scaleX,
        container.rect.top * scaleY,
        container.rect.right * scaleX,
        container.rect.bottom * scaleY,
      );
    }

    void _drawText(TextElement element) {
      painter.text = TextSpan(
        text: element.text,
        style: TextStyle(
          color: Colors.white,
          backgroundColor: Colors.red,
          fontSize: 8.0,
        ),
      );
      Offset position = Offset(
        element.rect.left * scaleX + 2.0,
        element.rect.top * scaleY,
      );
      painter.layout();
      painter.paint(canvas, position);
    }

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.red
      ..strokeWidth = 2.0;

    for (TextElement element in elements) {
      canvas.drawRect(_scaleRect(element), paint);
      _drawText(element);
    }
  }

  @override
  bool shouldRepaint(TextDetectorPainter oldDelegate) {
    return true;
  }
}
