import 'package:sip_script_runner/src/bindings/bindings_impl.dart';
import 'package:test/test.dart';

void main() {
  const bindings = BindingsImpl();

  group('$BindingsImpl', () {
    test('blobFileName', () {
      expect(bindings.blobFileName, isNotEmpty);
    });

    test('dylib', () async {
      final dylib = await bindings.dylib();
      expect(dylib, isNotNull);
    });
  });
}
