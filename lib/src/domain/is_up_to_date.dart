import 'package:sip_cli/src/deps/pub_updater.dart';
import 'package:sip_cli/src/package.dart' as pkg;
import 'package:sip_cli/src/version.dart' as pkg;

class IsUpToDate {
  const IsUpToDate();

  Future<bool> check() async {
    try {
      final version = await pubUpdater.getLatestVersion(pkg.packageName);

      return version == pkg.packageVersion;
    } catch (_) {
      return true;
    }
  }

  Future<String> latestVersion() async {
    try {
      return await pubUpdater.getLatestVersion(pkg.packageName);
    } catch (_) {
      return pkg.packageVersion;
    }
  }

  Future<bool> update() async {
    try {
      await pubUpdater.update(packageName: pkg.packageName);

      return true;
    } catch (_) {
      return false;
    }
  }
}
