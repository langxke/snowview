import 'package:hive/hive.dart';

part 'chat_session_hive.g.dart';

/// 聊天会话
@HiveType(typeId: 11)
class ChatSessionHive extends HiveObject {
  /// 会话ID
  @HiveField(0)
  String id;

  /// 会话标题
  @HiveField(1)
  String title;

  /// 创建时间
  @HiveField(2)
  DateTime createdAt;

  /// 最后更新时间
  @HiveField(3)
  DateTime updatedAt;

  /// 消息ID列表（关联到 ChatMessageHive）
  @HiveField(4)
  List<String> messageIds;

  ChatSessionHive({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageIds,
  });

  /// 创建新会话
  factory ChatSessionHive.create({
    required String id,
    String? title,
  }) {
    final now = DateTime.now();
    return ChatSessionHive(
      id: id,
      title: title ?? '新对话',
      createdAt: now,
      updatedAt: now,
      messageIds: [],
    );
  }

  /// 添加消息ID
  void addMessageId(String messageId) {
    messageIds.add(messageId);
    updatedAt = DateTime.now();
  }

  /// 更新标题
  void updateTitle(String newTitle) {
    title = newTitle;
    updatedAt = DateTime.now();
  }

  /// 获取消息数量
  int get messageCount => messageIds.length;

  /// 是否为空会话
  bool get isEmpty => messageIds.isEmpty;
}

