import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_assistant_model.dart';

/// Talks to the user's chosen AI provider directly from the app, using their
/// own API key. Supports Anthropic (Claude), OpenAI and Google Gemini. The
/// provider is detected from the key, then we can list models and chat.
class AiAssistantService {
  AiAssistantService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// List the models available to this key. Throws [AiException] on failure.
  Future<List<String>> listModels(AiProvider provider, String apiKey) async {
    switch (provider) {
      case AiProvider.anthropic:
        return _listAnthropic(apiKey);
      case AiProvider.openai:
        return _listOpenAi(apiKey);
      case AiProvider.gemini:
        return _listGemini(apiKey);
      case AiProvider.unknown:
        throw const AiException('Unrecognised API key format.');
    }
  }

  /// Send a chat turn and return the assistant's reply text.
  Future<String> chat({
    required AiConfig config,
    required String systemPrompt,
    required List<AiChatMessage> messages,
  }) async {
    switch (config.provider) {
      case AiProvider.anthropic:
        return _chatAnthropic(config, systemPrompt, messages);
      case AiProvider.openai:
        return _chatOpenAi(config, systemPrompt, messages);
      case AiProvider.gemini:
        return _chatGemini(config, systemPrompt, messages);
      case AiProvider.unknown:
        throw const AiException('No AI provider configured.');
    }
  }

  // ── Anthropic (Claude) ──────────────────────────────────────────────────
  Map<String, String> _anthropicHeaders(String key) => {
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
        // Allows calling the API straight from a browser (Flutter web).
        'anthropic-dangerous-direct-browser-access': 'true',
      };

  Future<List<String>> _listAnthropic(String key) async {
    final res = await _client.get(
      Uri.parse('https://api.anthropic.com/v1/models?limit=100'),
      headers: _anthropicHeaders(key),
    );
    _ensureOk(res);
    final data = (jsonDecode(res.body)['data'] as List? ?? []);
    return data.map((m) => m['id'].toString()).toList();
  }

  Future<String> _chatAnthropic(
      AiConfig c, String system, List<AiChatMessage> msgs) async {
    final res = await _client.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: _anthropicHeaders(c.apiKey),
      body: jsonEncode({
        'model': c.model,
        'max_tokens': 1500,
        'system': system,
        'messages': [
          for (final m in msgs) {'role': m.role, 'content': m.content},
        ],
      }),
    );
    _ensureOk(res);
    final content = (jsonDecode(res.body)['content'] as List? ?? []);
    final buf = StringBuffer();
    for (final block in content) {
      if (block is Map && block['type'] == 'text') buf.write(block['text']);
    }
    return buf.toString().trim();
  }

  // ── OpenAI ──────────────────────────────────────────────────────────────
  Map<String, String> _openAiHeaders(String key) => {
        'Authorization': 'Bearer $key',
        'content-type': 'application/json',
      };

  Future<List<String>> _listOpenAi(String key) async {
    final res = await _client.get(
      Uri.parse('https://api.openai.com/v1/models'),
      headers: _openAiHeaders(key),
    );
    _ensureOk(res);
    final data = (jsonDecode(res.body)['data'] as List? ?? []);
    final ids = data.map((m) => m['id'].toString()).toList();
    // Surface chat-capable models first.
    ids.sort((a, b) {
      bool chat(String s) => s.startsWith('gpt') || s.startsWith('o');
      if (chat(a) && !chat(b)) return -1;
      if (!chat(a) && chat(b)) return 1;
      return a.compareTo(b);
    });
    return ids;
  }

  Future<String> _chatOpenAi(
      AiConfig c, String system, List<AiChatMessage> msgs) async {
    final res = await _client.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: _openAiHeaders(c.apiKey),
      body: jsonEncode({
        'model': c.model,
        'messages': [
          {'role': 'system', 'content': system},
          for (final m in msgs) {'role': m.role, 'content': m.content},
        ],
      }),
    );
    _ensureOk(res);
    final choices = (jsonDecode(res.body)['choices'] as List? ?? []);
    if (choices.isEmpty) return '';
    return (choices.first['message']?['content'] ?? '').toString().trim();
  }

  // ── Google Gemini ───────────────────────────────────────────────────────
  Future<List<String>> _listGemini(String key) async {
    final res = await _client.get(
      Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$key'),
    );
    _ensureOk(res);
    final models = (jsonDecode(res.body)['models'] as List? ?? []);
    return models
        .where((m) =>
            (m['supportedGenerationMethods'] as List? ?? [])
                .contains('generateContent'))
        .map((m) => m['name'].toString().replaceFirst('models/', ''))
        .toList();
  }

  Future<String> _chatGemini(
      AiConfig c, String system, List<AiChatMessage> msgs) async {
    final res = await _client.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/'
          '${c.model}:generateContent?key=${c.apiKey}'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': system}
          ]
        },
        'contents': [
          for (final m in msgs)
            {
              // Gemini uses 'model' instead of 'assistant'.
              'role': m.isUser ? 'user' : 'model',
              'parts': [
                {'text': m.content}
              ],
            },
        ],
      }),
    );
    _ensureOk(res);
    final candidates = (jsonDecode(res.body)['candidates'] as List? ?? []);
    if (candidates.isEmpty) return '';
    final parts =
        (candidates.first['content']?['parts'] as List? ?? []);
    final buf = StringBuffer();
    for (final p in parts) {
      if (p is Map && p['text'] != null) buf.write(p['text']);
    }
    return buf.toString().trim();
  }

  // ── Shared ──────────────────────────────────────────────────────────────
  void _ensureOk(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String message = 'Request failed (${res.statusCode}).';
    try {
      final body = jsonDecode(res.body);
      final err = body['error'];
      if (err is Map && err['message'] != null) {
        message = err['message'].toString();
      } else if (err is String) {
        message = err;
      } else if (body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {/* keep default */}
    if (res.statusCode == 401 || res.statusCode == 403) {
      message = 'Invalid or unauthorised API key. $message';
    }
    throw AiException(message);
  }
}

class AiException implements Exception {
  const AiException(this.message);
  final String message;
  @override
  String toString() => message;
}
