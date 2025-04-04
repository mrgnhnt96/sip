import 'dart:async';
import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:pub_semver/pub_semver.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:sip_cli/src/version.dart';
import 'package:sip_cli/utils/exit_code.dart';

class UpdateCommand extends Command<ExitCode> {
  UpdateCommand({
    required this.pubUpdater,
    required this.logger,
  });

  final PubUpdater pubUpdater;
  final Logger logger;

  @override
  String get name => 'update';

  @override
  String get description => 'Update Sip CLI to the latest version';

  Future<(bool, String)> needsUpdate() async {
    final latestVersion = await pubUpdater.getLatestVersion('sip_cli');

    try {
      final semPackageVersion = Version.parse(packageVersion);
      final semLatestVersion = Version.parse(latestVersion);

      logger
        ..detail('Current version: $packageVersion')
        ..detail('Latest version: $latestVersion');

      return (semPackageVersion != semLatestVersion, latestVersion);
    } catch (e) {
      logger
        ..detail('Failed to parse versions')
        ..detail('Error: $e');
      return (false, latestVersion);
    }
  }

  Future<bool> update() async {
    try {
      await pubUpdater.update(packageName: 'sip_cli');
    } catch (error) {
      final data = jsonDecode(error.toString());
      logger.detail('$data');

      return false;
    }

    return true;
  }

  @override
  Future<ExitCode> run() async {
    final packageName = lightGreen.wrap('sip_cli')!;

    final progress = logger.progress('Checking for updates');

    final (needsUpdate, latestVersion) = await this.needsUpdate();

    if (!needsUpdate) {
      final version = darkGray.wrap('(v$packageVersion)');
      progress.complete(
        '$packageName is up to date $version',
      );

      return ExitCode.success;
    }

    progress.update('Updating $packageName to ${yellow.wrap(latestVersion)}');

    final updatedSuccessfully = await update();

    if (!updatedSuccessfully) {
      progress.complete('Failed to update $packageName');

      return ExitCode.software;
    }

    progress.complete(
      'Successfully updated $packageName to ${yellow.wrap(latestVersion)}',
    );

    return ExitCode.success;
  }

  Future<void> checkForUpdate() async {
    // don't wait on this, stop after 1 second
    final exiter = Completer<({(bool, String)? result, bool exit})>();

    Timer? timer;

    timer = Timer(const Duration(seconds: 1), () {
      exiter.complete((result: null, exit: true));
    });

    this.needsUpdate().then((value) {
      exiter.complete((result: value, exit: false));
    }).ignore();

    final (:result, :exit) = await exiter.future;
    timer.cancel();

    if (exit) {
      logger.detail('Skipping version check, timeout reached');
      return;
    }

    final (needsUpdate, latestVersion) = result!;

    if (needsUpdate) {
      const changelog =
          'https://github.com/mrgnhnt96/sip/blob/main/packages/sip/CHANGELOG.md';

      final package = cyan.wrap('sip_cli');
      final currentVersion = red.wrap(packageVersion);
      final updateToVersion = green.wrap(latestVersion);
      final updateCommand = yellow.wrap('sip update');
      final changelogLink = darkGray.wrap('Changelog: $changelog') ?? '';

      final lines = [
        '┌${'─' * 83}┐',
        '│ ${'New update for $package is available!'.padRightAnsi(81)} │',
        // ignore: lines_longer_than_80_chars
        '│ ${'You are using $currentVersion, the latest is $updateToVersion.'.padRightAnsi(81)} │',
        // ignore: lines_longer_than_80_chars
        '│ ${'Run `$updateCommand` to update to the latest version.'.padRightAnsi(81)} │',
        '│ ${changelogLink.padRightAnsi(81)} │',
        '└${'─' * 83}┘',
        '',
      ];

      final message = lines.join('\n');

      logger.write(message);
    }
  }
}

extension _StringX on String {
  String padRightAnsi(int width) {
    final visibleLength = stripAnsi().length;
    final padding = width - visibleLength;
    return this + ' ' * (padding > 0 ? padding : 0);
  }

  String stripAnsi() {
    final ansiRegExp = RegExp(r'\x1B\[[0-9;]*m');
    return replaceAll(ansiRegExp, '');
  }
}
