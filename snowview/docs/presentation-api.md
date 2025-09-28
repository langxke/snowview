## Presentation 模块 API 说明

### main.dart
- 根组件：`MyApp`
  - 使用 `MultiProvider` 注入 `ThemeProvider`、`TaskProvider`、`ScheduleProvider`、`FocusProvider`。
  - 主题：`AppTheme.light()` / `AppTheme.dark()`；主页：`MainScreen`。

### presentation/providers/task_provider.dart
- 类：`TaskItem`
  - 字段：`title: String`、`completed: bool`
  - 函数：`toggle() -> TaskItem` — 返回取反完成状态的新对象。
- 类：`TaskProvider extends ChangeNotifier`
  - 只读属性：`items: List<TaskItem>` — 不可变视图。
  - 函数：
    - `addTodo(String title) -> void` — 头插添加待办项。
    - `toggle(int index) -> void` — 切换完成状态。
    - `removeAt(int index) -> void` — 删除指定项。

### presentation/providers/schedule_provider.dart
- 类：`ScheduleProvider extends ChangeNotifier` — 预留（当前无方法）。

### presentation/providers/focus_provider.dart
- 类：`FocusProvider extends ChangeNotifier` — 预留（当前无方法）。

### presentation/providers/theme_provider.dart
- 类：`ThemeProvider extends ChangeNotifier`
  - 属性：`mode: ThemeMode`
  - 函数：`setMode(ThemeMode m) -> void` — 设置主题并通知刷新。

### presentation/screens/main_screen.dart
- 组件：`MainScreen` — 三列布局的主界面。
  - 左/中：`_TodoColumn`
    - 文本框输入（回车或按钮）调用 `TaskProvider.addTodo` 添加。
    - 列表项 `CheckboxListTile` 勾选触发 `TaskProvider.toggle`，删除触发 `removeAt`。
  - 右：`_AIChatPanel`
    - 内部状态 `_messages: List<_Msg>`、输入框 `_input`。
    - `_send() -> void` 将用户输入加入对话，并生成占位回复。

### presentation/screens/home_screen.dart
- 组件：`HomeScreen` — 占位 `Scaffold`（后续扩展）。

### presentation/screens/task_management_screen.dart
- 组件：`TaskManagementScreen` — 占位 `Scaffold`。

### presentation/screens/schedule_screen.dart
- 组件：`ScheduleScreen` — 占位 `Scaffold`。

### presentation/screens/focus_screen.dart
- 组件：`FocusScreen` — 占位 `Scaffold`。

### presentation/screens/settings_screen.dart
- 组件：`SettingsScreen` — 占位 `Scaffold`。

### presentation/widgets/common/custom_app_bar.dart
- 组件：`CustomAppBar implements PreferredSizeWidget`
  - 构造：`CustomAppBar({required String title})`
  - 属性：`preferredSize: Size`
  - 功能：返回带标题的 `AppBar`。

### presentation/widgets/common/loading_widget.dart
- 组件：`LoadingWidget`
  - 功能：`CircularProgressIndicator` 居中加载。

### presentation/widgets/common/error_widget.dart
- 组件：`ErrorInfoWidget`
  - 构造：`ErrorInfoWidget({required String message, VoidCallback? onRetry})`
  - 功能：显示错误消息及可选重试按钮。


