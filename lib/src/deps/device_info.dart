import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/device_info.dart';

final deviceInfoProvider = create(DeviceInfo.new);

final deviceInfo = read(deviceInfoProvider);
