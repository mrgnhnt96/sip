import 'package:sip_cli/src/domain/args.dart';

/// Environment variables that turn parts of sip's decoration off.
class OutputEnv {
  const OutputEnv._();

  /// https://no-color.org — set to any non-empty value to disable colour.
  static const String noColor = 'NO_COLOR';

  /// Set to any non-empty value to force colour on, even when piped.
  static const String forceColor = 'FORCE_COLOR';

  /// Set to any non-empty value to skip the "a new version is available"
  /// check, including the network request it makes.
  static const String noVersionCheck = 'SIP_NO_VERSION_CHECK';
}

/// Whether sip should wrap its output in ANSI escape codes.
///
/// sip used to force these on unconditionally, so a piped `sip list` handed
/// its reader a tree full of `\x1b[92m`. Anything reading sip's output --
/// a shell pipeline, a CI log, an AI coding assistant -- now gets plain text
/// unless it asks otherwise.
///
/// In precedence order:
/// 1. An explicit `--color` / `--no-color` flag.
/// 2. `NO_COLOR` (off) then `FORCE_COLOR` (on).
/// 3. `TERM=dumb` turns it off.
/// 4. Otherwise it follows whether stdout is a terminal.
bool shouldUseAnsi({
  required Args args,
  required Map<String, String> environment,
  required bool hasTerminal,
}) {
  if (args.getOrNull<bool>('color') case final bool color) {
    return color;
  }

  if (_isSet(environment[OutputEnv.noColor])) return false;
  if (_isSet(environment[OutputEnv.forceColor])) return true;

  if (environment['TERM'] == 'dumb') return false;

  return hasTerminal;
}

/// Whether sip should check pub.dev for a newer version of itself.
///
/// The check costs a network round trip and prints a sentence that is only
/// actionable to a human sitting at a terminal. Skipping it when nobody is
/// watching keeps scripted output clean and every scripted run faster.
///
/// In precedence order:
/// 1. `--no-version-check` (or `--version-check`).
/// 2. `SIP_NO_VERSION_CHECK`.
/// 3. Otherwise it follows whether stdout is a terminal.
bool shouldCheckVersion({
  required Args args,
  required Map<String, String> environment,
  required bool hasTerminal,
}) {
  if (args.getOrNull<bool>('version-check') case final bool check) {
    return check;
  }

  if (_isSet(environment[OutputEnv.noVersionCheck])) return false;

  return hasTerminal;
}

bool _isSet(String? value) => value != null && value.isNotEmpty;
