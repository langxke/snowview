import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/task_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/schedule_provider.dart';
import 'presentation/providers/focus_provider.dart';
import 'presentation/providers/task_list_provider.dart';
import 'presentation/providers/navigation_provider.dart';
import 'presentation/providers/journal_provider.dart';
import 'presentation/screens/main_screen.dart';
import 'data/models/calendar_event_hive.dart';
import 'data/models/task_category_hive.dart';
import 'data/models/checklist_task_hive.dart';
import 'data/models/subtask_hive.dart';
import 'data/models/work_session_hive.dart';
import 'data/models/focus_session_hive.dart';
import 'data/models/focus_daily_stats_hive.dart';
import 'data/models/journal_entry_hive.dart';
import 'data/models/journal_category_hive.dart';
import 'data/models/ai_config_hive.dart';
import 'data/models/chat_message_hive.dart';
import 'data/models/chat_session_hive.dart';
import 'data/repositories/task_list_repository.dart';
import 'data/repositories/work_session_repository.dart';
import 'data/repositories/focus_session_repository.dart';
import 'data/repositories/journal_repository.dart';
import 'data/repositories/journal_category_repository.dart';
import 'data/repositories/ai_config_repository.dart';
import 'data/repositories/chat_history_repository.dart';
import 'data/repositories/chat_session_repository.dart';
import 'services/ai_service.dart';
import 'services/ai_tool_executor.dart';
import 'services/ai_context_builder.dart';
import 'presentation/providers/ai_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化窗口管理器
  await windowManager.ensureInitialized();
  
  // 设置窗口选项
  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // 隐藏原生标题栏，使用自定义标题栏
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setTitle('雪象SnowView');
  });
  
  // 初始化Hive
  await initHive();
  
  runApp(const MyApp());
}

Future<void> initHive() async {
  // 初始化Hive Flutter
  await Hive.initFlutter();
  
  // 注册日历适配器
  Hive.registerAdapter(CalendarEventHiveAdapter());
  
  // 注册清单任务适配器
  Hive.registerAdapter(TaskCategoryHiveAdapter());
  Hive.registerAdapter(SubTaskHiveAdapter());
  Hive.registerAdapter(ChecklistTaskHiveAdapter());
  
  // 注册工作会话适配器
  Hive.registerAdapter(WorkSessionHiveAdapter());
  
  // 注册专注会话适配器
  Hive.registerAdapter(FocusSessionHiveAdapter());
  Hive.registerAdapter(FocusDailyStatsHiveAdapter());
  
  // 注册记录条目适配器
  Hive.registerAdapter(JournalEntryHiveAdapter());
  Hive.registerAdapter(JournalCategoryHiveAdapter());
  
  // 注册AI配置适配器
  Hive.registerAdapter(AIConfigHiveAdapter());
  Hive.registerAdapter(ChatMessageHiveAdapter());
  Hive.registerAdapter(ChatSessionHiveAdapter());
  
  // 打开数据库
  await Hive.openBox<CalendarEventHive>('calendar_events');
  await Hive.openBox<WorkSessionHive>('work_sessions');
  
  // 初始化清单任务数据库
  await TaskListRepository.init();
  
  // 初始化工作会话数据库
  await WorkSessionRepository.init();
  
  // 初始化专注会话数据库
  await FocusSessionRepository.init();
  
  // 初始化记录数据库
  await JournalCategoryRepository.init();
  await JournalRepository.init();
  
  // 初始化AI配置数据库
  await AIConfigRepository.init();
  await ChatHistoryRepository.init();
  await ChatSessionRepository.init();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(
          create: (_) => FocusProvider(FocusSessionRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => TaskListProvider(TaskListRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => JournalProvider(JournalRepository()),
        ),
        // AI Provider - 需要依赖其他 providers
        ChangeNotifierProxyProvider4<TaskListProvider, ScheduleProvider,
            FocusProvider, JournalProvider, AIProvider>(
          create: (context) {
            // ✅ 创建工具执行器并注册所有工具
            final toolExecutor = AIToolExecutor(
              taskProvider: context.read<TaskListProvider>(),
              scheduleProvider: context.read<ScheduleProvider>(),
              focusProvider: context.read<FocusProvider>(),
              journalProvider: context.read<JournalProvider>(),
              taskRepository: TaskListRepository(),
            );
            toolExecutor.registerAllExecutors();
            
            return AIProvider(
              aiService: AIService(AIConfigRepository()),
              toolExecutor: toolExecutor,
              contextBuilder: AIContextBuilder(
                taskProvider: context.read<TaskListProvider>(),
                scheduleProvider: context.read<ScheduleProvider>(),
                focusProvider: context.read<FocusProvider>(),
                journalProvider: context.read<JournalProvider>(),
              ),
              historyRepo: ChatHistoryRepository(),
              sessionRepo: ChatSessionRepository(),
              configRepo: AIConfigRepository(),
            );
          },
          update: (context, taskProvider, scheduleProvider, focusProvider,
              journalProvider, previous) {
            // ⚠️ 重要：重用现有的 AIProvider，避免在操作进行时被 dispose
            // 只有在 previous 为 null 时（首次创建）才创建新实例
            if (previous != null) {
              return previous;
            }
            
            // 首次创建 AIProvider
            // ✅ 创建工具执行器并注册所有工具
            final toolExecutor = AIToolExecutor(
              taskProvider: taskProvider,
              scheduleProvider: scheduleProvider,
              focusProvider: focusProvider,
              journalProvider: journalProvider,
              taskRepository: TaskListRepository(),
            );
            toolExecutor.registerAllExecutors();
            
            return AIProvider(
              aiService: AIService(AIConfigRepository()),
              toolExecutor: toolExecutor,
              contextBuilder: AIContextBuilder(
                taskProvider: taskProvider,
                scheduleProvider: scheduleProvider,
                focusProvider: focusProvider,
                journalProvider: journalProvider,
              ),
              historyRepo: ChatHistoryRepository(),
              sessionRepo: ChatSessionRepository(),
              configRepo: AIConfigRepository(),
            );
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: '雪象SnowView',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          home: const MainScreen(),
        ),
      ),
    );
  }
}
