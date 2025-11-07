import 'package:mason_logger/mason_logger.dart';
import 'package:scoped_deps/scoped_deps.dart';

final loggerProvider = create<Logger>(Logger.new);

Logger get logger => read(loggerProvider);
