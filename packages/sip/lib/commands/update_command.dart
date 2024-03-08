import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
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

    final match = packageVersion == latestVersion;

    if (match) {
      return (false, latestVersion);
    }

    if (isLocalVersion(current: packageVersion, latest: latestVersion)) {
      return (false, latestVersion);
    }

    return (true, latestVersion);
  }

  /// Returns true if the local version is larger than the latest version
  ///
  /// 0.0.1 (local) > 0.0.0 (latest)
  bool isLocalVersion({
    required String current,
    required String latest,
  }) {
    final latestPlus =
        latest.contains('+') ? latest.replaceAll(RegExp(r'.*(?=\+)'), '') : '';
    final currentPlus = current.contains('+')
        ? current.replaceAll(RegExp(r'.*(?=\+)'), '')
        : '';

    final latestSplit = latest.replaceAll(latestPlus, '').split('.');
    final currentSplit = current.replaceAll(currentPlus, '').split('.');

    for (var i = 0; i < latestSplit.length; i++) {
      final latest = int.tryParse(latestSplit[i]) ?? 0;
      final current = int.tryParse(currentSplit[i]) ?? 0;

      if (current > latest) {
        return true;
      }
    }

    if (latestPlus != currentPlus) {
      final latest = int.tryParse(latestPlus) ?? 0;
      final current = int.tryParse(currentPlus) ?? 0;

      if (current > latest) {
        return true;
      }
    }

    return false;
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
      progress.complete('$packageName is up to date');

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
