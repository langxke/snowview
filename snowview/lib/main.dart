import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/task_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/schedule_provider.dart';
import 'presentation/providers/focus_provider.dart';
import 'presentation/providers/task_list_provider.dart';
import 'presentation/screens/main_screen.dart';
import 'data/models/calendar_event_hive.dart';
import 'data/models/task_category_hive.dart';
import 'data/models/checklist_task_hive.dart';
import 'data/models/subtask_hive.dart';
import 'data/repositories/task_list_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
  
  // 打开数据库
  await Hive.openBox<CalendarEventHive>('calendar_events');
  
  // 初始化清单任务数据库
  await TaskListRepository.init();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => FocusProvider()),
        ChangeNotifierProvider(
          create: (_) => TaskListProvider(TaskListRepository()),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: '雪象 SnowView',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          home: const MainScreen(),
        ),
      ),
    );
  }
}
