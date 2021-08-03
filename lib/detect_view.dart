// Copyright 2021, Techaas.com. All rights reserved.
//
import 'package:flutter/material.dart';
import 'dart:io';

class DetectView extends StatelessWidget {
  final String imagePath;

  const DetectView({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Picture')),
      body: Center(child: Image.file(File(imagePath))),
    );
  }
}
