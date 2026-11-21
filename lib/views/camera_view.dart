// views/camera_view.dart
// ─────────────────────────────────────────────────────────────────────────────
// Live camera view menggunakan package:camera.
// Setiap frame dikonversi ke JPEG lalu dikirim ke controller untuk inferensi.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../controllers/detection_controller.dart';
import '../models/detection_model.dart';
import '../utils/app_logger.dart';
import 'widgets/shared_widgets.dart';

class CameraView extends StatefulWidget {
  final DetectionController controller;
  const CameraView({super.key, required this.controller});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  CameraController? _cam;
  bool _camReady = false;
  String _camError = '';
  int _frameCount = 0;
  DateTime _lastFpsTime = DateTime.now();
  static const int _processEveryNFrames = 5; // Proses 1 dari setiap N frame

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    log.i('CameraView', 'Menginisialisasi kamera...');
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _camError = 'Tidak ada kamera tersedia');
        log.e('CameraView', 'Tidak ada kamera');
        return;
      }

      // Pilih kamera belakang
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      log.i('CameraView', 'Kamera dipilih: ${back.name}');

      _cam = CameraController(
        back,
        ResolutionPreset.medium, // medium = 720p, cukup untuk YOLO 640×640
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg, // JPEG lebih mudah diproses
      );

      await _cam!.initialize();
      log.i('CameraView', 'Kamera ready: ${_cam!.value.previewSize}');

      // Mulai stream frame
      await _cam!.startImageStream(_onFrame);
      if (mounted) setState(() => _camReady = true);
    } catch (e) {
      log.e('CameraView', 'Gagal init kamera: $e');
      if (mounted) setState(() => _camError = e.toString());
    }
  }

  void _onFrame(CameraImage frame) {
    _frameCount++;

    // Hitung FPS
    final now = DateTime.now();
    final elapsed = now.difference(_lastFpsTime).inMilliseconds;
    if (elapsed >= 1000) {
      final fps = _frameCount * 1000 / elapsed;
      widget.controller.updateFps(fps);
      _frameCount = 0;
      _lastFpsTime = now;
    }

    // Proses hanya setiap N frame agar tidak overload CPU
    if (_frameCount % _processEveryNFrames != 0) return;

    // Konversi CameraImage ke JPEG bytes
    final bytes = _cameraImageToJpeg(frame);
    if (bytes != null) {
      widget.controller.processCameraFrame(bytes);
    }
  }

  Uint8List? _cameraImageToJpeg(CameraImage frame) {
    try {
      // Untuk format JPEG (Android), planes[0] langsung berisi JPEG bytes
      if (frame.format.group == ImageFormatGroup.jpeg) {
        return frame.planes[0].bytes;
      }
      // Format lain tidak didukung di sini
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cam == null || !_cam!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cam!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _buildCameraArea(),
        ),
        _buildResultPanel(),
      ],
    );
  }

  Widget _buildCameraArea() {
    if (_camError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text('Kamera error:\n$_camError',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ],
        ),
      );
    }

    if (!_camReady || _cam == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF2D7A3A)),
            SizedBox(height: 12),
            Text('Memuat kamera...'),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Preview kamera
            ClipRect(
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxWidth / _cam!.value.aspectRatio,
                    child: CameraPreview(_cam!),
                  ),
                ),
              ),
            ),
            // Overlay bounding box hasil deteksi
            if (widget.controller.cameraResults.isNotEmpty)
              BoundingBoxOverlay(
                detections: widget.controller.cameraResults,
                imageSize: Size(
                  _cam!.value.previewSize?.height ?? 640,
                  _cam!.value.previewSize?.width  ?? 480,
                ),
                widgetWidth: constraints.maxWidth,
                widgetHeight: constraints.maxHeight,
              ),
          ],
        );
      },
    );
  }

  Widget _buildResultPanel() {
    final results = widget.controller.cameraResults;
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Hasil Deteksi',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(width: 8),
                if (results.isNotEmpty) CountBadge(count: results.length),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text('Arahkan kamera ke buah jambu...',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, i) => DetectionCard(
                        className: results[i].className,
                        confidence: results[i].confidence,
                        color: results[i].color,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}