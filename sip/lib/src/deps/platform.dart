import 'package:platform/platform.dart';
import 'package:scoped_deps/scoped_deps.dart';

final platformProvider = create<Platform>(LocalPlatform.new);

Platform get platform => read(platformProvider);
