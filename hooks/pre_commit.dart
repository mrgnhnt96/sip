import 'package:hooksman/hooksman.dart';

Hook main() {
  return PreCommitHook(
    tasks: [
      ReRegisterHooks(),
      ShellTask(
        name: 'Format & analyze',
        include: [Glob('**.dart')],
        commands: (files) {
          return [
            'dart format ${files.join(' ')}',
            'dart analyze ${files.join(' ')} --fatal-infos --fatal-warnings',
          ];
        },
      ),
    ],
  );
}
