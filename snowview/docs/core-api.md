## Core 模块 API 说明

### core/constants/app_constants.dart
- 类：`AppConstants`
  - 静态常量：
    - `appName: String` — 应用名称。
    - `version: String` — 应用版本号。

### core/constants/database_constants.dart
- 类：`DatabaseConstants`
  - 静态常量：
    - `dbName: String` — 数据库文件名。
    - `dbVersion: int` — 数据库版本。
    - `tableTasks: String`、`tableSchedules: String`、`tableFocusSessions: String`、`tableFocusStats: String`、`tableUserPreferences: String` — 各业务表名。

### core/constants/ai_constants.dart
- 类：`AIConstants`
  - 静态常量：
    - `openAIApiBase: String` — OpenAI 基础端点。
    - `defaultModel: String` — 默认模型名称。

### core/theme/color_scheme.dart
- 类：`AppColorScheme`
  - 静态常量：
    - `seed: Color` — 主题种子色。
  - 静态属性：
    - `light: ColorScheme` — 明亮色板。
    - `dark: ColorScheme` — 深色色板。

### core/theme/app_theme.dart
- 类：`AppTheme`
  - 函数：`light() -> ThemeData`
    - 参数：无
    - 返回：`ThemeData`
    - 说明：返回基于 `AppColorScheme.light` 的明亮主题。
  - 函数：`dark() -> ThemeData`
    - 参数：无
    - 返回：`ThemeData`
    - 说明：返回基于 `AppColorScheme.dark` 的深色主题。

### core/errors/exceptions.dart
- 类：`ValidationException implements Exception`
  - 构造：`ValidationException(String message)`
  - 属性：`message: String`
  - 覆写：`toString() -> String` — 返回异常字符串。

### core/utils/validation_utils.dart
- 类：`ValidationUtils`
  - 函数：`isValidDuration(int minutes) -> bool`
    - 参数：`minutes: int`
    - 返回：`bool`
    - 说明：校验分钟数是否在 1..1440 之间。

### core/utils/date_utils.dart
- 类：`DateUtilsEx`
  - 函数：`formatDate(DateTime dt) -> String`
    - 参数：`dt: DateTime`
    - 返回：`String`（格式：YYYY-MM-DD）
    - 说明：格式化日期。

### core/utils/string_utils.dart
- 类：`StringUtilsEx`
  - 函数：`isBlank(String? s) -> bool`
    - 参数：`s: String?`
    - 返回：`bool`
    - 说明：判断字符串是否为空或全空白。


