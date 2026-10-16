import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:novelphone/data/data_providers.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/features/ai/ai_providers.dart';

/// 不实际出网的替身客户端：只用于确认「谁拿到了这个客户端」。
class _StubClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream<List<int>>.empty(), 200);
}

/// 共享 HTTP 客户端（ENH-12）：全 App 复用一个客户端（连接复用），
/// 且 AI 用例编排确实依赖它——避免退回「每次生成新建客户端」。
void main() {
  test('同容器内共享同一客户端实例（ENH-12）', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      identical(
        container.read(httpClientProvider),
        container.read(httpClientProvider),
      ),
      isTrue,
    );
  });

  test('AI 用例编排依赖共享客户端（ENH-12）', () {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        httpClientProvider.overrideWith((ref) {
          reads++;
          return _StubClient();
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(aiServiceProvider);

    // 旧实现不注入客户端（各 adapter 自建），这里的读取次数会是 0。
    expect(reads, 1);
  });
}
