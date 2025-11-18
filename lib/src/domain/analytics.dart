import 'package:lukehog_client/lukehog_client.dart';
import 'package:sip_cli/src/deps/device_info.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/utils/constants.dart';
import 'package:sip_cli/src/utils/is_ci.dart';
import 'package:sip_cli/src/version.dart';

class Analytics {
  Analytics() {
    _client = LukehogClient(_key);
  }

  static const _key = 'kfEW0UGBkaIAdhpU';

  late final LukehogClient _client;

  bool _hasInit = false;
  bool _disabled = false;

  void disable() {
    _disabled = true;
  }

  void enable() {
    _disabled = false;
  }

  Future<void> track(
    String event, {
    Map<String, dynamic> props = const {},
  }) async {
    if (_disabled) return;

    await _init();

    logger.detail(
      'Tracking event: $event with props: ${props.keys.join(', ')}',
    );

    try {
      await _client.capture(
        event,
        properties: {
          ...props,
          'is_sip_cli_script_set': Env.sipCliScript.isSet,
          'is_ci': isCi(),
          'package_version': packageVersion,
        },
        timestamp: DateTime.now(),
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> _init() async {
    if (_hasInit) return;

    _hasInit = true;

    try {
      final id = await deviceInfo.id();

      logger.detail('Setting user id: $id');

      _client.setUserId(id);
    } catch (e) {
      // ignore
    }
  }
}
