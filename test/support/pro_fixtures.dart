import 'package:assets/services/pro_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> setTestPro({bool enabled = true}) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        ProService.channel,
        (call) async => {
          'kind': enabled ? 'lifetime' : 'free',
          'legacyVerified': true,
          'products': <Object>[],
        },
      );
  await ProService.instance.refresh();
}
