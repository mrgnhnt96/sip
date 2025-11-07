// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/sip_runner.dart';
import 'package:sip_cli/src/deps/bindings.dart';
import 'package:sip_cli/src/deps/constrain_pubspec_versions.dart';
import 'package:sip_cli/src/deps/find.dart';
import 'package:sip_cli/src/deps/find_file.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/is_up_to_date.dart';
import 'package:sip_cli/src/deps/key_press_listener.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/platform.dart';
import 'package:sip_cli/src/deps/process.dart';
import 'package:sip_cli/src/deps/pub_updater.dart';
import 'package:sip_cli/src/deps/pubspec_lock.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/deps/run_many_scripts.dart';
import 'package:sip_cli/src/deps/run_one_script.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/deps/variables.dart';

void main(List<String> args) async {
  await runScoped(
    () => run(args),
    values: {
      bindingsProvider,
      constrainPubspecVersionsProvider,
      findFileProvider,
      findProvider,
      fsProvider,
      isUpToDateProvider,
      keyPressListenerProvider,
      loggerProvider,
      platformProvider,
      processProvider,
      pubUpdaterProvider,
      pubspecLockProvider,
      pubspecYamlProvider,
      runManyScriptsProvider,
      runOneScriptProvider,
      scriptsYamlProvider,
      variablesProvider,
    },
  );
}

Future<void> run(List<String> arguments) async {
  ProcessSignal.sigint.watch().listen((signal) {
    // always make sure that the cursor is visible
    stdout.write('\x1b[?25h');
    exit(1);
  }, cancelOnError: true);

  final args = List<String>.from(arguments);

  var loud = false;
  var quiet = false;

  if (args.contains('--quiet')) {
    quiet = true;
  } else if (args.contains('--loud')) {
    loud = true;
  }

  final logger = Logger(
    level: switch ((quiet, loud)) {
      (true, _) => Level.error,
      (_, true) => Level.verbose,
      (_, _) => Level.info,
    },
  );

  final exitCode = await SipRunner(ogArgs: args).run(args);

  logger.detail('$args Finishing with: $exitCode');

  exit(exitCode.code);
}
