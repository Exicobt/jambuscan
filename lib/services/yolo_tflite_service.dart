// services/yolo_tflite_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Menggantikan plugin ultralytics_yolo sepenuhnya.
// Menggunakan tflite_flutter dengan:
//   - CPU delegate (stabil di semua device termasuk Redmi MIUI)
//   - XNNPack delegate sebagai opsional (lebih cepat dari CPU biasa)
//   - Preprocessing YOLO manual (resize + normalize + letterbox)
//   - Postprocessing output [1, 7, 8400] → List<YoloDetection>
//
// Output shape model YOLOv8: [1, num_classes+4, 8400]
//   - 8400 = jumlah anchor
//   - baris 0-3 = cx, cy, w, h (ternormalisasi 0-1)
//   - baris 4-N = confidence per class
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../utils/app_logger.dart';

// ── Satu hasil deteksi ────────────────────────────────────────────────────

class YoloDetection {
  final int classIndex;
  final String className;
  final double confidence;

  // Koordinat ternormalisasi 0.0–1.0 (relatif ke gambar input asli)
  final double x1, y1, x2, y2;

  const YoloDetection({
    required this.classIndex,
    required this.className,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  @override
  String toString() =>
      'YoloDetection(class=$className conf=${(confidence*100).toStringAsFixed(1)}% '
      'box=[$x1,$y1,$x2,$y2])';
}

// ── Service utama ─────────────────────────────────────────────────────────

class YoloTfliteService {
  static const String _tag = 'YoloService';

  // ── Config — sesuaikan dengan model kamu ─────────────────────────────────
  static const int inputSize = 640;       // YOLOv8 default input 640×640
  static const int _numClasses = 3;       // matang, mentah, busuk
  static const List<String> classNames = ['matang', 'mentah', 'busuk'];

  // Interpreter TFLite
  Interpreter? _interpreter;
  bool get isLoaded => _interpreter != null;

  // ─────────────────────────────────────────────────────────────────────────
  // LOAD MODEL
  // ─────────────────────────────────────────────────────────────────────────

  /// [assetPath]: path di pubspec assets, misal 'assets/models/model.tflite'
  /// [useCpuOnly]: true = paksa CPU, false = coba XNNPack dulu
  Future<void> loadModel(String assetPath, {bool useCpuOnly = true}) async {
    log.i(_tag, 'Memuat model: $assetPath (CPU only: $useCpuOnly)');

    try {
      // Tutup interpreter lama jika ada
      _interpreter?.close();
      _interpreter = null;

      // Baca model dari assets
      final data = await rootBundle.load(assetPath);
      final modelBuffer = data.buffer.asUint8List(
        data.offsetInBytes, data.lengthInBytes,
      );
      log.d(_tag, 'Model bytes: ${modelBuffer.length}');

      // ── Opsi interpreter ────────────────────────────────────────────────
      final options = InterpreterOptions()
        ..threads = 4;  // 4 CPU threads, aman di semua device

      if (!useCpuOnly) {
        // XNNPack: lebih cepat dari CPU biasa, tidak pakai GPU sehingga aman
        // di Redmi MIUI
        try {
          options.addDelegate(XNNPackDelegate());
          log.i(_tag, 'XNNPack delegate ditambahkan');
        } catch (e) {
          log.w(_tag, 'XNNPack tidak tersedia, fallback ke CPU biasa: $e');
        }
      }

      _interpreter = Interpreter.fromBuffer(modelBuffer, options: options);

      // ── Log info tensor ─────────────────────────────────────────────────
      final inputShape  = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      log.i(_tag, 'Model loaded ✅',
          'Input:  $inputShape\nOutput: $outputShape');

      // Validasi output shape: harus [1, numClasses+4, 8400]
      final expectedRows = _numClasses + 4;
      if (outputShape.length < 3 || outputShape[1] != expectedRows) {
        log.w(_tag,
            'Output shape tidak sesuai ekspektasi!',
            'Ekspektasi: [1, $expectedRows, 8400]\n'
            'Aktual:     $outputShape\n'
            'Sesuaikan _numClasses di YoloTfliteService jika berbeda');
      }
    } catch (e, st) {
      _interpreter = null;
      log.e(_tag, 'Gagal load model: $e', st.toString());
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PREDICT
  // ─────────────────────────────────────────────────────────────────────────

  /// Menerima gambar sebagai Uint8List (JPEG/PNG bytes)
  /// Mengembalikan List<YoloDetection> yang sudah di-NMS
  Future<List<YoloDetection>> predict(
    Uint8List imageBytes, {
    double confidenceThreshold = 0.25,
    double iouThreshold = 0.45,
  }) async {
    if (_interpreter == null) {
      log.e(_tag, 'predict() dipanggil sebelum loadModel()');
      return [];
    }

    final watch = Stopwatch()..start();

    // 1. Decode gambar
    log.d(_tag, 'Decoding gambar...');
    final img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      log.e(_tag, 'Gagal decode gambar');
      return [];
    }
    log.d(_tag, 'Gambar decoded: ${decoded.width}×${decoded.height}');

    // 2. Letterbox resize ke 640×640
    final preprocessed = _letterboxResize(decoded, inputSize, inputSize);

    // 3. Konversi ke Float32 input tensor [1, 640, 640, 3]
    final inputTensor = _imageToFloat32(preprocessed.image);
    log.d(_tag, 'Preprocessing: ${watch.elapsedMilliseconds} ms');

    // 4. Siapkan output tensor [1, numClasses+4, 8400]
    final int numAnchors = 8400;
    final int numRows    = _numClasses + 4;
    final output = List.generate(
      1, (_) => List.generate(
        numRows, (_) => List.filled(numAnchors, 0.0),
      ),
    );

    // 5. Inference
    final inferStart = watch.elapsedMilliseconds;
    _interpreter!.run(inputTensor, output);
    log.i(_tag,
        'Inference: ${watch.elapsedMilliseconds - inferStart} ms',
        'Total preprocessing+inference: ${watch.elapsedMilliseconds} ms');

    // 6. Postprocessing: decode boxes + NMS
    final detections = _postprocess(
      output[0],
      numAnchors: numAnchors,
      confThreshold: confidenceThreshold,
      iouThreshold: iouThreshold,
      letterbox: preprocessed,
      origW: decoded.width.toDouble(),
      origH: decoded.height.toDouble(),
    );

    watch.stop();
    log.i(_tag,
        '${detections.length} objek terdeteksi (total: ${watch.elapsedMilliseconds} ms)',
        detections.isEmpty
            ? 'Tidak ada deteksi di atas threshold $confidenceThreshold'
            : detections.map((d) => d.toString()).join('\n'));

    return detections;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PREPROCESSING
  // ─────────────────────────────────────────────────────────────────────────

  /// Letterbox resize: pertahankan aspek rasio, padding dengan abu-abu (114,114,114)
  _LetterboxResult _letterboxResize(img.Image src, int targetW, int targetH) {
    final double scaleW = targetW / src.width;
    final double scaleH = targetH / src.height;
    final double scale  = math.min(scaleW, scaleH);

    final int newW = (src.width  * scale).round();
    final int newH = (src.height * scale).round();
    final int padLeft = ((targetW - newW) / 2).round();
    final int padTop  = ((targetH - newH) / 2).round();

    // Resize
    final resized = img.copyResize(src, width: newW, height: newH,
        interpolation: img.Interpolation.linear);

    // Buat canvas abu-abu (114, 114, 114) — warna padding standar YOLO
    final canvas = img.Image(width: targetW, height: targetH);
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));

    // Tempel gambar di tengah canvas
    img.compositeImage(canvas, resized, dstX: padLeft, dstY: padTop);

    log.d('YoloService',
        'Letterbox: ${src.width}×${src.height} → ${newW}×${newH}'
        ' (pad L=$padLeft T=$padTop scale=$scale)');

    return _LetterboxResult(
      image: canvas,
      scale: scale,
      padLeft: padLeft,
      padTop: padTop,
    );
  }

  /// Konversi img.Image → Float32List [1, H, W, 3] dengan normalisasi /255
  List<List<List<List<double>>>> _imageToFloat32(img.Image image) {
    final h = image.height;
    final w = image.width;

    // Shape: [1, h, w, 3]
    final tensor = List.generate(1, (_) =>
      List.generate(h, (y) =>
        List.generate(w, (x) {
          final pixel = image.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        })
      )
    );
    return tensor;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POSTPROCESSING
  // ─────────────────────────────────────────────────────────────────────────

  /// output: [numRows][numAnchors] — baris 0-3 = cx,cy,w,h; baris 4+ = class conf
  List<YoloDetection> _postprocess(
    List<List<double>> output, {
    required int numAnchors,
    required double confThreshold,
    required double iouThreshold,
    required _LetterboxResult letterbox,
    required double origW,
    required double origH,
  }) {
    final candidates = <_RawDetection>[];

    for (int a = 0; a < numAnchors; a++) {
      // Cari class dengan confidence tertinggi
      double maxConf = 0;
      int    maxIdx  = 0;
      for (int c = 0; c < _numClasses; c++) {
        final conf = output[4 + c][a];
        if (conf > maxConf) { maxConf = conf; maxIdx = c; }
      }

      if (maxConf < confThreshold) continue;

      // cx, cy, w, h dalam koordinat 640×640
      final cx = output[0][a];
      final cy = output[1][a];
      final w  = output[2][a];
      final h  = output[3][a];

      // Konversi ke piksel 640×640
      final x1_640 = cx - w / 2;
      final y1_640 = cy - h / 2;
      final x2_640 = cx + w / 2;
      final y2_640 = cy + h / 2;

      // Hapus padding letterbox dan normalisasi ke gambar asli
      final scale   = letterbox.scale;
      final padLeft = letterbox.padLeft.toDouble();
      final padTop  = letterbox.padTop.toDouble();

      double normX1 = ((x1_640 - padLeft) / scale) / origW;
      double normY1 = ((y1_640 - padTop)  / scale) / origH;
      double normX2 = ((x2_640 - padLeft) / scale) / origW;
      double normY2 = ((y2_640 - padTop)  / scale) / origH;

      // Klem ke [0, 1]
      normX1 = normX1.clamp(0.0, 1.0);
      normY1 = normY1.clamp(0.0, 1.0);
      normX2 = normX2.clamp(0.0, 1.0);
      normY2 = normY2.clamp(0.0, 1.0);

      if (normX2 <= normX1 || normY2 <= normY1) continue;

      candidates.add(_RawDetection(
        classIndex: maxIdx,
        confidence: maxConf,
        x1: normX1, y1: normY1,
        x2: normX2, y2: normY2,
      ));
    }

    log.d('YoloService',
        '${candidates.length} kandidat sebelum NMS (threshold=$confThreshold)');

    // NMS per class
    final afterNms = _nmsPerClass(candidates, iouThreshold);

    return afterNms.map((d) => YoloDetection(
      classIndex: d.classIndex,
      className: classNames[d.classIndex],
      confidence: d.confidence,
      x1: d.x1, y1: d.y1, x2: d.x2, y2: d.y2,
    )).toList();
  }

  // ── Non-Maximum Suppression per class ────────────────────────────────────

  List<_RawDetection> _nmsPerClass(
    List<_RawDetection> detections,
    double iouThreshold,
  ) {
    final result = <_RawDetection>[];

    for (int c = 0; c < _numClasses; c++) {
      final classDetections = detections
          .where((d) => d.classIndex == c)
          .toList()
        ..sort((a, b) => b.confidence.compareTo(a.confidence));

      final kept = <_RawDetection>[];
      for (final det in classDetections) {
        bool suppress = false;
        for (final k in kept) {
          if (_iou(det, k) > iouThreshold) { suppress = true; break; }
        }
        if (!suppress) kept.add(det);
      }
      result.addAll(kept);
    }

    return result;
  }

  double _iou(_RawDetection a, _RawDetection b) {
    final interX1 = math.max(a.x1, b.x1);
    final interY1 = math.max(a.y1, b.y1);
    final interX2 = math.min(a.x2, b.x2);
    final interY2 = math.min(a.y2, b.y2);

    if (interX2 <= interX1 || interY2 <= interY1) return 0.0;

    final inter = (interX2 - interX1) * (interY2 - interY1);
    final aArea = (a.x2 - a.x1) * (a.y2 - a.y1);
    final bArea = (b.x2 - b.x1) * (b.y2 - b.y1);
    return inter / (aArea + bArea - inter);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    log.i(_tag, 'Interpreter ditutup');
  }
}

// ── Internal data classes ─────────────────────────────────────────────────

class _LetterboxResult {
  final img.Image image;
  final double scale;
  final int padLeft;
  final int padTop;
  const _LetterboxResult({
    required this.image,
    required this.scale,
    required this.padLeft,
    required this.padTop,
  });
}

class _RawDetection {
  final int classIndex;
  final double confidence;
  final double x1, y1, x2, y2;
  const _RawDetection({
    required this.classIndex,
    required this.confidence,
    required this.x1, required this.y1,
    required this.x2, required this.y2,
  });
}