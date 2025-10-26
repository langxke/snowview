import 'package:hive/hive.dart';

part 'chat_message_hive.g.dart';

/// AI对话消息数据模型（Hive）
/// TypeId: 10
@HiveType(typeId: 10)
class ChatMessageHive extends HiveObject {
  /// 消息唯一标识
  @HiveField(0)
  String id;

  /// 消息角色：'user' | 'assistant' | 'system' | 'tool'
  @HiveField(1)
  String role;

  /// 消息内容
  @HiveField(2)
  String content;

  /// 时间戳
  @HiveField(3)
  DateTime timestamp;

  /// 工具调用ID（仅当role为'tool'时使用）
  @HiveField(4)
  String? toolCallId;

  /// 工具调用列表（JSON字符串数组）
  /// 仅当assistant调用工具时使用
  @HiveField(5)
  List<String>? toolCalls;

  /// 所属会话ID（旧数据可能为null，默认为'default'）
  @HiveField(6)
  String? sessionId;

  ChatMessageHive({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.toolCallId,
    this.toolCalls,
    this.sessionId,
  });

  /// 是否为用户消息
  bool get isUser => role == 'user';

  /// 是否为AI助手消息
  bool get isAssistant => role == 'assistant';

  /// 是否为系统消息
  bool get isSystem => role == 'system';

  /// 是否为工具调用消息
  bool get isTool => role == 'tool';

  /// 创建用户消息
  factory ChatMessageHive.user({
    required String id,
    required String content,
    required String sessionId,
    DateTime? timestamp,
  }) {
    return ChatMessageHive(
      id: id,
      role: 'user',
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      sessionId: sessionId,
    );
  }

  /// 创建助手消息
  factory ChatMessageHive.assistant({
    required String id,
    required String content,
    required String sessionId,
    DateTime? timestamp,
    List<String>? toolCalls,
  }) {
    return ChatMessageHive(
      id: id,
      role: 'assistant',
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      toolCalls: toolCalls,
      sessionId: sessionId,
    );
  }

  /// 创建系统消息
  factory ChatMessageHive.system({
    required String id,
    required String content,
    required String sessionId,
    DateTime? timestamp,
  }) {
    return ChatMessageHive(
      id: id,
      role: 'system',
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      sessionId: sessionId,
    );
  }

  /// 创建工具调用消息
  factory ChatMessageHive.tool({
    required String id,
    required String content,
    required String sessionId,
    required String toolCallId,
    DateTime? timestamp,
  }) {
    return ChatMessageHive(
      id: id,
      role: 'tool',
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      toolCallId: toolCallId,
      sessionId: sessionId,
    );
  }

  /// 创建副本
  ChatMessageHive copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    Object? toolCallId = _undefined,
    Object? toolCalls = _undefined,
    String? sessionId,
  }) {
    return ChatMessageHive(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      toolCallId:
          toolCallId == _undefined ? this.toolCallId : toolCallId as String?,
      toolCalls: toolCalls == _undefined
          ? this.toolCalls
          : toolCalls as List<String>?,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  @override
  String toString() {
    return 'ChatMessageHive{id: $id, role: $role, content: ${content.length > 50 ? content.substring(0, 50) + "..." : content}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessageHive &&
        other.id == id &&
        other.role == role &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(id, role, timestamp);
}

// 用于区分"未传值"和"传null"的哨兵值
const Object _undefined = Object();

