import 'dart:collection';

import 'package:args/args.dart';

class AnyArgResults implements ArgResults {
  AnyArgResults(this._argResults);

  final ArgResults _argResults;

  @override
  operator [](String name) {
    return _argResults[name];
  }

  @override
  List<String> get arguments => _argResults.arguments;

  @override
  ArgResults? get command => _argResults.command;

  @override
  String? get name => _argResults.name;

  @override
  Iterable<String> get options => _argResults.options;

  @override
  List<String> get rest =>
      UnmodifiableListView([..._argResults.rest, ..._moreRest]);

  List<String> _moreRest = [];

  void addRest(String rest) {
    _argResults.rest.add(rest);
  }

  void addAllRest(Iterable<String> rest) {
    _moreRest.addAll(rest);
  }

  @override
  bool wasParsed(String name) => _argResults.wasParsed(name);
}
