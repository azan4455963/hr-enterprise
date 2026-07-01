import '../core/utils/firestore_parse.dart';

/// A 1-to-1 conversation between two users. Doc id is the two uids sorted and
/// joined, so opening a chat is idempotent (never duplicates).
class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.participantIds,
    this.participantNames = const {},
    this.lastMessage,
    this.lastSenderId,
    this.lastMessageAt,
  });

  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames; // uid -> display name
  final String? lastMessage;
  final String? lastSenderId;
  final DateTime? lastMessageAt;

  bool hasParticipant(String uid) => participantIds.contains(uid);

  String otherId(String myUid) =>
      participantIds.firstWhere((p) => p != myUid, orElse: () => myUid);

  String nameOf(String uid) => participantNames[uid] ?? 'Unknown';

  String otherName(String myUid) => nameOf(otherId(myUid));

  factory ConversationModel.fromMap(String id, Map<String, dynamic> m) {
    final names = <String, String>{};
    final raw = m['participantNames'];
    if (raw is Map) {
      raw.forEach((k, v) => names[k.toString()] = v.toString());
    }
    return ConversationModel(
      id: id,
      participantIds: List<String>.from(m['participantIds'] as List? ?? const []),
      participantNames: names,
      lastMessage: m['lastMessage'] as String?,
      lastSenderId: m['lastSenderId'] as String?,
      lastMessageAt: parseFirestoreDate(m['lastMessageAt']),
    );
  }
}

/// One message inside a conversation.
class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.sentAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? sentAt;

  factory ChatMessageModel.fromMap(String id, Map<String, dynamic> m) {
    return ChatMessageModel(
      id: id,
      senderId: m['senderId'] as String? ?? '',
      senderName: m['senderName'] as String? ?? '',
      text: m['text'] as String? ?? '',
      sentAt: parseFirestoreDate(m['sentAt']),
    );
  }
}
