import 'package:args/args.dart';
import 'package:sip_cli/domain/any_arg_results.dart';

typedef _Callback<T> = void Function(T);

class AnyArgParser implements ArgParser {
  AnyArgParser({
    ArgParser? argParser,
  }) : _argParser = argParser ?? ArgParser();

  final ArgParser _argParser;

  @override
  ArgParser addCommand(String name, [ArgParser? parser]) =>
      _argParser.addCommand(name, parser);

  @override
  void addFlag(
    String name, {
    String? abbr,
    String? help,
    bool? defaultsTo = false,
    bool negatable = true,
    // ignore: avoid_positional_boolean_parameters
    void Function(bool p1)? callback,
    bool hide = false,
    List<String> aliases = const [],
  }) =>
      _argParser.addFlag(
        name,
        abbr: abbr,
        help: help,
        defaultsTo: defaultsTo,
        negatable: negatable,
        callback: callback,
        hide: hide,
        aliases: aliases,
      );

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
  }) =>
      _argParser.addMultiOption(
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
  }) =>
      _argParser.addOption(
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

  @override
  void addSeparator(String text) => _argParser.addSeparator(text);

  @override
  bool get allowTrailingOptions => _argParser.allowTrailingOptions;

  @override
  bool get allowsAnything => true;

  @override
  Map<String, ArgParser> get commands => _argParser.commands;

  @override
  dynamic defaultFor(String option) => _argParser.defaultFor(option);

  @override
  Option? findByAbbreviation(String abbr) =>
      _argParser.findByAbbreviation(abbr);

  @override
  Option? findByNameOrAlias(String name) => _argParser.findByNameOrAlias(name);

  @override
  @Deprecated('Use defaultFor instead.')
  dynamic getDefault(String option) => _argParser.getDefault(option);

  @override
  Map<String, Option> get options => _argParser.options;

  @override
  ArgResults parse(
    Iterable<String> args, {
    List<String> badArgs = const [],
    List<String>? preFlags,
  }) {
    var mutableArgs = [...args];
    final removedArgs = <String>[...badArgs];

    ArgResults backUpResult;

    final preFlags0 = <String>[];

    if (preFlags != null) {
      preFlags0.addAll(preFlags);
    } else {
      final preFlags = mutableArgs.takeWhile((value) => !value.startsWith('-'));
      preFlags0.addAll(preFlags);
      mutableArgs = mutableArgs.skip(preFlags.length).toList();
    }

    try {
      backUpResult = _argParser.parse([...preFlags0, ...mutableArgs]);
    } on ArgParserException catch (e) {
      final badFlag = RegExp('"([a-z-_=]+)"').firstMatch(e.message)?.group(1);

      if (badFlag == null) {
        rethrow;
      }

      var grabValues = true;

      if (mutableArgs.remove(badFlag)) {
        removedArgs.add(badFlag);
      } else if (mutableArgs.remove('-$badFlag')) {
        removedArgs.add('-$badFlag');
      } else if (mutableArgs.remove('--$badFlag')) {
        removedArgs.add('--$badFlag');
      } else {
        var foundFlag = false;
        for (final key in mutableArgs.reversed) {
          if (key.startsWith('--$badFlag=')) {
            mutableArgs.remove(key);
            removedArgs.add(key);
            foundFlag = true;
            break;
          } else if (RegExp(r'^-\w').hasMatch(badFlag) &&
              RegExp(r'(?:-)\w*' '${badFlag.replaceAll('-', '')}')
                  .hasMatch(key)) {
            final badFlagOnly = badFlag.replaceAll('-', '');
            grabValues = key.endsWith(badFlagOnly);

            final updatedKey = key.replaceAll(badFlagOnly, '');

            final replaceIndex = mutableArgs.indexOf(key);
            mutableArgs
                .replaceRange(replaceIndex, replaceIndex + 1, [updatedKey]);

            removedArgs.add(badFlag);
            foundFlag = true;
            break;
          }
        }

        if (!foundFlag) {
          throw Exception('Unknown flag format: $badFlag');
        }
      }

      if (grabValues) {
        final removed =
            mutableArgs.takeWhile((value) => !value.startsWith('-'));

        removedArgs.addAll(removed.expand((element) => element.split('=')));

        mutableArgs = mutableArgs.skip(removed.length).toList();
      }

      return parse(
        mutableArgs,
        badArgs: removedArgs,
        preFlags: preFlags0,
      );
    }

    final anyArgResults = AnyArgResults(backUpResult)..addAllRest(removedArgs);

    return anyArgResults;
  }

  @override
  String get usage => _argParser.usage;

  @override
  int? get usageLineLength => _argParser.usageLineLength;

  void inject(Option option) {
    void voidCallback(_) {}

    if (option.isFlag) {
      addFlag(
        option.name,
        abbr: option.abbr,
        aliases: option.aliases,
        help: option.help,
        callback: option.callback as _Callback? ?? voidCallback,
        defaultsTo: option.defaultsTo as bool? ?? false,
        hide: option.hide,
        negatable: option.negatable ?? false,
      );
    } else if (option.isMultiple) {
      addMultiOption(
        option.name,
        abbr: option.abbr,
        aliases: option.aliases,
        help: option.help,
        defaultsTo: option.defaultsTo as List<String>? ?? <String>[],
        hide: option.hide,
        allowed: option.allowed,
        allowedHelp: option.allowedHelp,
        callback: option.callback as _Callback? ?? voidCallback,
        splitCommas: option.splitCommas,
        valueHelp: option.valueHelp,
      );
    } else if (option.isSingle) {
      addOption(
        option.name,
        abbr: option.abbr,
        aliases: option.aliases,
        help: option.help,
        defaultsTo: option.defaultsTo as String? ?? '',
        hide: option.hide,
        allowed: option.allowed,
        allowedHelp: option.allowedHelp,
        callback: option.callback as _Callback? ?? voidCallback,
        valueHelp: option.valueHelp,
        mandatory: option.mandatory,
      );
    } else {
      throw Exception('Unknown option type: $option');
    }
  }
}
