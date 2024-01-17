import 'package:sip_script_runner/src/bindings/bindings.dart';
import 'package:test/test.dart';

void main() async {
  final bindings = const Bindings();

  group('$Bindings', () {
    test('blobFileName', () {
      expect(bindings.blobFileName, isNotEmpty);
    });

    test('dylib', () async {
      final dylib = await bindings.dylib();
      expect(dylib, isNotNull);
    });
  });
}
