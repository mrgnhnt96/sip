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
}
