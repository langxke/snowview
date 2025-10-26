import 'package:hive/hive.dart';
import '../models/chat_session_hive.dart';

/// 聊天会话仓库
class ChatSessionRepository {
  static const String _boxName = 'chat_sessions';

  /// 初始化
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<ChatSessionHive>(_boxName);
    }
  }

  /// 获取Box
  Box<ChatSessionHive> get _box {
    if (!Hive.isBoxOpen(_boxName)) {
      throw HiveError('聊天会话Box未打开，请先调用 ChatSessionRepository.init()');
    }
    return Hive.box<ChatSessionHive>(_boxName);
  }

  /// 创建新会话
  Future<ChatSessionHive> createSession({
    required String id,
    String? title,
  }) async {
    final session = ChatSessionHive.create(
      id: id,
      title: title,
    );
    await _box.put(id, session);
    return session;
  }

  /// 获取会话
  ChatSessionHive? getSession(String id) {
    return _box.get(id);
  }

  /// 获取所有会话（按创建时间正序，最早的在前，最新的在后）
  List<ChatSessionHive> getAllSessions() {
    final sessions = _box.values.toList();
    sessions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sessions;
  }

  /// 更新会话
  Future<void> updateSession(ChatSessionHive session) async {
    await session.save();
  }

  /// 删除会话
  Future<void> deleteSession(String id) async {
    await _box.delete(id);
  }

  /// 清空所有会话
  Future<void> clearAll() async {
    await _box.clear();
  }

  /// 获取会话数量
  int getSessionCount() {
    return _box.length;
  }
}

