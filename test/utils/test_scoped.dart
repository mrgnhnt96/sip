import 'dart:async';

import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scoped_deps/scoped_deps.dart';
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
import 'package:sip_cli/src/deps/platform.dart';
import 'package:sip_cli/src/deps/process.dart';
import 'package:sip_cli/src/deps/pub_updater.dart';
import 'package:sip_cli/src/deps/pubspec_lock.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/deps/script_runner.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/deps/time.dart';
import 'package:sip_cli/src/deps/variables.dart';
import 'package:sip_cli/src/domain/analytics.dart';
import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/constrain_pubspec_versions.dart';
import 'package:sip_cli/src/domain/device_info.dart';
import 'package:sip_cli/src/domain/find_file.dart';
import 'package:sip_cli/src/domain/pubspec_lock.dart';
import 'package:sip_cli/src/domain/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/script_runner.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:sip_cli/src/domain/time.dart';
import 'package:test/test.dart';

void testScoped(
  String description,
  FutureOr<void> Function() fn, {
  FileSystem Function()? fileSystem,
  Bindings Function()? bindings,
  Logger Function()? logger,
  ConstrainPubspecVersions Function()? constrainPubspecVersions,
  ScriptsYaml Function()? scriptsYaml,
  PubspecLock Function()? pubspecLock,
  FindFile Function()? findFile,
  PubspecYaml Function()? pubspecYaml,
  ScriptRunner Function()? scriptRunner,
  Args Function()? args,
}) {
  test(description, () async {
    final mockLogger = _MockLogger();
    when(() => mockLogger.level).thenReturn(Level.quiet);
    when(() => mockLogger.progress(any())).thenReturn(_MockProgress());

    final testProviders = {
      isUpToDateProvider,
      keyPressListenerProvider,
      platformProvider,
      processProvider,
      pubUpdaterProvider,
      variablesProvider,

      deviceInfoProvider.overrideWith(_MockDeviceInfo.new),
      analyticsProvider.overrideWith(_MockAnalytics.new),
      timeProvider.overrideWith(_MockTime.new),
      loggerProvider.overrideWith(() => logger?.call() ?? mockLogger),

      if (scriptRunner?.call() case final scriptRunner?)
        scriptRunnerProvider.overrideWith(() => scriptRunner)
      else
        scriptRunnerProvider,

      if (args?.call() case final args?)
        argsProvider.overrideWith(() => args)
      else
        argsProvider,

      if (pubspecYaml?.call() case final pubspecYaml?)
        pubspecYamlProvider.overrideWith(() => pubspecYaml)
      else
        pubspecYamlProvider,

      if (pubspecLock?.call() case final pubspecLock?)
        pubspecLockProvider.overrideWith(() => pubspecLock)
      else
        pubspecLockProvider,

      if (scriptsYaml?.call() case final scriptsYaml?)
        scriptsYamlProvider.overrideWith(() => scriptsYaml)
      else
        scriptsYamlProvider,

      if (fileSystem?.call() case final FileSystem fs)
        fsProvider.overrideWith(() => fs)
      else
        fsProvider,

      if (bindings?.call() case final bindings?)
        bindingsProvider.overrideWith(() => bindings)
      else
        bindingsProvider,

      if (constrainPubspecVersions?.call() case final constrainPubspecVersions?)
        constrainPubspecVersionsProvider.overrideWith(
          () => constrainPubspecVersions,
        )
      else
        constrainPubspecVersionsProvider,

      if (findFile?.call() case final findFile?)
        findFileProvider.overrideWith(() => findFile)
      else
        findFileProvider,
    };

    await runScoped(values: testProviders, () async {
      switch (fn) {
        case final Future<void> Function() fn:
          await fn();
        case final void Function() fn:
          fn();
      }
    });
  });
}

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

class _MockTime extends Mock implements Time {}

class _MockDeviceInfo extends Mock implements DeviceInfo {}

class _MockAnalytics extends Mock implements Analytics {}
