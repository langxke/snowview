import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/journal_entry_hive.dart';
import '../../data/models/journal_category_hive.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/journal_category_repository.dart';
import '../../data/repositories/focus_session_repository.dart';

/// 记录功能状态管理
class JournalProvider extends ChangeNotifier {
  final JournalRepository _repository;
  final JournalCategoryRepository _categoryRepo = JournalCategoryRepository();
  final FocusSessionRepository _focusRepo = FocusSessionRepository();

  JournalProvider(this._repository) {
    // 延迟加载，确保 Box 已打开
    Future.microtask(() async {
      await _loadCategories();
      await _loadEntries();
    });
  }

  // === 状态属性 ===

  List<JournalCategoryHive> _categories = [];
  List<JournalEntryHive> _allEntries = [];
  String _selectedCategoryId = 'all';        // 当前选中的类别ID
  String? _selectedEntryId;                  // 当前选中的记录ID
  String? _selectedTag;
  String _searchQuery = '';

  // === Getters ===

  /// 当前筛选后的记录列表
  List<JournalEntryHive> get entries {
    List<JournalEntryHive> filtered = _allEntries;

    // 按类别筛选
    if (_selectedCategoryId != 'all') {
      filtered = filtered.where((e) => e.categoryId == _selectedCategoryId).toList();
    }

    // 按标签筛选（暂时不使用，保留代码）
    // if (_selectedTag != null) {
    //   filtered = filtered.where((e) => e.tags.contains(_selectedTag)).toList();
    // }

    // 按搜索关键词筛选
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((e) {
        return e.title.toLowerCase().contains(query) ||
               e.content.toLowerCase().contains(query) ||
               e.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    // 置顶的记录排在前面
    filtered.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    return filtered;
  }

  /// 置顶的记录
  List<JournalEntryHive> get pinnedEntries {
    return _allEntries.where((e) => e.isPinned).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 所有类别
  List<JournalCategoryHive> get categories => _categories;

  /// 所有标签（暂时不使用）
  List<String> get allTags {
    return _repository.getAllTags();
  }

  /// 各类别数量统计
  Map<String, int> get entryCountByCategory {
    final counts = {'all': _allEntries.length};
    for (final category in _categories) {
      counts[category.id] = _allEntries.where((e) => e.categoryId == category.id).length;
    }
    return counts;
  }

  /// 当前选中的类别ID
  String get selectedCategoryId => _selectedCategoryId;

  /// 当前选中的记录ID
  String? get selectedEntryId => _selectedEntryId;

  /// 当前选中的记录
  JournalEntryHive? get selectedEntry {
    if (_selectedEntryId == null) return null;
    try {
      return _allEntries.firstWhere((e) => e.id == _selectedEntryId);
    } catch (e) {
      return null;
    }
  }

  /// 当前选中的类别
  JournalCategoryHive? get selectedCategory {
    if (_selectedCategoryId == 'all') return null;
    return _categoryRepo.getCategoryById(_selectedCategoryId);
  }

  /// 当前选中的标签（暂时不使用）
  String? get selectedTag => _selectedTag;

  // === 初始化和加载 ===

  /// 加载类别
  Future<void> _loadCategories() async {
    try {
      _categories = _categoryRepo.getAllCategories();
      
      // 如果没有类别，创建默认类别
      if (_categories.isEmpty) {
        await _categoryRepo.createDefaultCategories();
        _categories = _categoryRepo.getAllCategories();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('加载类别失败: $e');
      _categories = [];
    }
  }

  /// 加载所有记录
  Future<void> _loadEntries() async {
    try {
      _allEntries = _repository.getAllEntries();
      notifyListeners();
    } catch (e) {
      debugPrint('加载记录失败: $e');
      _allEntries = [];
      notifyListeners();
    }
  }

  /// 重新加载记录（公开方法）
  Future<void> reload() async {
    await _loadCategories();
    await _loadEntries();
  }

  // === 核心方法 - CRUD ===

  /// 创建记录
  Future<void> createEntry({
    required String categoryId,
    String? title,
    String content = '',
    List<String> tags = const [],
    String? mood,
    List<String> relatedTaskIds = const [],
  }) async {
    final entry = JournalEntryHive(
      id: const Uuid().v4(),
      title: title ?? '',
      content: content,
      categoryId: categoryId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tags: tags,
      mood: mood,
      relatedTaskIds: relatedTaskIds,
      dailyFocusMinutes: null,
      isPinned: false,
    );

    // 如果是日记类别，自动填充当日专注数据
    if (categoryId == 'daily') {
      await autoFillDailyData(entry);
    }

    await _repository.saveEntry(entry);
    await _loadEntries();
  }

  /// 更新记录
  Future<void> updateEntry(JournalEntryHive entry) async {
    final updated = entry.copyWith(
      updatedAt: DateTime.now(),
    );
    await _repository.updateEntry(updated);
    await _loadEntries();
  }

  /// 删除记录
  Future<void> deleteEntry(String entryId) async {
    await _repository.deleteEntry(entryId);
    await _loadEntries();
  }

  // === 类别管理 ===

  /// 创建类别
  Future<void> createCategory({
    required String name,
    required Color color,
  }) async {
    final category = JournalCategoryHive(
      id: const Uuid().v4(),
      name: name,
      colorValue: color.value,
      order: _categoryRepo.getNextOrder(),
      createdAt: DateTime.now(),
    );

    await _categoryRepo.saveCategory(category);
    await _loadCategories();
  }

  /// 更新类别
  Future<void> updateCategory({
    required String id,
    String? name,
    Color? color,
  }) async {
    final category = _categoryRepo.getCategoryById(id);
    if (category != null) {
      final updated = category.copyWith(
        name: name,
        colorValue: color?.value,
      );
      await _categoryRepo.updateCategory(updated);
      await _loadCategories();
    }
  }

  /// 删除类别
  Future<void> deleteCategory(String categoryId) async {
    await _categoryRepo.deleteCategory(categoryId);
    
    // 如果删除的是当前选中类别，切换到"全部"
    if (_selectedCategoryId == categoryId) {
      _selectedCategoryId = 'all';
    }
    
    await _loadCategories();
  }

  // === 筛选方法 ===

  /// 选择类别
  void selectCategory(String categoryId) {
    _selectedCategoryId = categoryId;
    _selectedEntryId = null;  // 切换类别时清除选中的记录
    notifyListeners();
  }

  /// 选择记录
  void selectEntry(String? entryId) {
    _selectedEntryId = entryId;
    notifyListeners();
  }

  /// 选择标签（暂时不使用）
  void selectTag(String? tag) {
    _selectedTag = tag;
    notifyListeners();
  }

  /// 设置搜索关键词
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// 清除所有筛选
  void clearFilters() {
    _selectedCategoryId = 'all';
    _selectedTag = null;
    _searchQuery = '';
    notifyListeners();
  }

  // === 自动关联 ===

  /// 自动填充当日专注数据
  Future<void> autoFillDailyData(JournalEntryHive entry) async {
    try {
      // 获取当日专注统计
      final stats = _focusRepo.getStatsForDate(entry.createdAt);
      
      if (stats != null) {
        final focusMinutes = stats.totalFocusSeconds ~/ 60;
        
        // 更新记录的专注时长
        final updated = entry.copyWith(
          dailyFocusMinutes: focusMinutes,
        );
        
        // 如果内容为空，自动生成模板
        if (entry.content.trim().isEmpty) {
          final template = _generateDailyTemplate(stats);
          final withTemplate = updated.copyWith(content: template);
          await _repository.updateEntry(withTemplate);
        } else {
          await _repository.updateEntry(updated);
        }
      }
    } catch (e) {
      debugPrint('自动填充专注数据失败: $e');
    }
  }

  /// 生成日记模板
  String _generateDailyTemplate(dynamic stats) {
    final focusTime = stats.totalFocusSeconds ~/ 60;
    final pomodoroCount = stats.pomodoroCount;
    
    return '''
# ${_getFormattedDate(DateTime.now())} 日记

## 今日数据
- 🍅 完成 $pomodoroCount 个番茄钟
- ⏱️ 专注时长：$focusTime 分钟

## 今日完成
- 

## 收获和感悟
- 

## 明天计划
- 
''';
  }

  /// 格式化日期
  String _getFormattedDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  // === 标签管理 ===

  /// 添加标签到记录
  Future<void> addTagToEntry(String entryId, String tag) async {
    await _repository.addTag(entryId, tag);
    await _loadEntries();
  }

  /// 从记录移除标签
  Future<void> removeTagFromEntry(String entryId, String tag) async {
    await _repository.removeTag(entryId, tag);
    await _loadEntries();
  }

  // === 置顶 ===

  /// 切换置顶状态
  Future<void> togglePin(String entryId) async {
    await _repository.togglePin(entryId);
    await _loadEntries();
  }

  // === 快捷创建 ===

  /// 创建今日日记
  Future<void> createTodayDiary() async {
    await createEntry(
      categoryId: 'daily',
      title: '',  // 使用默认标题
      tags: [],
    );
  }

  /// 创建本周周记
  Future<void> createWeeklyJournal() async {
    await createEntry(
      categoryId: 'weekly',
      title: '',  // 使用默认标题
      tags: [],
    );
  }

  /// 从专注会话创建记录
  Future<void> createFromFocusSession({
    required dynamic session,  // FocusSessionHive
    String? taskTitle,
    int consecutiveCount = 0,
  }) async {
    final hour = session.endTime.hour.toString().padLeft(2, '0');
    final minute = session.endTime.minute.toString().padLeft(2, '0');
    
    final content = '''
# 专注记录 - $hour:$minute

刚刚完成了${taskTitle != null ? '「$taskTitle」任务的' : ''}专注会话

**专注时长**：${session.actualDuration ~/ 60}分钟
**连续番茄钟**：第$consecutiveCount个

## 收获和感想
''';

    await createEntry(
      categoryId: 'note',
      title: '专注记录 - ${taskTitle ?? ''}',
      content: content,
      tags: [],
      relatedTaskIds: session.taskId != null ? [session.taskId] : [],
    );
  }

  // === 批量操作 ===

  /// 批量删除记录
  Future<void> deleteMultipleEntries(List<String> entryIds) async {
    await _repository.deleteMultipleEntries(entryIds);
    await _loadEntries();
  }
}

