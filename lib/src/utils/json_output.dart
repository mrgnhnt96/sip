import 'dart:convert';

import 'package:sip_cli/src/deps/logger.dart';

/// Writes [payload] to stdout as indented JSON, and nothing else.
///
/// Uses `Logger.write` rather than `info` so `--quiet` cannot swallow the one
/// thing the caller asked for, and so no log level or theme decorates it.
/// Everything sip has to say alongside JSON belongs on stderr.
void writeJson(Object? payload) {
  logger.write('${const JsonEncoder.withIndent('  ').convert(payload)}\n');
}
