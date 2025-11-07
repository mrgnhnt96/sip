import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/constrain_pubspec_versions.dart';

final constrainPubspecVersionsProvider = create<ConstrainPubspecVersions>(
  ConstrainPubspecVersions.new,
);

ConstrainPubspecVersions get constrainPubspecVersions =>
    read(constrainPubspecVersionsProvider);
