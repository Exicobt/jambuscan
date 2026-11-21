// controllers/detection_controller.dart
// ─────────────────────────────────────────────────────────────────────────────
// Controller dengan YoloTfliteService (tflite_flutter) — tanpa ultralytics.
// Strategi: coba float32 dulu (paling kompatibel), jika gagal error jelas.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../models/detection_model.dart';
import '../services/yolo_tflite_service.dart';
import '../utils/app_logger.dart';

class DetectionController extends ChangeNotifier {
  static const String _tag = 'Controller';

  // ── Config ─────────────────────────────────────────────────────────────────
  // Nama file di assets/models/ — WAJIB sesuai pubspec.yaml
  // Gunakan float32 untuk kompatibilitas maksimum (termasuk Redmi MIUI)
  static const String modelAssetPath = 'assets/models/best_jambu_biji_8m_float16.tflite';

  static const double confidenceThreshold = 0.25;
  static const double iouThreshold        = 0.45;

  static const Map<String, Color> labelColors = {
    'matang': Color(0xFF4CAF50),
    'mentah': Color(0xFFFFA000),
    'busuk':  Color(0xFFE53935),
  };

  // ── State & Service ────────────────────────────────────────────────────────
  AppState _state = const AppState();
  AppState get state => _state;

  final YoloTfliteService _service = YoloTfliteService();

  // Camera mode pakai CameraController (dari package camera)
  // Live detection di camera mode dijalankan via CameraController.startImageStream
  List<DetectionResult> _cameraResults = [];
  List<DetectionResult> get cameraResults => _cameraResults;

  bool _isCameraStreaming = false;

  // ─────────────────────────────────────────────────────────────────────────
  // INIT MODEL
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> initModel() async {
    if (_state.modelState == ModelLoadState.loading) {
      log.w(_tag, 'initModel dipanggil saat loading, diabaikan');
      return;
    }
    if (_state.modelState == ModelLoadState.ready) {
      log.i(_tag, 'Model sudah ready: $modelAssetPath');
      return;
    }

    log.i(_tag, '━━━ Memulai load model ━━━');
    log.i(_tag, 'Path    : $modelAssetPath');
    log.i(_tag, 'Delegate: CPU (paksa, agar stabil di Redmi MIUI)');
    log.i(_tag, 'Package : tflite_flutter (bukan ultralytics plugin)');

    _updateState(_state.copyWith(
      modelState: ModelLoadState.loading,
      modelError: '',
    ));

    try {
      final watch = Stopwatch()..start();

      // useCpuOnly=true: paksa CPU delegate, tidak pakai GPU sama sekali
      // Ini solusi utama untuk Redmi MIUI yang GPU delegate-nya corrupt output
      await _service.loadModel(modelAssetPath, useCpuOnly: true);

      watch.stop();
      log.i(_tag, '✅ Model loaded dalam ${watch.elapsedMilliseconds} ms');

      _updateState(_state.copyWith(
        modelState: ModelLoadState.ready,
        activeModelLabel: '$modelAssetPath (CPU)',
      ));
    } on Exception catch (e, st) {
      _handleLoadError(e.toString(), st.toString());
    } catch (e, st) {
      _handleLoadError(e.toString(), st.toString());
    }
  }

