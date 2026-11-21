// views/upload_view.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/detection_controller.dart';
import '../models/detection_model.dart';
import 'widgets/shared_widgets.dart';

class UploadView extends StatelessWidget {
  final DetectionController controller;
  const UploadView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return Column(children: [
      Expanded(flex: 3,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA5D6A7), width: 1.5)),
          child: ClipRRect(borderRadius: BorderRadius.circular(20),
              child: _ImageArea(state: state)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: UploadButton(icon: Icons.camera_alt_rounded,
              label: 'Kamera',
              onTap: () => controller.pickAndDetect(ImageSource.camera))),
          const SizedBox(width: 12),
          Expanded(child: UploadButton(icon: Icons.photo_library_rounded,
              label: 'Galeri',
              onTap: () => controller.pickAndDetect(ImageSource.gallery))),
        ]),
      ),
      const SizedBox(height: 12),
      _ResultPanel(state: state),
    ]);
  }
}

class _ImageArea extends StatelessWidget {
  final AppState state;
  const _ImageArea({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isDetecting) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF2D7A3A)),
          SizedBox(height: 16),
          Text('Mendeteksi...', style: TextStyle(color: Color(0xFF2D7A3A))),
        ],
      ));
    }

    if (state.uploadedImage == null) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF2D7A3A).withOpacity(0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.add_photo_alternate_outlined,
                size: 52, color: Color(0xFF2D7A3A))),
        const SizedBox(height: 16),
        const Text('Pilih gambar jambu', style: TextStyle(color: Color(0xFF2D7A3A),
            fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 6),
        Text('dari kamera atau galeri',
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ]);
    }

    return LayoutBuilder(builder: (context, constraints) => Stack(
      fit: StackFit.expand,
      children: [
        Image.file(state.uploadedImage!, fit: BoxFit.contain,
            width: constraints.maxWidth, height: constraints.maxHeight),
        if (state.uploadResults.isNotEmpty)
          BoundingBoxOverlay(detections: state.uploadResults,
              imageSize: state.imageSizePixels,
              widgetWidth: constraints.maxWidth,
              widgetHeight: constraints.maxHeight),
      ],
    ));
  }
}

class _ResultPanel extends StatelessWidget {
  final AppState state;
  const _ResultPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final results = state.uploadResults;
    return Expanded(flex: 2,
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Hasil Deteksi',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(width: 8),
              if (results.isNotEmpty) CountBadge(count: results.length),
            ]),
            const SizedBox(height: 10),
            Expanded(child: results.isEmpty
                ? Center(child: Text(state.uploadedImage == null
                    ? 'Belum ada gambar dipilih'
                    : 'Tidak ada objek terdeteksi',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14)))
                : ListView.builder(itemCount: results.length,
                    itemBuilder: (_, i) => DetectionCard(
                        className: results[i].className,
                        confidence: results[i].confidence,
                        color: results[i].color))),
          ],
        ),
      ),
    );
  }
}