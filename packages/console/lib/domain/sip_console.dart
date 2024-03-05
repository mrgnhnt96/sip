import 'package:dart_console2/dart_console2.dart';
import 'package:sip_console/domain/level.dart';
import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/domain/print/print_debug.dart';
import 'package:sip_console/domain/print/print_error.dart';
import 'package:sip_console/domain/print/print_log.dart';
import 'package:sip_console/domain/print/print_success.dart';
import 'package:sip_console/domain/print/print_verbose.dart';
import 'package:sip_console/domain/print/print_warn.dart';
import 'package:sip_console/setup/setup.dart';

/// A console that prints messages to the terminal
class SipConsole {
  SipConsole({
    Print? success,
    Print? error,
    Print? warn,
    Print? verbose,
    Print? log,
    Print? debug,
    Level level = Level.normal,
  })  : _success = success ?? PrintSuccess(),
        _error = error ?? PrintError(),
        _warn = warn ?? PrintWarn(),
        _verbose = verbose ?? PrintVerbose(),
        _log = log ?? PrintLog(),
        _debug = debug ?? PrintDebug(),
        _level = level;

  final Print _success;
  final Print _error;
  final Print _warn;
  final Print _verbose;
  final Print _log;
  final Print _debug;

  Level _level;

  void enableVerbose() {
    _level = Level.verbose;
  }

  /// Prints an error message.
  void e(String message) {
    _error.print(message);
  }

  /// Prints a warning message.
  void w(String message) {
    _warn.print(message);
  }

  /// Prints a verbose message.
  void v(String message) {
    if (!_level.isVerbose && !_level.isDebug) return;

    _verbose.print(message);
  }

  /// Prints a log message.
  void l(String message) {
    _log.print(message);
  }

  /// Prints a success message.
  void s(String message) {
    _success.print(message);
  }

  /// Prints a debug message.
  void d(String message) {
    if (!_level.isDebug) return;

    _debug.print(message);
  }

  void emptyLine() {
    getIt<Console>().writeLine('');
  }

  void print(String message) {
    getIt<Console>().writeLine(message);
  }
}
