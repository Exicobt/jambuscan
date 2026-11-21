// views/detection_page.dart
import 'package:flutter/material.dart';
import '../controllers/detection_controller.dart';
import '../models/detection_model.dart';
import 'camera_view.dart';
import 'upload_view.dart';
import 'debug_console_view.dart';
import 'widgets/shared_widgets.dart';

class DetectionPage extends StatefulWidget {
  const DetectionPage({super.key});
  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  late final DetectionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DetectionController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.initModel());
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white, elevation: 0,
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                onPressed: () => Navigator.pop(context)),
            title: Row(children: [
              Container(width: 32, height: 32,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF2D7A3A), Color(0xFF4CAF50)]),
                    shape: BoxShape.circle),
                child: const Icon(Icons.grass_rounded, color: Colors.white, size: 18)),
              const SizedBox(width: 10),
              const Text('Object Detection',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ]),
            actions: [
              IconButton(
                tooltip: 'Debug Console',
                icon: Icon(Icons.terminal,
                    color: state.showDebugPanel ? const Color(0xFF2D7A3A) : Colors.grey[500]),
                onPressed: _controller.toggleDebugPanel),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(90),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ModelStatusBar(modelState: state.modelState, modelError: state.modelError,
                    fps: state.fps, showFps: state.mode == DetectMode.camera),
                _ModeTab(current: state.mode, onSwitch: _controller.switchMode),
              ]),
            ),
          ),
          body: Column(children: [
            Expanded(child: state.mode == DetectMode.camera
                ? CameraView(controller: _controller)
                : UploadView(controller: _controller)),
            if (state.showDebugPanel)
              const SizedBox(height: 280, child: DebugConsoleView()),
          ]),
        );
      },
    );
  }
}

class _ModeTab extends StatelessWidget {
  final DetectMode current;
  final void Function(DetectMode) onSwitch;
  const _ModeTab({required this.current, required this.onSwitch});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      _tab(DetectMode.camera, Icons.videocam_rounded, 'Live Kamera'),
      _tab(DetectMode.upload, Icons.upload_rounded, 'Upload Foto'),
    ]),
  );

  Widget _tab(DetectMode mode, IconData icon, String label) {
    final selected = current == mode;
    return Expanded(child: GestureDetector(onTap: () => onSwitch(mode),
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.08),
                blurRadius: 6, offset: const Offset(0, 2))] : null),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: selected ? const Color(0xFF2D7A3A) : Colors.grey[500]),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? const Color(0xFF2D7A3A) : Colors.grey[500])),
        ]),
      ),
    ));
  }
}