// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:file/local.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:sip_cli/domain/domain.dart';
import 'package:sip_cli/sip_runner.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:sip_script_runner/utils/logger.dart' as script_runner;

void main(List<String> _) async {
  final args = List<String>.from(_);

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

  script_runner.Logger.setup(
    detail: logger.detail,
    err: logger.err,
    warn: logger.warn,
    write: logger.write,
  );

  final exitCode = await SipRunner(
    bindings: const BindingsImpl(),
    scriptsYaml: scriptsYaml,
    findFile: const FindFile(fs: fs),
    pubspecLock: const PubspecLockImpl(fs: fs),
    pubspecYaml: pubspecYaml,
    variables: const Variables(
      cwd: cwd,
      pubspecYaml: pubspecYaml,
      scriptsYaml: scriptsYaml,
    ),
    fs: fs,
    logger: logger,
    cwd: cwd,
    pubUpdater: PubUpdater(),
  ).run(args);

  logger.detail('$args Finishing with: $exitCode');

  exit(exitCode.code);
}