  void _handleLoadError(String error, String stackTrace) {
    log.c(_tag, '🔥 GAGAL LOAD MODEL: $error',
        'Kemungkinan penyebab:\n'
        '1. File model tidak ada di assets/models/\n'
        '2. Nama file di pubspec.yaml tidak sesuai\n'
        '3. File .tflite corrupt\n'
        '4. RAM tidak cukup (model float32 lebih besar)\n\n'
        'Stack: $stackTrace');

    _updateState(_state.copyWith(
      modelState: ModelLoadState.failed,
      modelError: error,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAMERA MODE — live detection via image stream
  // ─────────────────────────────────────────────────────────────────────────

  /// Proses satu frame dari CameraController.startImageStream
  /// Dipanggil dari CameraView setiap frame
  Future<void> processCameraFrame(Uint8List jpegBytes) async {
    if (!_service.isLoaded || _isCameraStreaming) return;
    _isCameraStreaming = true;

    try {
      final detections = await _service.predict(
        jpegBytes,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
      );

      _cameraResults = detections.map((d) => DetectionResult(
        className: d.className,
        confidence: d.confidence,
        normalizedBox: Rect.fromLTRB(d.x1, d.y1, d.x2, d.y2),
        color: labelColors[d.className.toLowerCase()] ?? Colors.grey,
      )).toList();

      notifyListeners();
    } catch (e) {
      log.e(_tag, 'Error proses camera frame: $e');
    } finally {
      _isCameraStreaming = false;
    }
  }

  void updateFps(double fps) {
    if ((fps - _state.fps).abs() > 0.5) {
      _updateState(_state.copyWith(fps: fps));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPLOAD MODE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> pickAndDetect(ImageSource source) async {
    log.i(_tag, 'Image picker: ${source == ImageSource.camera ? "kamera" : "galeri"}');

    final XFile? picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) {
      log.w(_tag, 'Image picker dibatalkan');
      return;
    }

    final imageFile = File(picked.path);
    log.i(_tag, 'Gambar dipilih: ${picked.path}');

    // Baca ukuran gambar asli
    final rawBytes = await imageFile.readAsBytes();
    final decoded  = img.decodeImage(rawBytes);
    if (decoded == null) {
      log.e(_tag, 'Gagal decode gambar yang dipilih');
      return;
    }

    final imgW = decoded.width.toDouble();
    final imgH = decoded.height.toDouble();
    log.d(_tag, 'Ukuran gambar: ${imgW.toInt()}×${imgH.toInt()} px');

    _updateState(_state.copyWith(
      uploadedImage: imageFile,
      uploadResults: [],
      isDetecting: true,
      imageSizePixels: Size(imgW, imgH),
      clearAnnotated: true,
    ));

    // Pastikan model ready
    if (!_service.isLoaded) {
      log.w(_tag, 'Model belum ready, menjalankan initModel()...');
      await initModel();
    }

    if (!_service.isLoaded) {
      log.e(_tag, 'Model tetap tidak ready. Abort predict.');
      _updateState(_state.copyWith(
        isDetecting: false,
        modelError: 'Model tidak dapat diinisialisasi',
      ));
      return;
    }

    await _runPredict(rawBytes, imageFile, imgW, imgH);
  }

  Future<void> _runPredict(
    Uint8List imageBytes,
    File imageFile,
    double imgW,
    double imgH,
  ) async {
    try {
      log.d(_tag, '━━━ predict() ━━━');
      log.d(_tag, 'Bytes   : ${imageBytes.length}');
      log.d(_tag, 'Conf    : $confidenceThreshold');
      log.d(_tag, 'IOU     : $iouThreshold');
      log.d(_tag, 'Model   : $modelAssetPath');
      log.d(_tag, 'Delegate: CPU');

      final watch = Stopwatch()..start();
      final detections = await _service.predict(
        imageBytes,
        confidenceThreshold: confidenceThreshold,
        iouThreshold: iouThreshold,
      );
      watch.stop();

      log.i(_tag, 'predict() selesai: ${watch.elapsedMilliseconds} ms');

      if (detections.isEmpty) {
        log.w(_tag, 'Tidak ada deteksi',
            'Kemungkinan:\n'
            '1. Threshold terlalu tinggi (coba turunkan confidenceThreshold)\n'
            '2. Objek tidak ada di gambar\n'
            '3. Output shape model tidak sesuai _numClasses di service\n'
            '4. Model belum dilatih untuk kondisi gambar ini');
      }

      final results = detections.map((d) => DetectionResult(
        className: d.className,
        confidence: d.confidence,
        normalizedBox: Rect.fromLTRB(d.x1, d.y1, d.x2, d.y2),
        color: labelColors[d.className.toLowerCase()] ?? Colors.grey,
      )).toList();

      for (int i = 0; i < results.length; i++) {
        log.i(_tag, '  [$i] ${results[i]}');
      }

      _updateState(_state.copyWith(
        uploadResults: results,
        isDetecting: false,
        modelState: ModelLoadState.ready,
      ));
    } on Exception catch (e, st) {
      log.e(_tag, 'Exception saat predict: $e', st.toString());
      _updateState(_state.copyWith(isDetecting: false));
    } catch (e, st) {
      log.c(_tag, 'Error tidak dikenal saat predict: $e', st.toString());
      _updateState(_state.copyWith(isDetecting: false));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODE SWITCHING
  // ─────────────────────────────────────────────────────────────────────────

  void switchMode(DetectMode mode) {
    if (_state.mode == mode) return;
    log.i(_tag, 'Switch mode: ${_state.mode.name} → ${mode.name}');
    _cameraResults = [];
    _updateState(_state.copyWith(
      mode: mode,
      uploadResults: [],
      isDetecting: false,
      clearUploadedImage: true,
      clearAnnotated: true,
    ));
  }

  void toggleDebugPanel() =>
      _updateState(_state.copyWith(showDebugPanel: !_state.showDebugPanel));

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  void _updateState(AppState s) { _state = s; notifyListeners(); }

  @override
  void dispose() {
    _service.dispose();
    log.i(_tag, 'Controller disposed');
    super.dispose();
  }
}