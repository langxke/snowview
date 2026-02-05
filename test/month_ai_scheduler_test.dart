import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:snowview/data/models/ai_config_hive.dart';
import 'package:snowview/data/models/openai/openai_models.dart';
import 'package:snowview/data/repositories/ai_config_repository.dart';
import 'package:snowview/presentation/screens/schedule/month_ai_scheduler.dart';
import 'package:snowview/services/ai_service.dart';

class _TaskStub {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final DateTime? remindAt;
  final DateTime? createdAt;

  _TaskStub({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.remindAt,
    this.createdAt,
  });
}

class _FakeAIService implements AIService {
  int callCount = 0;
  final List<String> outputs;

  _FakeAIService(this.outputs);

  @override
  Future<OpenAIChatResponse> chat({
    required List<OpenAIChatMessage> messages,
    String? systemPrompt,
    List<OpenAITool>? tools,
    int? maxRetries = 3,
  }) async {
    final idx = callCount < outputs.length ? callCount : outputs.length - 1;
    callCount++;
    final content = outputs[idx];
    return OpenAIChatResponse(
      id: 'fake',
      object: 'chat.completion',
      created: 0,
      model: 'fake',
      choices: [
        OpenAIChatChoice(
          index: 0,
          message: OpenAIChatMessage.text(role: OpenAIMessageRole.assistant, content: content),
        ),
      ],
    );
  }

  @override
  Stream<OpenAIStreamResponse> chatStream({required List<OpenAIChatMessage> messages, String? systemPrompt, List<OpenAITool>? tools}) {
    throw UnimplementedError();
  }

  @override
  AIConfigHive? get config => null;

  @override
  bool get hasValidConfig => true;

  @override
  Future<(bool, String?)> testConnection() async => (true, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MonthAiScheduler parses date and dates and de-duplicates', () async {
    SharedPreferences.setMockInitialValues({});

    final ai = _FakeAIService([
      '''
      {
        "reasoning": "test",
        "schedule": {
          "assignments": [
            { "taskId": "t1", "date": "2026-02-02" },
            { "taskId": "t1", "dates": ["2026-02-02", "2026-02-03"] }
          ]
        }
      }
      '''
    ]);

    final res = await MonthAiScheduler.callMonthSchedulingAIForTest(
      aiService: ai,
      today: DateTime(2026, 2, 1),
      monthEnd: DateTime(2026, 2, 28),
      candidates: [
        _TaskStub(id: 't1', title: 'task', description: 'note'),
      ],
    );

    expect(res.reasoning, contains('test'));
    expect(res.byTaskId['t1'], equals(['2026-02-02', '2026-02-03']));
    expect(ai.callCount, 1);
  });

  test('MonthAiScheduler retries on JSON parse errors using configured max retries', () async {
    SharedPreferences.setMockInitialValues({});

    final dir = await Directory.systemTemp.createTemp('snowview_ai_config_test_');
    Hive.init(dir.path);
    Hive.registerAdapter(AIConfigHiveAdapter());
    await Hive.openBox<AIConfigHive>('ai_config');
    final repo = AIConfigRepository();
    await repo.saveConfig(
      AIConfigHive(
        provider: 'openai',
        apiKey: 'k',
        baseUrl: null,
        model: 'm',
        temperature: 0.7,
        maxTokens: 1000,
        maxJsonParseRetries: 2,
        enableTools: true,
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
      ),
    );

    final ai = _FakeAIService([
      'not a json',
      '''
      {
        "reasoning": "ok",
        "schedule": { "assignments": [ { "taskId": "t1", "date": "2026-02-02" } ] }
      }
      '''
    ]);

    final res = await MonthAiScheduler.callMonthSchedulingAIForTest(
      aiService: ai,
      today: DateTime(2026, 2, 1),
      monthEnd: DateTime(2026, 2, 28),
      candidates: [
        _TaskStub(id: 't1', title: 'task', description: 'note'),
      ],
    );

    expect(res.byTaskId['t1'], equals(['2026-02-02']));
    expect(ai.callCount, 2);

    await Hive.close();
    await dir.delete(recursive: true);
  });
}
