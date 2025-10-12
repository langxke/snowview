import 'package:hive/hive.dart';
import '../models/journal_entry_hive.dart';

/// 记录数据仓库
class JournalRepository {
  static const String _boxName = 'journal_entries';

  // 获取Box实例（添加检查）
  Box<JournalEntryHive> get _box {
    if (!Hive.isBoxOpen(_boxName)) {
      throw HiveError('Journal box not opened. Please call JournalRepository.init() first.');
    }
    return Hive.box<JournalEntryHive>(_boxName);
  }

  // === 初始化 ===

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<JournalEntryHive>(_boxName);
    }
  }

  // === CRUD 操作 ===

  /// 保存记录
  Future<void> saveEntry(JournalEntryHive entry) async {
    await _box.put(entry.id, entry);
  }

  /// 更新记录
  Future<void> updateEntry(JournalEntryHive entry) async {
    await _box.put(entry.id, entry);
  }

  /// 删除记录
  Future<void> deleteEntry(String entryId) async {
    await _box.delete(entryId);
  }

  /// 根据ID获取记录
  JournalEntryHive? getEntryById(String entryId) {
    return _box.get(entryId);
  }

  // === 查询方法 ===

  /// 获取所有记录
  List<JournalEntryHive> getAllEntries() {
    return _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // 按创建时间倒序
  }

  /// 获取指定类别的记录
  List<JournalEntryHive> getEntriesByCategoryId(String categoryId) {
    return _box.values
        .where((entry) => entry.categoryId == categoryId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 获取指定日期的记录
  List<JournalEntryHive> getEntriesByDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return _box.values.where((entry) {
      final entryDate = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      return entryDate.isAtSameMomentAs(targetDate);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 获取包含指定标签的记录
  List<JournalEntryHive> getEntriesByTag(String tag) {
    return _box.values
        .where((entry) => entry.tags.contains(tag))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 获取置顶的记录
  List<JournalEntryHive> getPinnedEntries() {
    return _box.values
        .where((entry) => entry.isPinned)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 获取时间范围内的记录
  List<JournalEntryHive> getEntriesInRange(DateTime start, DateTime end) {
    return _box.values.where((entry) {
      return !entry.createdAt.isBefore(start) && !entry.createdAt.isAfter(end);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // === 搜索 ===

  /// 搜索记录（标题和内容）
  List<JournalEntryHive> searchEntries(String query) {
    if (query.trim().isEmpty) {
      return getAllEntries();
    }

    final lowerQuery = query.toLowerCase();
    return _box.values.where((entry) {
      return entry.title.toLowerCase().contains(lowerQuery) ||
             entry.content.toLowerCase().contains(lowerQuery) ||
             entry.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // === 统计 ===

  /// 获取指定类别的记录数量
  int getEntryCountByCategoryId(String categoryId) {
    if (categoryId == 'all') {
      return _box.length;
    }
    return _box.values.where((entry) => entry.categoryId == categoryId).length;
  }

  /// 获取所有标签（去重并排序）
  List<String> getAllTags() {
    final tagSet = <String>{};
    for (final entry in _box.values) {
      tagSet.addAll(entry.tags);
    }
    final tags = tagSet.toList()..sort();
    return tags;
  }

  /// 获取标签使用次数
  Map<String, int> getTagCounts() {
    final tagCounts = <String, int>{};
    for (final entry in _box.values) {
      for (final tag in entry.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    return tagCounts;
  }

  // === 业务逻辑 ===

  /// 切换置顶状态
  Future<void> togglePin(String entryId) async {
    final entry = getEntryById(entryId);
    if (entry != null) {
      final updated = entry.copyWith(
        isPinned: !entry.isPinned,
        updatedAt: DateTime.now(),
      );
      await updateEntry(updated);
    }
  }

  /// 添加标签
  Future<void> addTag(String entryId, String tag) async {
    final entry = getEntryById(entryId);
    if (entry != null && !entry.tags.contains(tag)) {
      final newTags = [...entry.tags, tag];
      final updated = entry.copyWith(
        tags: newTags,
        updatedAt: DateTime.now(),
      );
      await updateEntry(updated);
    }
  }

  /// 移除标签
  Future<void> removeTag(String entryId, String tag) async {
    final entry = getEntryById(entryId);
    if (entry != null) {
      final newTags = entry.tags.where((t) => t != tag).toList();
      final updated = entry.copyWith(
        tags: newTags,
        updatedAt: DateTime.now(),
      );
      await updateEntry(updated);
    }
  }

  /// 批量删除记录
  Future<void> deleteMultipleEntries(List<String> entryIds) async {
    await _box.deleteAll(entryIds);
  }

  /// 清空所有记录
  Future<void> clearAllEntries() async {
    await _box.clear();
  }
}

