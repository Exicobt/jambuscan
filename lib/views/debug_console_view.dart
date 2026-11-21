// views/debug_console_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_logger.dart';

class DebugConsoleView extends StatefulWidget {
  const DebugConsoleView({super.key});
  @override
  State<DebugConsoleView> createState() => _DebugConsoleViewState();
}

class _DebugConsoleViewState extends State<DebugConsoleView> {
  final ScrollController _scroll = ScrollController();
  LogLevel? _filter;

  @override
  void initState() { super.initState(); log.addListener(_onLog); }
  @override
  void dispose() { log.removeListener(_onLog); _scroll.dispose(); super.dispose(); }

  void _onLog() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    });
  }

  Color _color(LogLevel l) => switch(l) {
    LogLevel.debug    => const Color(0xFF9E9E9E),
    LogLevel.info     => const Color(0xFF4CAF50),
    LogLevel.warning  => const Color(0xFFFFA000),
    LogLevel.error    => const Color(0xFFE53935),
    LogLevel.critical => const Color(0xFFFF1744),
  };

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == null
        ? log.logs : log.logs.where((e) => e.level == _filter).toList();
    return Container(color: const Color(0xFF0D0D0D),
      child: Column(children: [
        Container(color: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            const Icon(Icons.terminal, color: Color(0xFF4CAF50), size: 16),
            const SizedBox(width: 8),
            Text('Debug Console (${filtered.length}/${log.logs.length})',
                style: const TextStyle(color: Color(0xFF4CAF50),
                    fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700)),
            const Spacer(),
            ...[null, LogLevel.info, LogLevel.warning, LogLevel.error].map((lvl) {
              final label = lvl == null ? 'ALL' : lvl.name.substring(0, 4).toUpperCase();
              final active = _filter == lvl;
              final color = lvl == null ? Colors.white : _color(lvl);
              return GestureDetector(
                onTap: () => setState(() => _filter = lvl),
                child: Container(margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: active ? color.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: active ? color : const Color(0xFF333333)),
                  ),
                  child: Text(label, style: TextStyle(color: active ? color : const Color(0xFF666666),
                      fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.w700))),
              );
            }),
            const SizedBox(width: 8),
            GestureDetector(onTap: () {
              Clipboard.setData(ClipboardData(text: filtered.map((e) => e.toString()).join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Log disalin'), duration: Duration(seconds: 2)));
            }, child: const Icon(Icons.copy, color: Color(0xFF666666), size: 16)),
            const SizedBox(width: 8),
            GestureDetector(onTap: log.clear,
                child: const Icon(Icons.delete_outline, color: Color(0xFF666666), size: 16)),
          ]),
        ),
        Expanded(child: filtered.isEmpty
            ? const Center(child: Text('Tidak ada log',
                style: TextStyle(color: Color(0xFF444444), fontFamily: 'monospace')))
            : ListView.builder(controller: _scroll, padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: filtered.length, itemBuilder: (_, i) {
                  final e = filtered[i];
                  final color = _color(e.level);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.timeLabel, style: const TextStyle(color: Color(0xFF555555),
                          fontFamily: 'monospace', fontSize: 9)),
                      const SizedBox(width: 4),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3)),
                        child: Text(e.levelLabel.trim(), style: TextStyle(color: color,
                            fontFamily: 'monospace', fontSize: 8, fontWeight: FontWeight.w900))),
                      const SizedBox(width: 4),
                      Expanded(child: Text(e.message, style: TextStyle(
                          color: e.level == LogLevel.debug ? const Color(0xFFBBBBBB) : color,
                          fontFamily: 'monospace', fontSize: 9))),
                    ]),
                  );
                })),
      ]),
    );
  }
}