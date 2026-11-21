// main.dart
import 'package:flutter/material.dart';
import 'views/detection_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Object Detection',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D7A3A)),
      useMaterial3: true,
    ),
    home: const DetectionPage(),
  );
}