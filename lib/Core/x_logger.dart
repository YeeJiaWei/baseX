import 'package:flutter/foundation.dart';

enum LogType { error, warning, success, response }

/// Readable logger.
///
/// The previous implementation used ANSI colour escapes and box-drawing
/// banners. Consoles that don't interpret ANSI (iOS simulator Run window,
/// VS Code Debug Console) render those escapes as literal `^[[38;5;..m` noise,
/// so this version leans on emoji markers + indentation for visual structure,
/// which render in every console. Set [ansiColor] to true when viewing logs in
/// a real terminal (`flutter run`) to additionally get true ANSI colours.
class XLogger {
  /// Enable true ANSI colours. Leave false for consoles that show raw escape
  /// codes; set true only in a terminal that renders ANSI.
  static const bool ansiColor = false;

  static const String _reset = '\x1B[0m';

  /// Wraps [s] in an ANSI SGR [code] when [ansiColor] is on, else returns it
  /// unchanged.
  static String _c(String code, String s) =>
      ansiColor ? '\x1B[${code}m$s$_reset' : s;

  /// Matches a leading run of box-drawing characters so they can be stripped.
  static final RegExp _boxLead = RegExp(r'^[\s║╟╠╣╔╚╗╝═━│┃|]+');

  /// Matches lines made up entirely of box-drawing characters / whitespace.
  static final RegExp _boxOnly = RegExp(r'^[\s║╟╠╣╔╚╗╝═━│┃|]*$');

  // ── Tagged one-off logs ──

  static void warning(Object? msg, {String? className}) =>
      _tagged('⚠️', '1;33', 'WARN', msg, className);

  static void info(Object? msg, {String? className}) =>
      _tagged('ℹ️', '1;34', 'INFO', msg, className);

  static void success(Object? msg, {String? className}) =>
      _tagged('✅', '1;32', 'OK', msg, className);

  static void error(Object? msg, {String? className}) =>
      _tagged('🔴', '1;31', 'ERROR', msg, className);

  static void _tagged(
      String emoji, String color, String tag, Object? msg, String? className) {
    final label = className != null ? '$tag · $className' : tag;
    debugPrint('$emoji ${_c(color, '[$label]')} $msg');
  }

  // ── HTTP request / response / error block logging ──
  // One icon per block at the top — 🔵 request (outgoing), 🟢 success
  // response, 🔴 failed — with a left border `│` wrapping the body and a
  // `└` closing the block. The icon reflects the outcome directly.

  static void reqHead(String mid) => _open('🔵', '1;36', mid);
  static void reqBody(String text) => _mid('1;36', text);
  static void reqTail(String mid) => _close('1;36');

  static void resHead(String mid) => _open('🟢', '1;32', mid);
  static void resBody(String text) => _mid('1;32', text);
  static void resTail(String mid) => _close('1;32');

  static void errorHead(String mid) => _open('🔴', '1;31', mid);
  static void errorBody(String text) => _mid('1;31', text);
  static void errorTail(String mid) => _close('1;31');

  /// Prints a whole HTTP exchange as one bordered block with a single outcome
  /// icon at the top — 🟢 success / 🔴 failed. [lines] are already cleaned
  /// (request lines prefixed `→`, response lines `←`).
  static void httpBlock({
    required bool failed,
    required String title,
    required List<String> lines,
  }) {
    final emoji = failed ? '🔴' : '🟢';
    final color = failed ? '1;31' : '1;32';
    debugPrint('$emoji ${_c(color, '┌──── $title ────')}');
    for (final line in lines) {
      debugPrint('   ${_c(color, '│')} $line');
    }
    debugPrint('   ${_c(color, '└──────────────────────')}');
  }

  /// Opens a block with the single outcome icon, e.g.
  /// `🟢 ┌──── RESPONSE ────`.
  static void _open(String emoji, String color, String mid) {
    final label = mid.trim().replaceFirst('START ', '');
    debugPrint('$emoji ${_c(color, '┌──── $label ────')}');
  }

  /// Body line inside the block, prefixed with the left border `│`. Strips
  /// the source box-drawing decoration and drops pure spacers / `#####`
  /// section markers.
  static void _mid(String color, String text) {
    if (text.contains('##########')) return;
    if (_boxOnly.hasMatch(text)) return;
    final clean = text.replaceFirst(_boxLead, '').trimRight();
    if (clean.isEmpty) return;
    debugPrint('   ${_c(color, '│')} $clean');
  }

  /// Closes the block with the bottom-left border, e.g. `   └────────────`.
  static void _close(String color) {
    debugPrint('   ${_c(color, '└──────────────────────')}');
  }
}
