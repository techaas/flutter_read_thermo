part of 'camera_view.dart';

Uint8List _concatenatePlanes(List<Plane> planes) {
  final allBytes = WriteBuffer();
  planes.forEach((plane) => allBytes.putUint8List(plane.bytes));
  return allBytes.done().buffer.asUint8List();
}

InputImageRotation? _rotationIntToImageRotation(int rotation) {
  return InputImageRotationMethods.fromRawValue(rotation);
}

InputImageData _buildImageData(
  CameraImage image,
  InputImageRotation rotation,
) {
  return InputImageData(
    size: Size(image.width.toDouble(), image.height.toDouble()),
    imageRotation: rotation,
    inputImageFormat: InputImageFormat.YUV420,
    planeData: image.planes
        .map(
          (plane) => InputImagePlaneMetadata(
            bytesPerRow: plane.bytesPerRow,
            height: plane.height,
            width: plane.width,
          ),
        )
        .toList(),
  );
}

Future<T> _detect<T>(
  CameraImage image,
  HandleDetection<T> handleDetection,
  InputImageRotation rotation,
) async {
  return handleDetection(
    InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      inputImageData: _buildImageData(image, rotation),
    ),
  );
}

imglib.Image _getCroppedImage(CameraImage cameraImage, int rotation, Rect rect) {
  imglib.Image image = _convertYUV420(cameraImage);
  imglib.Image rotated = imglib.copyRotate(image, rotation);

  Rect cropRect = Rect.fromLTRB(
      math.max(0, rect.left - 20),
      math.max(0, rect.top - 20),
      math.min(rect.right + 20, rotated.width.toDouble()),
      math.min(rect.bottom + 20, rotated.height.toDouble()));

  debugPrint('$cropRect');
  imglib.Image cropped = imglib.copyCrop(rotated, cropRect.left.round(), cropRect.top.round(),
      cropRect.width.round(), cropRect.height.round());
  return cropped;
}

imglib.Image _convertYUV420(CameraImage image) {
  const int shift = (0xFF << 24);

  final img = imglib.Image(image.width, image.height);
  Plane plane = image.planes[0];

  // Fill image buffer with plane[0] from YUV420_888
  for (int x = 0; x < image.width; x++) {
    for (int planeOffset = 0;
        planeOffset < image.height * image.width;
        planeOffset += image.width) {
      final pixelColor = plane.bytes[planeOffset + x];
      // color: 0x FF  FF  FF  FF
      //           A   B   G   R
      // Calculate pixel color
      var newVal = shift | (pixelColor << 16) | (pixelColor << 8) | pixelColor;
      img.data[planeOffset + x] = newVal;
    }
  }

  return img;
}
