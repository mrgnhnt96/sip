import 'dart:ffi' as ffi;
import 'dart:ffi';
import 'dart:isolate' show Isolate;

import 'package:ffi/ffi.dart' show StringUtf8Pointer, Utf8;
import 'package:path/path.dart' as path;
import 'package:sip_script_runner/src/bindings/bindings.dart';

typedef RustRunScript = ffi.Int32 Function(Pointer<Utf8> script);
typedef DartRunScript = int Function(Pointer<Utf8> script);

/// The communicator between dart and rust
class BindingsImpl implements Bindings {
  const BindingsImpl();

  static const packageUri = 'package:sip_script_runner/sip_script_runner.dart';
  static const blobsPath = 'src/blobs/';

  /// Supported operating systems with architectures
  /// mapped to blob file extensions.
  static const supported = <ffi.Abi, String>{
    ffi.Abi.windowsX64: 'windows_x64.dll',
    ffi.Abi.linuxX64: 'linux_x64.so',
    ffi.Abi.macosX64: 'macos_x64.dylib',
    ffi.Abi.macosArm64: 'macos_arm64.dylib',
  };

  /// Gets the file name of blob files based on platform
  ///
  /// File name doesn't contain directory paths.
  String get blobFileName {
    final currentAbi = ffi.Abi.current();

    if (!supported.containsKey(currentAbi)) {
      throw Exception('Unsupported platform');
    }

    return supported[currentAbi]!;
  }

  Future<ffi.DynamicLibrary> dylib() async {
    final resolvedPackageUri =
        await Isolate.resolvePackageUri(Uri.parse(packageUri));

    if (resolvedPackageUri == null) {
      throw Exception('Could not resolve package uri');
    }

    final objectFilePath = resolvedPackageUri
        .resolve(path.join(blobsPath, blobFileName))
        .toFilePath();

    try {
      return ffi.DynamicLibrary.open(objectFilePath);
    } catch (e) {
      throw Exception('Could not open compiled rust library');
    }
  }

  @override
  Future<int> runScript(String script) async {
    final lib = await dylib();

    final runScript =
        lib.lookupFunction<RustRunScript, DartRunScript>('run_script');

    final scriptPointer = script.toNativeUtf8();

    // this is stopping and not finishing...
    final exitCode = runScript(scriptPointer);

    print(exitCode);
    return exitCode;
  }
}
