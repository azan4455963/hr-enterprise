import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/conversation_model.dart';
import '../models/user_model.dart';

/// Internal 1-to-1 chat backed by `conversations` + `conversations/{id}/messages`.
class ChatService {
  ChatService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _convos =>
      _db.collection('conversations');

  /// Deterministic conversation id for a pair of users (order-independent).
  String conversationId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}__${ids[1]}';
  }

  /// Create the conversation if it doesn't exist; returns its id.
  Future<String> openConversation({
    required UserModel me,
    required UserModel other,
  }) async {
    final id = conversationId(me.id, other.id);
    final ref = _convos.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participantIds': [me.id, other.id],
        'participantNames': {
          me.id: me.displayName ?? me.email,
          other.id: other.displayName ?? other.email,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    }
    return id;
  }

  Future<void> sendMessage({
    required String conversationId,
    required UserModel sender,
    required String text,
  }) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final ref = _convos.doc(conversationId);
    await ref.collection('messages').add({
      'senderId': sender.id,
      'senderName': sender.displayName ?? sender.email,
      'text': body,
      'sentAt': FieldValue.serverTimestamp(),
    });
    await ref.update({
      'lastMessage': body,
      'lastSenderId': sender.id,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  List<ConversationModel> _sorted(QuerySnapshot<Map<String, dynamic>> s) {
    final list =
        s.docs.map((d) => ConversationModel.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => (b.lastMessageAt ?? DateTime(0))
        .compareTo(a.lastMessageAt ?? DateTime(0)));
    return list;
  }

  /// The signed-in user's own conversations (sorted newest-first client-side).
  Stream<List<ConversationModel>> watchMyConversations(String uid) => _convos
      .where('participantIds', arrayContains: uid)
      .snapshots()
      .map(_sorted);

  /// Admin monitor: every conversation.
  Stream<List<ConversationModel>> watchAll() =>
      _convos.snapshots().map(_sorted);

  /// Mark [uid] as having read [conversationId] up to now (clears their badge).
  Future<void> markRead(String conversationId, String uid) async {
    try {
      await _convos.doc(conversationId).update({
        'readAt.$uid': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-critical.
    }
  }

  Stream<ConversationModel?> watchConversation(String id) =>
      _convos.doc(id).snapshots().map(
          (d) => d.exists ? ConversationModel.fromMap(d.id, d.data()!) : null);

  Stream<List<ChatMessageModel>> watchMessages(String conversationId) => _convos
      .doc(conversationId)
      .collection('messages')
      .orderBy('sentAt')
      .snapshots()
      .map((s) => s.docs
          .map((d) => ChatMessageModel.fromMap(d.id, d.data()))
          .toList());
}
