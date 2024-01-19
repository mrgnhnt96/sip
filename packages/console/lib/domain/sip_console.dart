import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/domain/print/print_debug.dart';
import 'package:sip_console/domain/print/print_error.dart';
import 'package:sip_console/domain/print/print_log.dart';
import 'package:sip_console/domain/print/print_success.dart';
import 'package:sip_console/domain/print/print_verbose.dart';
import 'package:sip_console/domain/print/print_warn.dart';
import 'package:sip_console/domain/progress/finisher.dart';
import 'package:sip_console/domain/progress/progress.dart';

class SipConsole {
  SipConsole({
    Print? success,
    Print? error,
    Print? warn,
    Print? verbose,
    Print? log,
    Print? debug,
    Progress? progress,
  })  : _success = success ?? PrintSuccess(),
        _error = error ?? PrintError(),
        _warn = warn ?? PrintWarn(),
        _verbose = verbose ?? PrintVerbose(),
        _log = log ?? PrintLog(),
        _debug = debug ?? PrintDebug(),
        _progress = progress ?? Progress();

  final Print _success;
  final Print _error;
  final Print _warn;
  final Print _verbose;
  final Print _log;
  final Print _debug;
  final Progress _progress;

  Finishers progress(Iterable<String> entries) {
    return _progress.start(entries);
  }

  /// Prints an error message.
  void e(String message) => _error.print(message);

  /// Prints a warning message.
  void w(String message) => _warn.print(message);

  /// Prints a verbose message.
  void v(String message) => _verbose.print(message);

  /// Prints a log message.
  void l(String message) => _log.print(message);

  /// Prints a success message.
  void s(String message) => _success.print(message);

  /// Prints a debug message.
  void d(String message) => _debug.print(message);
}
