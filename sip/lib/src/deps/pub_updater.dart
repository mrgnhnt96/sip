import 'package:pub_updater/pub_updater.dart';
import 'package:scoped_deps/scoped_deps.dart';

final pubUpdaterProvider = create<PubUpdater>(PubUpdater.new);

PubUpdater get pubUpdater => read(pubUpdaterProvider);
