import 'package:hooksman/hooksman.dart';

// todo: create pre-push hook

Hook main() {
  return PreCommitHook(
    tasks: [
      ReRegisterHooks(),
      // Analyze & format dart files
      ShellTask(
        name: 'Analyze dart files',
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
