import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/security/screen_protection.dart';

/// ENH-26：截屏保护 MethodChannel 桥接。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(ScreenProtection.channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(ScreenProtection.channel, null);
  });

  test('把开关状态发送给原生层', () async {
    await ScreenProtection.setEnabled(true);
    await ScreenProtection.setEnabled(false);

    expect(calls, hasLength(2));
    expect(calls.first.method, 'setSecureScreen');
    expect(calls.first.arguments, <String, dynamic>{'enabled': true});
    expect(calls.last.arguments, <String, dynamic>{'enabled': false});
  });

  test('原生异常或无实现时静默，不影响设置保存', () async {
    messenger.setMockMethodCallHandler(ScreenProtection.channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    await ScreenProtection.setEnabled(true);

    messenger.setMockMethodCallHandler(ScreenProtection.channel, null);
    await ScreenProtection.setEnabled(false);
  });
}
