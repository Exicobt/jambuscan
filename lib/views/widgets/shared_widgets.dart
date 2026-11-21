// views/widgets/shared_widgets.dart
import 'package:flutter/material.dart';
import '../../models/detection_model.dart';

class ModelStatusBar extends StatelessWidget {
  final ModelLoadState modelState;
  final String modelError;
  final double fps;
  final bool showFps;

  const ModelStatusBar({super.key, required this.modelState,
      required this.modelError, this.fps = 0, this.showFps = false});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final String msg;
    Widget? trailing;

    switch (modelState) {
      case ModelLoadState.idle:
        bg = const Color(0xFF546E7A); msg = 'Menunggu inisialisasi...'; break;
      case ModelLoadState.loading:
        bg = const Color(0xFFFFA000); msg = 'Memuat model (CPU)...';
        trailing = const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
        break;
      case ModelLoadState.ready:
        bg = const Color(0xFF2E7D32); msg = 'Model aktif (tflite_flutter + CPU)';
        trailing = showFps ? Text('${fps.toStringAsFixed(1)} FPS',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700, fontSize: 13)) : null;
        break;
      case ModelLoadState.failed:
        bg = const Color(0xFFC62828); msg = 'Gagal: $modelError';
        trailing = const Icon(Icons.refresh, color: Colors.white, size: 16);
        break;
    }

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(children: [
        Icon(modelState == ModelLoadState.ready ? Icons.circle
            : modelState == ModelLoadState.loading ? Icons.hourglass_top
            : modelState == ModelLoadState.failed ? Icons.error_outline
            : Icons.pause_circle_outline,
            color: Colors.white, size: 14),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis)),
        if (trailing != null) trailing,
      ]),
    );
  }
}

class DetectionCard extends StatelessWidget {
  final String className;
  final double confidence;
  final Color color;

  const DetectionCard({super.key, required this.className,
      required this.confidence, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(width: 40, height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(className[0].toUpperCase(),
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 18)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(className.toUpperCase(), style: TextStyle(color: color,
                  fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: confidence,
                      backgroundColor: color.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(color), minHeight: 5)),
            ])),
        const SizedBox(width: 14),
        Text('$pct%', style: TextStyle(color: color,
            fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
    );
  }
}

class CountBadge extends StatelessWidget {
  final int count;
  const CountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: const Color(0xFF2D7A3A),
        borderRadius: BorderRadius.circular(20)),
    child: Text('$count', style: const TextStyle(color: Colors.white,
        fontSize: 12, fontWeight: FontWeight.w700)),
  );
}

class UploadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const UploadButton({super.key, required this.icon,
      required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2D7A3A), Color(0xFF4CAF50)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFF2D7A3A).withOpacity(0.3),
            blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    ),
  );
}

class BoundingBoxOverlay extends StatelessWidget {
  final List<DetectionResult> detections;
  final Size imageSize;
  final double widgetWidth;
  final double widgetHeight;

  const BoundingBoxOverlay({super.key, required this.detections,
      required this.imageSize, required this.widgetWidth,
      required this.widgetHeight});

  @override
  Widget build(BuildContext context) {
    if (imageSize == Size.zero) return const SizedBox.shrink();
    final fitted = applyBoxFit(BoxFit.contain, imageSize, Size(widgetWidth, widgetHeight));
    final rendered = fitted.destination;
    final dx = (widgetWidth  - rendered.width)  / 2;
    final dy = (widgetHeight - rendered.height) / 2;
    return Positioned.fill(child: CustomPaint(
      painter: _BoxPainter(detections: detections,
          renderedSize: rendered, offset: Offset(dx, dy)),
    ));
  }
}

class _BoxPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Size renderedSize;
  final Offset offset;

  _BoxPainter({required this.detections, required this.renderedSize, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detections) {
      final color = det.color;
      final l = offset.dx + det.normalizedBox.left   * renderedSize.width;
      final t = offset.dy + det.normalizedBox.top    * renderedSize.height;
      final r = offset.dx + det.normalizedBox.right  * renderedSize.width;
      final b = offset.dy + det.normalizedBox.bottom * renderedSize.height;

      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(l, t, r, b),
          const Radius.circular(4)),
          Paint()..color = color.withOpacity(0.9)
            ..strokeWidth = 2.5..style = PaintingStyle.stroke);

      final label = '${det.className.toUpperCase()}  ${(det.confidence*100).toStringAsFixed(1)}%';
      final tp = TextPainter(text: TextSpan(text: label,
          style: const TextStyle(color: Colors.white, fontSize: 11,
              fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr)..layout();
      const pad = 4.0;
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(l, t - tp.height - pad*2, tp.width + pad*2, tp.height + pad*2),
          const Radius.circular(4)), Paint()..color = color);
      tp.paint(canvas, Offset(l + pad, t - tp.height - pad));
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) =>
      old.detections != detections || old.renderedSize != renderedSize;
}