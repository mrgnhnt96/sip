// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/sip_runner.dart';
import 'package:sip_cli/src/deps/analytics.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/bindings.dart';
import 'package:sip_cli/src/deps/constrain_pubspec_versions.dart';
import 'package:sip_cli/src/deps/device_info.dart';
import 'package:sip_cli/src/deps/find_file.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/is_up_to_date.dart';
import 'package:sip_cli/src/deps/key_press_listener.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/on_death.dart';
import 'package:sip_cli/src/deps/platform.dart';
import 'package:sip_cli/src/deps/process.dart';
import 'package:sip_cli/src/deps/pub_updater.dart';
import 'package:sip_cli/src/deps/pubspec_lock.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/deps/script_runner.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/deps/terminal.dart';
import 'package:sip_cli/src/deps/time.dart';
import 'package:sip_cli/src/deps/variables.dart';
import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/domain/terminal.dart';
import 'package:sip_cli/src/domain/time.dart';
import 'package:sip_cli/src/utils/output_mode.dart';

void main(List<String> arguments) async {
  final args = Args.parse(arguments);

  final logger = Logger(
    level: switch ((args['quiet'], args['loud'])) {
      (true, _) => Level.error,
      (_, true) => Level.verbose,
      (_, _) => Level.info,
    },
  );

  // Colour follows the reader: a terminal gets escape codes, a pipe, a file
  // or a CI log gets plain text. `--color`, `NO_COLOR` and `FORCE_COLOR`
  // override the guess.
  final useAnsi = shouldUseAnsi(
    args: args,
    environment: Platform.environment,
    hasTerminal: const Terminal().hasTerminal,
  );

  await overrideAnsiOutput(useAnsi, () async {
    await runScoped(
      run,
      values: {
        argsProvider.overrideWith(() => args),
        bindingsProvider,
        constrainPubspecVersionsProvider,
        findFileProvider,
        fsProvider,
        isUpToDateProvider,
        keyPressListenerProvider,
        loggerProvider.overrideWith(() => logger),
        platformProvider,
        processProvider,
        pubUpdaterProvider,
        pubspecLockProvider,
        pubspecYamlProvider,
        scriptsYamlProvider,
        terminalProvider,
        variablesProvider,
        scriptRunnerProvider,
        timeProvider,
        deviceInfoProvider,
        analyticsProvider,
        onDeathProvider,
      },
    );
  });
}

Future<void> run() async {
  onDeath
    // always make sure that the cursor is visible
    ..register(() => stdout.write('\x1b[?25h'))
    ..listen();

  // Start the stopwatch
  time.get(TimeKey.core);

  final exitCode = await const SipRunner().run();

  logger.detail('$args Finishing with: $exitCode');

  exit(exitCode.code);
}
