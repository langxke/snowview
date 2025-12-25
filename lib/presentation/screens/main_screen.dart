import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/focus_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/custom_title_bar.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'tasks/task_list_screen.dart';
import 'focus/focus_screen.dart';
import 'ai_chat_panel.dart';

enum _MainSection { todo, calendar, focus, settings }

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // GlobalKey 确保 IndexedStack 状态在布局变化时保持
  final _sectionStackKey = GlobalKey();

  // 右侧 AI 面板是否显示
  bool _showAI = false;

  // AI 面板宽度比例
  double _aiRatio = 1 / 3;
  static const double _aiMinRatio = 0.2;
  static const double _aiMaxRatio = 0.6;
  static const double _handleWidth = 8.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navigationProvider = context.watch<NavigationProvider>();
    
    return Column(
      children: [
        // 自定义标题栏 - 会随主题变化而改变颜色
        const CustomTitleBar(),
        
        // 主内容区域
        Expanded(
          child: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Stack(
                    children: [
                      NavigationRail(
                        minWidth: 56,
                        selectedIndex: navigationProvider.currentIndex,
                        onDestinationSelected: (i) {
                          if (i == 0) {
                            if (navigationProvider.currentIndex == 1) {
                              navigationProvider.toggleCalendarChecklist();
                              return;
                            }

                            // 从其他页面点击“清单”：跳转到日历页并展开左侧清单
                            navigationProvider.navigateTo(1);
                            navigationProvider.toggleCalendarChecklist();
                            return;
                          }

                          navigationProvider.navigateTo(i);
                        },
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          NavigationRailDestination(
                            icon: Icon(
                              navigationProvider.currentIndex == 1 &&
                                      navigationProvider.isCalendarChecklistExpanded
                                  ? Icons.arrow_back
                                  : Icons.list_alt_outlined,
                            ),
                            selectedIcon: Icon(
                              navigationProvider.currentIndex == 1 &&
                                      navigationProvider.isCalendarChecklistExpanded
                                  ? Icons.arrow_back
                                  : Icons.list_alt,
                            ),
                            label: const Text('清单'),
                          ),
                          const NavigationRailDestination(
                            icon: Icon(Icons.calendar_today_outlined),
                            selectedIcon: Icon(Icons.calendar_today),
                            label: Text('日历'),
                          ),
                          const NavigationRailDestination(
                            icon: Icon(Icons.timer_outlined),
                            selectedIcon: Icon(Icons.timer),
                            label: Text('专注'),
                          ),
                          const NavigationRailDestination(
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
                            // AI助手按钮
                            Column(
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
                                Text(
                                  'AI助手',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
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
          ),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final currentSection = _MainSection.values[navigationProvider.currentIndex];
    
    // 使用 IndexedStack 保持所有页面状态，配合 GlobalKey 确保位置变化时状态不丢失
    final indexedStack = IndexedStack(
      key: _sectionStackKey,
      index: navigationProvider.currentIndex,
      children: const [
        TaskListScreen(),
        ScheduleScreen(),
        FocusScreen(),
        SettingsScreen(),
      ],
    );
    
    // 如果不在专注页面，且有活动会话，显示顶部状态条
    if (currentSection != _MainSection.focus) {
      return Consumer<FocusProvider>(
        builder: (context, focusProvider, child) {
          if (focusProvider.isActive) {
            return Column(
              children: [
                _buildFocusStatusBar(context, focusProvider),
                Expanded(child: indexedStack),
              ],
            );
          }
          return indexedStack;
        },
      );
    }
    
    return indexedStack;
  }
  
  /// 构建专注状态条
  Widget _buildFocusStatusBar(BuildContext context, FocusProvider provider) {
    final theme = Theme.of(context);
    final navigationProvider = context.read<NavigationProvider>();
    
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: () {
          navigationProvider.navigateToFocus();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                provider.isPaused ? Icons.pause_circle : Icons.timer,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Text(
                provider.isPaused ? '专注已暂停' : '专注进行中',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                provider.formattedTime,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
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

