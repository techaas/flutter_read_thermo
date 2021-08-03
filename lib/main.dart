// Copyright 2021, Techaas.com. All rights reserved.
//
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'camera_view.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final cameras = await availableCameras();
    final firstCamera = cameras.first;
    runApp(MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CameraView(camera: firstCamera),
    ));
  } on CameraException catch (e) {
    debugPrint('Initialize Error: ${e.description}');
  }
}
