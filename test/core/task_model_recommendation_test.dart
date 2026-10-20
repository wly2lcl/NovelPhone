import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/task_model_recommendation.dart';
import 'package:novelphone/data/repositories/settings_repository.dart';
import 'package:novelphone/data/repositories/token_stats_repository.dart';

TokenStatRow row({
  required String task,
  required String model,
  int calls = 4,
  int outputChars = 400,
  int adoptedChars = 0,
  int adopted = 4,
  int verbatimAdopted = 0,
  int ignored = 0,
}) {
  return TokenStatRow(
    model: model,
    task: task,
    calls: calls,
    promptTokens: 0,
    completionTokens: 0,
    outputChars: outputChars,
    adoptedChars: adoptedChars,
    adopted: adopted,
    verbatimAdopted: verbatimAdopted,
    ignored: ignored,
  );
}

void main() {
  group('任务模型推荐（ENH-37）', () {
    test('采纳率更高的模型胜出，并带出当前映射与统计', () {
      final result = recommendTaskModels(
        rows: <TokenStatRow>[
          row(task: AiTask.continueWriting, model: 'm1', adoptedChars: 200),
          row(
            task: AiTask.continueWriting,
            model: 'm2',
            adoptedChars: 320,
            verbatimAdopted: 3,
          ),
        ],
        currentModels: <String, String?>{AiTask.continueWriting: 'm1'},
      );

      expect(result, hasLength(1));
      expect(result.single.task, AiTask.continueWriting);
      expect(result.single.model, 'm2');
      expect(result.single.currentModel, 'm1');
      expect(result.single.adoptionPercent, 80);
      expect(result.single.verbatimPercent, 75);
    });

    test('样本不足、提升不足或已是当前模型时不推荐', () {
      final insufficient = recommendTaskModels(
        rows: <TokenStatRow>[
          row(
            task: AiTask.continueWriting,
            model: 'm2',
            calls: 2,
            adoptedChars: 320,
          ),
        ],
        currentModels: <String, String?>{AiTask.continueWriting: 'm1'},
      );
      expect(insufficient, isEmpty);

      final smallGain = recommendTaskModels(
        rows: <TokenStatRow>[
          row(task: AiTask.rewrite, model: 'm1', adoptedChars: 200),
          row(task: AiTask.rewrite, model: 'm2', adoptedChars: 220),
        ],
        currentModels: <String, String?>{AiTask.rewrite: 'm1'},
      );
      expect(smallGain, isEmpty);

      final alreadyBest = recommendTaskModels(
        rows: <TokenStatRow>[
          row(task: AiTask.rewrite, model: 'm2', adoptedChars: 320),
        ],
        currentModels: <String, String?>{AiTask.rewrite: 'm2'},
      );
      expect(alreadyBest, isEmpty);
    });

    test('未映射任务可推荐，低采纳率与不可采纳任务被过滤', () {
      final unmapped = recommendTaskModels(
        rows: <TokenStatRow>[
          row(task: AiTask.summary, model: 'm2', adoptedChars: 240),
        ],
        currentModels: const <String, String?>{},
      );
      expect(unmapped.single.currentModel, isNull);
      expect(unmapped.single.adoptionPercent, 60);

      final lowRate = recommendTaskModels(
        rows: <TokenStatRow>[
          row(task: AiTask.summary, model: 'm2', adoptedChars: 40),
        ],
        currentModels: const <String, String?>{},
      );
      expect(lowRate, isEmpty);

      final notAdoptable = recommendTaskModels(
        rows: <TokenStatRow>[
          row(task: AiTask.check, model: 'm2', adoptedChars: 320),
        ],
        currentModels: const <String, String?>{},
      );
      expect(notAdoptable, isEmpty);
    });
  });
}
