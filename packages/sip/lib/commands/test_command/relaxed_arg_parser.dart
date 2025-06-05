// ignore_for_file: avoid_positional_boolean_parameters

import 'dart:collection';

import 'package:args/args.dart';
// ignore: implementation_imports
import 'package:args/src/parser.dart';
import 'package:sip_cli/domain/args.dart';

class RelaxedArgParser implements ArgParser {
  RelaxedArgParser() : _parser = ArgParser();

  final ArgParser _parser;

  @override
  ArgParser addCommand(String name, [ArgParser? parser]) {
    return _parser.addCommand(name, parser);
  }

  @override
  void addFlag(
    String name, {
    String? abbr,
    String? help,
    bool? defaultsTo = false,
    bool negatable = true,
    void Function(bool p1)? callback,
    bool hide = false,
    bool hideNegatedUsage = false,
    List<String> aliases = const [],
  }) {
    try {
      _parser.addFlag(
        name,
        abbr: abbr,
        help: help,
        defaultsTo: defaultsTo,
        negatable: negatable,
        callback: callback,
        hide: hide,
        hideNegatedUsage: hideNegatedUsage,
        aliases: aliases,
      );
    } catch (_) {}
  }

  @override
  void addMultiOption(
    String name, {
    String? abbr,
    String? help,
    String? valueHelp,
    Iterable<String>? allowed,
    Map<String, String>? allowedHelp,
    Iterable<String>? defaultsTo,
    void Function(List<String> p1)? callback,
    bool splitCommas = true,
    bool hide = false,
    List<String> aliases = const [],
  }) {
    try {
      _parser.addMultiOption(
        name,
        abbr: abbr,
        help: help,
        valueHelp: valueHelp,
        allowed: allowed,
        allowedHelp: allowedHelp,
        defaultsTo: defaultsTo,
        callback: callback,
        splitCommas: splitCommas,
        hide: hide,
        aliases: aliases,
      );
    } catch (_) {}
  }

  @override
  void addOption(
    String name, {
    String? abbr,
    String? help,
    String? valueHelp,
    Iterable<String>? allowed,
    Map<String, String>? allowedHelp,
    String? defaultsTo,
    void Function(String? p1)? callback,
    bool mandatory = false,
    bool hide = false,
    List<String> aliases = const [],
  }) {
    try {
      _parser.addOption(
        name,
        abbr: abbr,
        help: help,
        valueHelp: valueHelp,
        allowed: allowed,
        allowedHelp: allowedHelp,
        defaultsTo: defaultsTo,
        callback: callback,
        mandatory: mandatory,
        hide: hide,
        aliases: aliases,
      );
    } catch (_) {}
  }

  @override
  void addSeparator(String text) {
    _parser.addSeparator(text);
  }

  @override
  bool get allowTrailingOptions => _parser.allowTrailingOptions;

  @override
  bool get allowsAnything => _parser.allowsAnything;

  @override
  Map<String, ArgParser> get commands => _parser.commands;

  @override
  void defaultFor(String option) {
    _parser.defaultFor(option);
  }

  @override
  Option? findByAbbreviation(String abbr) {
    return _parser.findByAbbreviation(abbr);
  }

  @override
  Option? findByNameOrAlias(String name) {
    return _parser.findByNameOrAlias(name);
  }

  @override
  @Deprecated('Use defaultFor instead')
  void getDefault(String option) {
    _parser.defaultFor(option);
  }

  @override
  Map<String, Option> get options => _parser.options;

  @override
  ArgResults parse(Iterable<String> args) {
    return _ArgsResults(args.toList(), this);
  }

  @override
  String get usage => _parser.usage;

  @override
  int? get usageLineLength => _parser.usageLineLength;
}

class _ArgsResults implements ArgResults {
  _ArgsResults(List<String> args, ArgParser parser) : _args = Args.parse(args) {
    ArgResults? results;

    final mutableArgs = switch (args.contains('--')) {
      true => args.takeWhile((e) => e != '--').toList(),
      false => args.toList(),
    };

    while (results == null || mutableArgs.isNotEmpty) {
      try {
        results = Parser(null, parser, Queue.of(mutableArgs)).parse();
      } catch (_) {
        mutableArgs.removeLast();
      }
    }

    _results = results;
  }

  final Args _args;
  late final ArgResults _results;

  @override
  dynamic operator [](String name) {
    return _args[name];
  }

  @override
  List<String> get arguments => _args.toArgs().toList();

  @override
  ArgResults? get command => _results.command;

  @override
  bool flag(String name) {
    return _args.get(name);
  }

  @override
  List<String> multiOption(String name) {
    return _args.get(name);
  }

  @override
  String? get name => _results.name;

  @override
  String? option(String name) {
    return _args.get(name);
  }

  @override
  Iterable<String> get options => _args.toArgs().toList();

  @override
  List<String> get rest => _args.rest;

  @override
  bool wasParsed(String name) {
    return _args.wasParsed(name);
  }
}
