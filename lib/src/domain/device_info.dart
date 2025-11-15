import 'dart:async';
import 'dart:io';

import 'package:platform/platform.dart';
import 'package:sip_cli/src/deps/platform.dart';
import 'package:sip_cli/src/deps/process.dart';
import 'package:sip_cli/src/domain/process_details.dart';

class DeviceInfo {
  const DeviceInfo();

  Future<String> id() async {
    ProcessDetails details;
    switch (platform) {
      case Platform(isMacOS: true):
        details = await process(
          // run bash command
          'bash',
          [
            '-c',
            r'''
ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformUUID/{print $4}'\n
''',
          ],
          runInShell: true,
          mode: ProcessStartMode.normal,
        );
      case Platform(isLinux: true):
        details = await process(
          'cat',
          ['/etc/machine-id'],
          runInShell: true,
          mode: ProcessStartMode.normal,
        );
      case Platform(isWindows: true):
        details = await process(
          'powershell',
          [
            '-c',
            r'$reg = "HKLM:\SOFTWARE\Microsoft\Cryptography"; (Get-ItemProperty -Path $reg).MachineGuid',
          ],
          runInShell: true,
          mode: ProcessStartMode.normal,
        );

      default:
        throw UnimplementedError(
          'Device id is not supported on ${platform.operatingSystem}',
        );
    }

    final completer = Completer<String>();

    details.stdout.first.then((event) {
      if (completer.isCompleted) return;

      completer.complete(event.trim());
    }).ignore();

    Timer(const Duration(milliseconds: 800), () {
      if (completer.isCompleted) return;

      completer.completeError(Exception('Timeout'));
    });

    return completer.future;
  }
}
