import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/domain/print/print_debug.dart';
import 'package:sip_console/domain/print/print_error.dart';
import 'package:sip_console/domain/print/print_log.dart';
import 'package:sip_console/domain/print/print_success.dart';
import 'package:sip_console/domain/print/print_verbose.dart';
import 'package:sip_console/domain/print/print_warn.dart';

class SipConsole {
  SipConsole({
    Print? success,
    Print? error,
    Print? warn,
    Print? verbose,
    Print? log,
    Print? debug,
  })  : _success = success ?? PrintSuccess(),
        _error = error ?? PrintError(),
        _warn = warn ?? PrintWarn(),
        _verbose = verbose ?? PrintVerbose(),
        _log = log ?? PrintLog(),
        _debug = debug ?? PrintDebug();

  final Print _success;
  final Print _error;
  final Print _warn;
  final Print _verbose;
  final Print _log;
  final Print _debug;

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
    _debug.print(message);
  }
}
