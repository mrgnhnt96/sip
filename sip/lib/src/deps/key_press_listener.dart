import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/utils/key_press_listener.dart';

final keyPressListenerProvider = create<KeyPressListener>(KeyPressListener.new);

KeyPressListener get keyPressListener => read(keyPressListenerProvider);
