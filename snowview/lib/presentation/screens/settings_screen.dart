import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/focus_sound_service.dart';
import '../../data/repositories/ai_config_repository.dart';
import '../../data/models/ai_config_hive.dart';
import '../../services/ai_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 专注设置
  int _pomodoroDuration = 25;
  int _shortBreakDuration = 5;
  int _longBreakDuration = 15;
  bool _enableNotification = true;
  bool _enableSound = false;
  
  final FocusSoundService _soundService = FocusSoundService();
  
  // AI配置设置
  final AIConfigRepository _aiConfigRepo = AIConfigRepository();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController(text: 'gpt-3.5-turbo');
  bool _obscureApiKey = true;
  double _temperature = 0.7;
  int _maxTokens = 2000;
  bool _enableTools = true;
  bool _isTestingConnection = false;
  bool _hasValidConfig = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAIConfig();
  }
  
  @override
  void dispose() {
    _soundService.dispose();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pomodoroDuration = prefs.getInt('focus_pomodoro_duration') ?? 25;
      _shortBreakDuration = prefs.getInt('focus_short_break_duration') ?? 5;
      _longBreakDuration = prefs.getInt('focus_long_break_duration') ?? 15;
      _enableNotification = prefs.getBool('focus_enable_notification') ?? true;
      _enableSound = prefs.getBool('focus_enable_sound') ?? false;
    });
  }

  /// 静默保存设置（不显示提示）
  Future<void> _saveSettingsQuietly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('focus_pomodoro_duration', _pomodoroDuration);
    await prefs.setInt('focus_short_break_duration', _shortBreakDuration);
    await prefs.setInt('focus_long_break_duration', _longBreakDuration);
    await prefs.setBool('focus_enable_notification', _enableNotification);
    await prefs.setBool('focus_enable_sound', _enableSound);
  }

  /// 保存设置并显示提示（用于开关切换）
  Future<void> _saveSettingsWithToast() async {
    await _saveSettingsQuietly();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设置已保存'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// 播放测试提示音
  Future<void> _playTestSound() async {
    try {
      await _soundService.playCompleteSound();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('这就是专注完成时的提示音'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败：${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ==================== AI配置相关方法 ====================

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
        title: const Text('⚙️ 设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildAIConfigSettings(context),
          const SizedBox(height: 24),
          _buildFocusSettings(context),
          const SizedBox(height: 24),
          _buildAboutSection(context),
        ],
      ),
    );
  }

  /// AI配置设置
  Widget _buildAIConfigSettings(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
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
                  color: Colors.green.withOpacity(0.1),
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
    );
  }

  /// 专注设置
  Widget _buildFocusSettings(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '专注设置',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 时长设置
            _buildDurationSetting(
              '番茄钟时长',
              _pomodoroDuration,
              (value) {
                _pomodoroDuration = value.round();
              },
              min: 10,
              max: 60,
            ),
            const SizedBox(height: 16),
            
            _buildDurationSetting(
              '短休息时长',
              _shortBreakDuration,
              (value) {
                _shortBreakDuration = value.round();
              },
              min: 3,
              max: 15,
            ),
            const SizedBox(height: 16),
            
            _buildDurationSetting(
              '长休息时长',
              _longBreakDuration,
              (value) {
                _longBreakDuration = value.round();
              },
              min: 10,
              max: 30,
            ),
            
            const Divider(height: 32),
            
            // 通知和音效设置
            SwitchListTile(
              title: const Text('启用通知提醒'),
              subtitle: const Text('专注完成时发送通知'),
              value: _enableNotification,
              onChanged: (value) {
                setState(() {
                  _enableNotification = value;
                });
                _saveSettingsWithToast();
              },
            ),
            
            SwitchListTile(
              title: const Text('启用音效'),
              subtitle: const Text('专注完成时播放提示音'),
              value: _enableSound,
              onChanged: (value) {
                setState(() {
                  _enableSound = value;
                });
                _saveSettingsWithToast();
              },
            ),
            
            // 试听提示音按钮
            if (_enableSound)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: _playTestSound,
                  icon: const Icon(Icons.volume_up),
                  label: const Text('试听提示音'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 时长设置项
  Widget _buildDurationSetting(
    String label,
    int value,
    ValueChanged<double> onChanged, {
    required int min,
    required int max,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '$value 分钟',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value 分钟',
          onChanged: (newValue) {
            // 滑动时只更新UI，不保存
            setState(() {
              onChanged(newValue);
            });
          },
          onChangeEnd: (newValue) {
            // 用户松手后才保存设置
            _saveSettingsQuietly();
          },
        ),
      ],
    );
  }

  /// 关于部分
  Widget _buildAboutSection(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
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
    );
  }
}
