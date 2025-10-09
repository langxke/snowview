import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/focus_sound_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  @override
  void dispose() {
    _soundService.dispose();
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
          _buildFocusSettings(context),
          const SizedBox(height: 24),
          _buildAboutSection(context),
        ],
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
