import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import '../models/journal_category_hive.dart';

/// 记录类别数据仓库
class JournalCategoryRepository {
  static const String _boxName = 'journal_categories';

  // 获取Box实例
  Box<JournalCategoryHive> get _box {
    if (!Hive.isBoxOpen(_boxName)) {
      throw HiveError('Journal category box not opened. Please call JournalCategoryRepository.init() first.');
    }
    return Hive.box<JournalCategoryHive>(_boxName);
  }

  // === 初始化 ===

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<JournalCategoryHive>(_boxName);
    }
  }

  // === CRUD 操作 ===

  /// 保存类别
  Future<void> saveCategory(JournalCategoryHive category) async {
    await _box.put(category.id, category);
  }

  /// 更新类别
  Future<void> updateCategory(JournalCategoryHive category) async {
    await _box.put(category.id, category);
  }

  /// 删除类别
  Future<void> deleteCategory(String categoryId) async {
    await _box.delete(categoryId);
  }

  /// 根据ID获取类别
  JournalCategoryHive? getCategoryById(String categoryId) {
    return _box.get(categoryId);
  }

  // === 查询方法 ===

  /// 获取所有类别
  List<JournalCategoryHive> getAllCategories() {
    return _box.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order)); // 按排序序号
  }

  // === 业务逻辑 ===

  /// 创建默认类别
  Future<void> createDefaultCategories() async {
    // 检查是否已有类别
    if (_box.isNotEmpty) return;

    final now = DateTime.now();
    
    final defaultCategories = [
      JournalCategoryHive(
        id: 'daily',
        name: '日记',
        colorValue: Colors.blue.value,
        order: 0,
        createdAt: now,
      ),
      JournalCategoryHive(
        id: 'weekly',
        name: '周记',
        colorValue: Colors.green.value,
        order: 1,
        createdAt: now,
      ),
      JournalCategoryHive(
        id: 'note',
        name: '随笔',
        colorValue: Colors.orange.value,
        order: 2,
        createdAt: now,
      ),
    ];

    for (final category in defaultCategories) {
      await saveCategory(category);
    }
  }

  /// 获取下一个排序序号
  int getNextOrder() {
    if (_box.isEmpty) return 0;
    final maxOrder = _box.values.map((c) => c.order).reduce((a, b) => a > b ? a : b);
    return maxOrder + 1;
  }
}


