import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'todo_pane.dart';
import 'ai_chat_panel.dart';

enum _MainSection { todo, calendar, settings }

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 左侧侧边栏当前选中项
  _MainSection _section = _MainSection.todo;

  // 右侧 AI 面板是否显示
  bool _showAI = true;

  // AI 面板宽度比例
  double _aiRatio = 1 / 3;
  static const double _aiMinRatio = 0.2;
  static const double _aiMaxRatio = 0.6;
  static const double _handleWidth = 8.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 56,
            child: Stack(
              children: [
                NavigationRail(
                  minWidth: 56,
                  selectedIndex: _section.index,
                  onDestinationSelected: (i) {
                    setState(() {
                      _section = _MainSection.values[i];
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.list_alt_outlined),
                      selectedIcon: Icon(Icons.list_alt),
                      label: Text('清单'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.calendar_today_outlined),
                      selectedIcon: Icon(Icons.calendar_today),
                      label: Text('日历'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('设置'),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 4,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _showAI ? '隐藏 AI 对话' : '显示 AI 对话',
                        icon: Icon(_showAI ? Icons.chat : Icons.chat_bubble_outline),
                        onPressed: () {
                          setState(() {
                            _showAI = !_showAI;
                          });
                        },
                      ),
                      const SizedBox(height: 6),
                      IconButton(
                        tooltip: isDark ? '切换到日间模式' : '切换到夜间模式',
                        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                        onPressed: () {
                          final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                          context.read<ThemeProvider>().setMode(newMode);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _buildMainArea(context)),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context) {
    switch (_section) {
      case _MainSection.todo:
        return const TodoPane();
      case _MainSection.calendar:
        return const ScheduleScreen();
      case _MainSection.settings:
        return const SettingsScreen();
    }
  }

  Widget _buildMainArea(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_showAI) {
          return _buildSection(context);
        }
        final total = constraints.maxWidth;
        final aiWidth = (total - _handleWidth) * _aiRatio;
        final contentWidth = total - _handleWidth - aiWidth;
        return Row(
          children: [
            SizedBox(width: contentWidth, child: _buildSection(context)),
            _VerticalResizeHandle(
              width: _handleWidth,
              onDragDelta: (dx) {
                setState(() {
                  _aiRatio = (_aiRatio - dx / total).clamp(_aiMinRatio, _aiMaxRatio);
                });
              },
            ),
            SizedBox(
              width: aiWidth,
              child: AIChatPanel(
                onClose: () {
                  setState(() {
                    _showAI = false;
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VerticalResizeHandle extends StatelessWidget {
  final double width;
  final ValueChanged<double> onDragDelta;
  const _VerticalResizeHandle({required this.width, required this.onDragDelta});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDragDelta(d.delta.dx),
        child: SizedBox(
          width: width,
          child: Center(
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}

