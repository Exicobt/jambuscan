// utils/app_logger.dart
// ─────────────────────────────────────────────────────────────────────────────
// Sistem logging terpusat dengan level, tag, dan timestamp.
// Semua log dari Model, Controller, dan View diarahkan ke sini.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error, critical }

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;
  final String? detail; // stack trace atau info tambahan

  LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    this.detail,
  }) : time = DateTime.now();

  String get levelLabel {
    switch (level) {
      case LogLevel.debug:    return 'DEBUG';
      case LogLevel.info:     return 'INFO ';
      case LogLevel.warning:  return 'WARN ';
      case LogLevel.error:    return 'ERROR';
      case LogLevel.critical: return 'CRIT ';
    }
  }

  String get timeLabel =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}.'
      '${(time.millisecond ~/ 10).toString().padLeft(2, '0')}';

  @override
  String toString() => '[$timeLabel][$levelLabel][$tag] $message'
      '${detail != null ? '\n  ↳ $detail' : ''}';
}

class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  // Simpan log dalam memori agar bisa ditampilkan di Debug Console UI
  final List<LogEntry> _logs = [];
  static const int _maxLogs = 500;

  // Listener agar UI bisa reaktif saat ada log baru
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback cb) => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void _add(LogLevel level, String tag, String message, [String? detail]) {
    final entry = LogEntry(level: level, tag: tag, message: message, detail: detail);

    // Print ke console Flutter (hanya di debug mode)
    if (kDebugMode) {
      final prefix = _consolePrefix(level);
      debugPrint('$prefix ${entry.toString()}');
    }

    _logs.add(entry);
    if (_logs.length > _maxLogs) _logs.removeAt(0);

    for (final cb in List.of(_listeners)) {
      cb();
    }
  }

  String _consolePrefix(LogLevel l) {
    switch (l) {
      case LogLevel.debug:    return '🔍';
      case LogLevel.info:     return '✅';
      case LogLevel.warning:  return '⚠️ ';
      case LogLevel.error:    return '❌';
      case LogLevel.critical: return '🔥';
    }
  }

  // ── Public API ──
  void d(String tag, String msg, [String? detail]) =>
      _add(LogLevel.debug,   tag, msg, detail);
  void i(String tag, String msg, [String? detail]) =>
      _add(LogLevel.info,    tag, msg, detail);
  void w(String tag, String msg, [String? detail]) =>
      _add(LogLevel.warning, tag, msg, detail);
  void e(String tag, String msg, [String? detail]) =>
      _add(LogLevel.error,   tag, msg, detail);
  void c(String tag, String msg, [String? detail]) =>
      _add(LogLevel.critical, tag, msg, detail);

  void clear() {
    _logs.clear();
    for (final cb in List.of(_listeners)) cb();
  }
}

// Shorthand global
final log = AppLogger.instance;