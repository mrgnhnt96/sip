import 'dart:async';

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

  Completer<void>? _completer;

  Finishers progress(Iterable<String> entries) {
    _completer = Completer<void>();
    return _progress.start(entries, () {
      _completer?.complete();
    });
  }

  /// Prints an error message.
  void e(String message) async {
    await _completer?.future;

    _error.print(message);
  }

  /// Prints a warning message.
  void w(String message) async {
    await _completer?.future;

    _warn.print(message);
  }

  /// Prints a verbose message.
  void v(String message) async {
    await _completer?.future;

    _verbose.print(message);
  }

  /// Prints a log message.
  void l(String message) async {
    await _completer?.future;

    _log.print(message);
  }

  /// Prints a success message.
  void s(String message) async {
    await _completer?.future;

    _success.print(message);
  }

  /// Prints a debug message.
  void d(String message) async {
    await _completer?.future;

    _debug.print(message);
  }
}
