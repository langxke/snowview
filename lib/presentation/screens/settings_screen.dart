import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/ai_config_repository.dart';
import '../../data/models/ai_config_hive.dart';
import '../../services/ai_service.dart';
import '../../services/app_data_reset_service.dart';
import '../providers/daily_plan_provider.dart';
import '../providers/focus_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/task_list_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 可分配时间段设置
  static const String _prefsKeyWeekdayRanges = 'availability_weekday_ranges_v1';
  static const String _prefsKeyWeekendRanges = 'availability_weekend_ranges_v1';
  static const String _prefsKeyWorkdays = 'availability_workdays_v1';

  List<_TimeRange> _weekdayRanges = <_TimeRange>[const _TimeRange(startMinutes: 9 * 60, endMinutes: 12 * 60), const _TimeRange(startMinutes: 13 * 60, endMinutes: 18 * 60)];
  List<_TimeRange> _weekendRanges = <_TimeRange>[const _TimeRange(startMinutes: 10 * 60, endMinutes: 12 * 60), const _TimeRange(startMinutes: 14 * 60, endMinutes: 18 * 60)];
  Set<int> _workdays = <int>{1, 2, 3, 4, 5};

  // AI配置设置
  final AIConfigRepository _aiConfigRepo = AIConfigRepository();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController(text: 'gpt-3.5-turbo');
  bool _obscureApiKey = true;
  double _temperature = 0.7;
  int _maxTokens = 2000;
  int _maxJsonParseRetries = 3;
  bool _enableTools = true;
  bool _isTestingConnection = false;
  bool _hasValidConfig = false;
  bool _isClearingAllData = false;

  @override
  void initState() {
    super.initState();
    _loadAIConfig();
    _loadAvailabilitySettings();
  }
  
  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  // ==================== AI配置相关方法 ====================

  Future<void> _loadAvailabilitySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final weekdayRaw = prefs.getString(_prefsKeyWeekdayRanges);
      final weekendRaw = prefs.getString(_prefsKeyWeekendRanges);
      final workdaysRaw = prefs.getStringList(_prefsKeyWorkdays);

      final weekdayParsed = _parseRanges(weekdayRaw);
      final weekendParsed = _parseRanges(weekendRaw);
      final workdaysParsed = _parseWorkdays(workdaysRaw);

      if (!mounted) return;
      setState(() {
        if (weekdayParsed != null && weekdayParsed.isNotEmpty) {
          _weekdayRanges = weekdayParsed;
        }
        if (weekendParsed != null && weekendParsed.isNotEmpty) {
          _weekendRanges = weekendParsed;
        }
        if (workdaysParsed != null && workdaysParsed.isNotEmpty) {
          _workdays = workdaysParsed;
        }
      });
    } catch (_) {
      // ignore
    }
  }

  Set<int>? _parseWorkdays(List<String>? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = <int>{};
    for (final s in raw) {
      final v = int.tryParse(s);
      if (v != null && v >= 1 && v <= 7) {
        parsed.add(v);
      }
    }
    return parsed;
  }

  List<_TimeRange>? _parseRanges(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    final ranges = <_TimeRange>[];
    for (final item in decoded) {
      if (item is Map) {
        final start = item['startMinutes'];
        final end = item['endMinutes'];
        if (start is int && end is int) {
          final range = _TimeRange(startMinutes: start, endMinutes: end);
          if (range.isValid) {
            ranges.add(range);
          }
        }
      }
    }
    return ranges;
  }

  Future<void> _saveAvailabilitySettingsQuietly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKeyWeekdayRanges,
        jsonEncode(_weekdayRanges.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _prefsKeyWeekendRanges,
        jsonEncode(_weekendRanges.map((e) => e.toJson()).toList()),
      );
      await prefs.setStringList(
        _prefsKeyWorkdays,
        _workdays.map((e) => e.toString()).toList(),
      );
    } catch (e) {
      debugPrint('[SettingsScreen] save availability failed: $e');
    }
  }

  Future<void> _toggleWorkday(int weekday) async {
    setState(() {
      if (_workdays.contains(weekday)) {
        _workdays = {..._workdays}..remove(weekday);
      } else {
        _workdays = {..._workdays}..add(weekday);
      }
    });
    await _saveAvailabilitySettingsQuietly();
  }

  Future<void> _pickAndSetTime({
    required bool isWeekday,
    required int index,
    required bool isStart,
  }) async {
    final ranges = isWeekday ? _weekdayRanges : _weekendRanges;
    if (index < 0 || index >= ranges.length) return;

    final current = ranges[index];
    final initial = isStart ? current.startTimeOfDay : current.endTimeOfDay;

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;

    final pickedMinutes = picked.hour * 60 + picked.minute;
    final updated = isStart
        ? current.copyWith(startMinutes: pickedMinutes)
        : current.copyWith(endMinutes: pickedMinutes);

    if (!updated.isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('时间段无效：结束时间必须晚于开始时间'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      final updatedRanges = [...ranges];
      updatedRanges[index] = updated;
      if (isWeekday) {
        _weekdayRanges = updatedRanges;
      } else {
        _weekendRanges = updatedRanges;
      }
    });
    await _saveAvailabilitySettingsQuietly();
  }

  Future<void> _addRange({required bool isWeekday}) async {
    setState(() {
      final target = isWeekday ? _weekdayRanges : _weekendRanges;
      final updated = [...target, const _TimeRange(startMinutes: 9 * 60, endMinutes: 10 * 60)];
      if (isWeekday) {
        _weekdayRanges = updated;
      } else {
        _weekendRanges = updated;
      }
    });
    await _saveAvailabilitySettingsQuietly();
  }

  Future<void> _removeRange({required bool isWeekday, required int index}) async {
    setState(() {
      final target = isWeekday ? _weekdayRanges : _weekendRanges;
      if (index < 0 || index >= target.length) return;
      final updated = [...target]..removeAt(index);
      if (isWeekday) {
        _weekdayRanges = updated;
      } else {
        _weekendRanges = updated;
      }
    });
    await _saveAvailabilitySettingsQuietly();
  }

  /// 加载AI配置
  Future<void> _loadAIConfig() async {
    final config = _aiConfigRepo.getConfig();
    if (config != null) {
      setState(() {
        _apiKeyController.text = config.apiKey;
        _baseUrlController.text = config.baseUrl ?? '';
        _modelController.text = config.model;
        _temperature = config.temperature;
        _maxTokens = config.maxTokens;
        _maxJsonParseRetries = config.maxJsonParseRetries;
        _enableTools = config.enableTools;
        _hasValidConfig = config.isValid;
      });
    }
  }

  /// 保存AI配置（不测试连接）
  Future<void> _saveAIConfig() async {
    // 基本验证
    if (_apiKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 请先输入API Key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_modelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 请先输入模型名称'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final config = AIConfigHive(
        provider: 'openai',
        apiKey: _apiKeyController.text.trim(),
        baseUrl: _baseUrlController.text.trim().isEmpty 
            ? null 
            : _baseUrlController.text.trim(),
        model: _modelController.text.trim(),
        temperature: _temperature,
        maxTokens: _maxTokens,
        maxJsonParseRetries: _maxJsonParseRetries,
        enableTools: _enableTools,
        createdAt: _aiConfigRepo.getConfig()?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 验证配置格式
      if (!config.isValid) {
        if (mounted) {
          String errorMsg = '配置格式错误';
          if (config.baseUrl != null && config.baseUrl!.isNotEmpty) {
            final url = config.baseUrl!.trim();
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              errorMsg = 'BaseURL 格式错误：必须以 http:// 或 https:// 开头';
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $errorMsg'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      await _aiConfigRepo.saveConfig(config);
      
      // 注意：保存成功不代表配置有效（需要测试连接才能确认）
      setState(() {
        _hasValidConfig = false; // 保存后需要测试连接才能确认有效性
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 配置已保存，请点击"测试连接"验证配置'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败：${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 测试AI连接
  Future<void> _testAIConnection() async {
    if (_apiKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 请先输入API Key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_modelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 请先输入模型名称'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isTestingConnection = true;
    });

    // 双层保护：确保任何异常都被捕获
    try {
      // 先创建临时配置进行验证（不保存到数据库）
      final tempConfig = AIConfigHive(
        provider: 'openai',
        apiKey: _apiKeyController.text.trim(),
        baseUrl: _baseUrlController.text.trim().isEmpty 
            ? null 
            : _baseUrlController.text.trim().replaceAll(RegExp(r'/+$'), ''), // 移除末尾的斜杠
        model: _modelController.text.trim(),
        temperature: _temperature,
        maxTokens: _maxTokens,
        maxJsonParseRetries: _maxJsonParseRetries,
        enableTools: _enableTools,
        createdAt: _aiConfigRepo.getConfig()?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 验证配置格式
      if (!tempConfig.isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ 配置格式错误，请检查输入'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 临时保存配置以便测试
      await _aiConfigRepo.saveConfig(tempConfig);

      // 使用AIService进行实际测试（带超时保护）
      final aiService = AIService(_aiConfigRepo);
      
      final (isConnected, errorMessage) = await aiService.testConnection()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => (false, '连接超时（30秒）\n请检查网络或BaseURL'),
          );

      if (mounted) {
        if (isConnected) {
          // 测试成功，更新本地状态
          setState(() {
            _hasValidConfig = true;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ 连接测试成功！配置已保存'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // 测试失败，不保存配置（或者删除刚才的临时保存）
          setState(() {
            _hasValidConfig = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${errorMessage ?? "连接失败"}'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasValidConfig = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 测试失败：${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAvailabilitySettings(context),
          const SizedBox(height: 24),
          _buildAIConfigSettings(context),
          const SizedBox(height: 24),
          _buildDataResetSection(context),
          const SizedBox(height: 24),
          _buildAboutSection(context),
        ],
      ),
    );
  }

  Future<void> _confirmAndClearAllLocalData() async {
    if (_isClearingAllData) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清空所有本地数据？'),
          content: const Text('此操作会清空任务、日程、今日计划、专注统计、聊天记录、AI 配置以及所有本地偏好设置，且不可恢复。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() {
      _isClearingAllData = true;
    });

    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      await AppDataResetService.clearAllLocalData();

      if (!mounted) return;
      await context.read<FocusProvider>().resetAfterDataCleared();
      context.read<DailyPlanProvider>().resetCache();
      await context.read<TaskListProvider>().refresh();
      context.read<ScheduleProvider>().refresh();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清空所有本地数据，建议重启应用')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清空失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isClearingAllData = false;
        });
      }
    }
  }

  Widget _buildDataResetSection(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      '数据清理',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '用于清理遗留数据。清空后不可恢复。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isClearingAllData ? null : _confirmAndClearAllLocalData,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('清空所有本地数据'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilitySettings(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '可分配时间段',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '设置 AI 在安排任务时可使用的时间范围（支持多段）',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  '工作日定义',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildWeekdayChip(context, label: '周一', weekday: 1),
                    _buildWeekdayChip(context, label: '周二', weekday: 2),
                    _buildWeekdayChip(context, label: '周三', weekday: 3),
                    _buildWeekdayChip(context, label: '周四', weekday: 4),
                    _buildWeekdayChip(context, label: '周五', weekday: 5),
                    _buildWeekdayChip(context, label: '周六', weekday: 6),
                    _buildWeekdayChip(context, label: '周日', weekday: 7),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '未选中的日期将视为周末/非工作日，并使用「周末」可分配时间段。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 32),

                _buildRangeGroup(
                  context,
                  title: '工作日',
                  ranges: _weekdayRanges,
                  isWeekday: true,
                ),
                const SizedBox(height: 20),
                _buildRangeGroup(
                  context,
                  title: '周末',
                  ranges: _weekendRanges,
                  isWeekday: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdayChip(
    BuildContext context, {
    required String label,
    required int weekday,
  }) {
    final selected = _workdays.contains(weekday);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _toggleWorkday(weekday),
    );
  }

  Widget _buildRangeGroup(
    BuildContext context, {
    required String title,
    required List<_TimeRange> ranges,
    required bool isWeekday,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _addRange(isWeekday: isWeekday),
              icon: const Icon(Icons.add),
              label: const Text('新增时间段'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (ranges.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '暂无时间段',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...List.generate(ranges.length, (index) {
            final range = ranges[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () => _pickAndSetTime(
                            isWeekday: isWeekday,
                            index: index,
                            isStart: true,
                          ),
                          child: Text('开始 ${range.formatStart()}'),
                        ),
                        OutlinedButton(
                          onPressed: () => _pickAndSetTime(
                            isWeekday: isWeekday,
                            index: index,
                            isStart: false,
                          ),
                          child: Text('结束 ${range.formatEnd()}'),
                        ),
                        Text(
                          '共 ${range.durationMinutes} 分钟',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '删除',
                    onPressed: () => _removeRange(isWeekday: isWeekday, index: index),
                    icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAIConfigSettings(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // 标题
            Row(
              children: [
                Icon(Icons.smart_toy, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'AI助手配置',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '配置AI助手以使用智能对话功能',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // API Key输入框
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'API Key *',
                hintText: '输入您的OpenAI API Key',
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureApiKey = !_obscureApiKey;
                    });
                  },
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Base URL输入框
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL（可选）',
                hintText: 'https://api.openai.com/v1/chat/completions',
                helperText: '填写完整的API端点地址，不会自动追加路径',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 模型选择
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: '模型',
                hintText: '例如：gpt-3.5-turbo, gpt-4, gpt-4o, deepseek-chat 等',
                prefixIcon: Icon(Icons.psychology),
                border: OutlineInputBorder(),
                helperText: '输入您的模型名称，支持所有兼容OpenAI API的模型',
              ),
            ),

            const Divider(height: 32),

            // 高级设置标题
            Text(
              '高级设置',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Temperature滑块
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Temperature（温度）'),
                    Text(
                      _temperature.toStringAsFixed(1),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '控制回复的随机性。值越高越有创造性',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _temperature,
                  min: 0.0,
                  max: 2.0,
                  divisions: 20,
                  label: _temperature.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() {
                      _temperature = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Max Tokens滑块
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Max Tokens（最大长度）'),
                    Text(
                      _maxTokens.toString(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'AI回复的最大长度限制',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _maxTokens.toDouble(),
                  min: 500,
                  max: 4000,
                  divisions: 14,
                  label: _maxTokens.toString(),
                  onChanged: (value) {
                    setState(() {
                      _maxTokens = value.round();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // JSON解析最大重试次数
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('最大重试次数（解析错误）'),
                    Text(
                      _maxJsonParseRetries.toString(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '当AI输出无法解析为JSON或不符合要求结构时，自动重试的最大次数',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _maxJsonParseRetries.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _maxJsonParseRetries.toString(),
                  onChanged: (value) {
                    setState(() {
                      _maxJsonParseRetries = value.round();
                    });
                  },
                ),
              ],
            ),

            // 启用工具调用开关
            SwitchListTile(
              title: const Text('启用工具调用'),
              subtitle: const Text('允许AI直接操作任务、日程等功能'),
              value: _enableTools,
              onChanged: (value) {
                setState(() {
                  _enableTools = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // 配置状态指示
            if (_hasValidConfig)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '配置有效',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTestingConnection ? null : _testAIConnection,
                    icon: _isTestingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering),
                    label: Text(_isTestingConnection ? '测试中...' : '测试连接'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveAIConfig,
                    icon: const Icon(Icons.save),
                    label: const Text('保存配置'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 关于部分
  Widget _buildAboutSection(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '关于',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '雪象 SnowView',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '版本：1.0.0',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '基于AI辅助的智能日程规划和专注工具',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeRange {
  final int startMinutes;
  final int endMinutes;

  const _TimeRange({
    required this.startMinutes,
    required this.endMinutes,
  });

  bool get isValid => startMinutes >= 0 && endMinutes <= 24 * 60 && endMinutes > startMinutes;

  int get durationMinutes => endMinutes - startMinutes;

  TimeOfDay get startTimeOfDay => TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60);

  TimeOfDay get endTimeOfDay => TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);

  String formatStart() => _formatMinutes(startMinutes);

  String formatEnd() => _formatMinutes(endMinutes);

  _TimeRange copyWith({int? startMinutes, int? endMinutes}) {
    return _TimeRange(
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
    };
  }

  static String _formatMinutes(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
