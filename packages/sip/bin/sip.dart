// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:file/local.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:sip_cli/domain/bindings_impl.dart';
import 'package:sip_cli/domain/domain.dart';
import 'package:sip_cli/domain/variables.dart';
import 'package:sip_cli/sip_runner.dart';
import 'package:sip_cli/utils/key_press_listener.dart';

void main(List<String> arguments) async {
  ProcessSignal.sigint.watch().listen(
        (signal) => exit(1),
        cancelOnError: true,
      );

  final args = List<String>.from(arguments);

  var loud = false;
  var quiet = false;

  if (args.contains('--quiet')) {
    quiet = true;
  } else if (args.contains('--loud')) {
    loud = true;
  }

  final logger = Logger(
    level: quiet
        ? Level.error
        : loud
            ? Level.verbose
            : Level.info,
  );

  const fs = LocalFileSystem();

  const scriptsYaml = ScriptsYamlImpl(fs: fs);
  const pubspecYaml = PubspecYamlImpl(fs: fs);
  const cwd = CWDImpl(fs: fs);
  final bindings = BindingsImpl(
    logger: logger,
  );

  final runOneScript = RunOneScript(
    bindings: bindings,
    logger: logger,
  );

  final runManyScripts = RunManyScripts(
    bindings: bindings,
    logger: logger,
    runOneScript: runOneScript,
  );

  final exitCode = await SipRunner(
    ogArgs: args,
    bindings: bindings,
    scriptsYaml: scriptsYaml,
    findFile: const FindFile(fs: fs),
    pubspecLock: const PubspecLockImpl(fs: fs),
    pubspecYaml: pubspecYaml,
    variables: Variables(
      cwd: cwd,
      pubspecYaml: pubspecYaml,
      scriptsYaml: scriptsYaml,
    ),
    fs: fs,
    logger: logger,
    cwd: cwd,
    pubUpdater: PubUpdater(),
    runOneScript: runOneScript,
    runManyScripts: runManyScripts,
    keyPressListener: KeyPressListener(logger: logger),
  ).run(args);

  logger.detail('$args Finishing with: $exitCode');

  exit(exitCode.code);
}
