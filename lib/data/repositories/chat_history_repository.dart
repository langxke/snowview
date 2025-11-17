import 'package:hive/hive.dart';
import '../models/chat_message_hive.dart';

/// 对话历史数据仓库
class ChatHistoryRepository {
  static const String _boxName = 'chat_messages';

  /// 获取消息Box
  Box<ChatMessageHive> get _box => Hive.box<ChatMessageHive>(_boxName);

  /// 保存单条消息
  Future<void> saveMessage(ChatMessageHive message) async {
    await _box.put(message.id, message);
  }

  /// 批量保存消息
  Future<void> saveMessages(List<ChatMessageHive> messages) async {
    final entries = {for (var msg in messages) msg.id: msg};
    await _box.putAll(entries);
  }

  /// 获取所有消息（按时间排序）
  List<ChatMessageHive> getAllMessages() {
    final messages = _box.values.toList();
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  /// 获取最近N条消息
  List<ChatMessageHive> getRecentMessages(int count) {
    final messages = getAllMessages();
    if (messages.length <= count) {
      return messages;
    }
    return messages.sublist(messages.length - count);
  }

  /// 根据ID获取消息
  ChatMessageHive? getMessageById(String id) {
    return _box.get(id);
  }

  /// 删除单条消息
  Future<void> deleteMessage(String id) async {
    await _box.delete(id);
  }

  /// 删除所有消息
  Future<void> clearAllMessages() async {
    await _box.clear();
  }

  /// 获取消息总数
  int getMessageCount() {
    return _box.length;
  }

  /// 获取某个时间段内的消息
  List<ChatMessageHive> getMessagesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return _box.values.where((message) {
      return message.timestamp.isAfter(startDate) &&
          message.timestamp.isBefore(endDate);
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// 获取今天的消息
  List<ChatMessageHive> getTodayMessages() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getMessagesByDateRange(startOfDay, endOfDay);
  }

  /// 更新消息列表（用于压缩/总结对话）
  Future<void> updateMessages(List<ChatMessageHive> messages) async {
    await clearAllMessages();
    await saveMessages(messages);
  }

  /// 删除指定数量的旧消息
  Future<void> deleteOldestMessages(int count) async {
    final messages = getAllMessages();
    if (messages.length <= count) {
      await clearAllMessages();
      return;
    }

    final toDelete = messages.take(count);
    for (var message in toDelete) {
      await deleteMessage(message.id);
    }
  }

  /// 只保留最近N条消息
  Future<void> keepRecentMessages(int count) async {
    final messages = getAllMessages();
    if (messages.length <= count) {
      return;
    }

    final toDelete = messages.take(messages.length - count);
    for (var message in toDelete) {
      await deleteMessage(message.id);
    }
  }

  /// 根据角色获取消息
  List<ChatMessageHive> getMessagesByRole(String role) {
    return _box.values
        .where((message) => message.role == role)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// 获取所有用户消息
  List<ChatMessageHive> getUserMessages() {
    return getMessagesByRole('user');
  }

  /// 获取所有助手消息
  List<ChatMessageHive> getAssistantMessages() {
    return getMessagesByRole('assistant');
  }

  // ==================== 会话相关方法 ====================

  /// 根据会话ID获取所有消息（按时间排序）
  List<ChatMessageHive> getMessagesBySessionId(String sessionId) {
    return _box.values
        .where((message) => (message.sessionId ?? 'default') == sessionId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
  
  /// 迁移旧数据：将没有sessionId的消息设置为默认会话ID
  Future<void> migrateOldMessages(String defaultSessionId) async {
    var needsMigration = false;
    for (var message in _box.values) {
      if (message.sessionId == null) {
        message.sessionId = defaultSessionId;
        await message.save();
        needsMigration = true;
      }
    }
    if (needsMigration) {
      print('[ChatHistory] 已将 ${_box.values.where((m) => m.sessionId == defaultSessionId).length} 条旧消息迁移到默认会话');
    }
  }

  /// 获取某个会话的最近N条消息
  List<ChatMessageHive> getRecentMessagesBySessionId(String sessionId, int count) {
    final messages = getMessagesBySessionId(sessionId);
    if (messages.length <= count) {
      return messages;
    }
    return messages.sublist(messages.length - count);
  }

  /// 删除某个会话的所有消息
  Future<void> deleteMessagesBySessionId(String sessionId) async {
    final messages = getMessagesBySessionId(sessionId);
    for (var message in messages) {
      await deleteMessage(message.id);
    }
  }

  /// 获取某个会话的消息总数
  int getSessionMessageCount(String sessionId) {
    return _box.values.where((message) => (message.sessionId ?? 'default') == sessionId).length;
  }

  /// 获取所有不同的会话ID
  List<String> getAllSessionIds() {
    final sessionIds = <String>{};
    for (var message in _box.values) {
      sessionIds.add(message.sessionId ?? 'default');
    }
    return sessionIds.toList();
  }

  // ==================== 初始化方法 ====================

  /// 初始化数据库（打开Box）
  static Future<void> init() async {
    await Hive.openBox<ChatMessageHive>(_boxName);
  }

  /// 关闭数据库
  static Future<void> close() async {
    await Hive.box<ChatMessageHive>(_boxName).close();
  }
}

