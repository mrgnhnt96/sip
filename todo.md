# TODO

- [ ] Running `sip pub upgrade --major --dart-only` results in a never ending process if there are no matches
- [ ] Add a `(commands)` section to the `scripts.yaml` file to configure how `flutter` and `dart` commands are run
  - It would be nice to map `flutter` to `fvm flutter` and `dart` to `fvm dart`
- [ ] Ignore the build directory when running pub commands
- [ ] Look into interact
  - <https://pub.dev/packages/interact>
- [ ] Add config for colors
- [ ] Use Process.start to run commands
- [ ] Refactor how flutter tests are run, it is a lot faster using `flutter test`
- [ ] Add configuration within scripts.yaml to change the default cli command from `dart` and `flutter`
  - Like `fvm dart` or `fvm flutter` or something like that
- [ ] Support "search" for scripts, which would find any script that matches the search term and list them
