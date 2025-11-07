import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/pubspec_lock.dart';

final pubspecLockProvider = create<PubspecLock>(PubspecLock.new);

PubspecLock get pubspecLock => read(pubspecLockProvider);
