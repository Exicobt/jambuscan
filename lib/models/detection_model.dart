// models/detection_model.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

enum ModelLoadState { idle, loading, ready, failed }

extension ModelLoadStateX on ModelLoadState {
  bool get isReady   => this == ModelLoadState.ready;
  bool get isFailed  => this == ModelLoadState.failed;
  bool get isLoading => this == ModelLoadState.loading;

  String get label {
    switch (this) {
      case ModelLoadState.idle:    return 'Belum diinisialisasi';
      case ModelLoadState.loading: return 'Memuat model...';
      case ModelLoadState.ready:   return 'Model aktif';
      case ModelLoadState.failed:  return 'Model gagal dimuat';
    }
  }
}

enum DetectMode { camera, upload }

class DetectionResult {
  final String className;
  final double confidence;
  final Rect normalizedBox;
  final Color color;

  const DetectionResult({
    required this.className,
    required this.confidence,
    required this.normalizedBox,
    required this.color,
  });

  String get confidenceLabel => '${(confidence * 100).toStringAsFixed(1)}%';

  @override
  String toString() =>
      'DetectionResult(class=$className conf=$confidenceLabel box=$normalizedBox)';
}

class AppState {
  final ModelLoadState modelState;
  final String modelError;
  final String activeModelLabel;
  final DetectMode mode;
  final double fps;
  final File? uploadedImage;
  final Size imageSizePixels;
  final bool isDetecting;
  final List<DetectionResult> uploadResults;
  final Uint8List? annotatedImageBytes;
  final bool showDebugPanel;

  const AppState({
    this.modelState       = ModelLoadState.idle,
    this.modelError       = '',
    this.activeModelLabel = '',
    this.mode             = DetectMode.camera,
    this.fps              = 0,
    this.uploadedImage,
    this.imageSizePixels  = Size.zero,
    this.isDetecting      = false,
    this.uploadResults    = const [],
    this.annotatedImageBytes,
    this.showDebugPanel   = false,
  });

  AppState copyWith({
    ModelLoadState? modelState,
    String? modelError,
    String? activeModelLabel,
    DetectMode? mode,
    double? fps,
    File? uploadedImage,
    bool clearUploadedImage = false,
    Size? imageSizePixels,
    bool? isDetecting,
    List<DetectionResult>? uploadResults,
    Uint8List? annotatedImageBytes,
    bool clearAnnotated = false,
    bool? showDebugPanel,
  }) {
    return AppState(
      modelState       : modelState        ?? this.modelState,
      modelError       : modelError        ?? this.modelError,
      activeModelLabel : activeModelLabel  ?? this.activeModelLabel,
      mode             : mode              ?? this.mode,
      fps              : fps               ?? this.fps,
      uploadedImage    : clearUploadedImage ? null : (uploadedImage ?? this.uploadedImage),
      imageSizePixels  : imageSizePixels   ?? this.imageSizePixels,
      isDetecting      : isDetecting       ?? this.isDetecting,
      uploadResults    : uploadResults     ?? this.uploadResults,
      annotatedImageBytes: clearAnnotated ? null : (annotatedImageBytes ?? this.annotatedImageBytes),
      showDebugPanel   : showDebugPanel    ?? this.showDebugPanel,
    );
  }
}