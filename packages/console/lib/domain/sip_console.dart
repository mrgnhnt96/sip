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

  final Level _level;

  /// Prints an error message.
  void e(String message) async {
    _error.print(message);
  }

  /// Prints a warning message.
  void w(String message) async {
    _warn.print(message);
  }

  /// Prints a verbose message.
  void v(String message) async {
    if (!_level.isVerbose && !_level.isDebug) return;

    _verbose.print(message);
  }

  /// Prints a log message.
  void l(String message) async {
    _log.print(message);
  }

  /// Prints a success message.
  void s(String message) async {
    _success.print(message);
  }

  /// Prints a debug message.
  void d(String message) async {
    if (!_level.isDebug) return;

    _debug.print(message);
  }

  void emptyLine() async {
    final console = getIt<Console>();

    console.writeLine('');
  }

  void print(String message) async {
    final console = getIt<Console>();

    console.writeLine(message);
  }
}
