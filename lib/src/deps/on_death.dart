import 'dart:io';

import 'package:scoped_deps/scoped_deps.dart';

final onDeathProvider = create(_OnDeath.new);

// ignore: library_private_types_in_public_api
_OnDeath get onDeath => read(onDeathProvider);

class _OnDeath {
  _OnDeath() : _callbacks = [];

  final List<void Function()> _callbacks;

  void register(void Function() callback) {
    _callbacks.add(callback);
  }

  void _die() {
    while (_callbacks.isNotEmpty) {
      try {
        final fn = _callbacks.removeLast();

        fn();
      } catch (_) {}
    }
  }

  void listen() {
    ProcessSignal.sigint.watch().listen((_) {
      _die();
      exit(1);
    }, cancelOnError: true);
  }
}
