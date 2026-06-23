// Models for the in-app AI assistant (bring-your-own API key).
//
// The provider is auto-detected from the shape of the API key, so the user
// only pastes a key — no dropdown needed.

enum AiProvider { anthropic, openai, gemini, unknown }

extension AiProviderX on AiProvider {
  String get label {
    switch (this) {
      case AiProvider.anthropic:
        return 'Claude (Anthropic)';
      case AiProvider.openai:
        return 'OpenAI (GPT)';
      case AiProvider.gemini:
        return 'Google Gemini';
      case AiProvider.unknown:
        return 'Unknown';
    }
  }

  /// A sensible model to fall back to if listing models fails.
  String get fallbackModel {
    switch (this) {
      case AiProvider.anthropic:
        return 'claude-3-5-sonnet-latest';
      case AiProvider.openai:
        return 'gpt-4o-mini';
      case AiProvider.gemini:
        return 'gemini-1.5-flash';
      case AiProvider.unknown:
        return '';
    }
  }

  /// Detect the provider from an API key's prefix.
  static AiProvider detect(String key) {
    final k = key.trim();
    if (k.startsWith('sk-ant-')) return AiProvider.anthropic;
    if (k.startsWith('AIza')) return AiProvider.gemini;
    if (k.startsWith('sk-')) return AiProvider.openai;
    return AiProvider.unknown;
  }
}

/// Saved configuration: which provider, the key, and the chosen model.
class AiConfig {
  const AiConfig({
    required this.provider,
    required this.apiKey,
    required this.model,
  });

  final AiProvider provider;
  final String apiKey;
  final String model;

  bool get isReady =>
      provider != AiProvider.unknown && apiKey.isNotEmpty && model.isNotEmpty;

  AiConfig copyWith({AiProvider? provider, String? apiKey, String? model}) {
    return AiConfig(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  Map<String, dynamic> toMap() => {
        'provider': provider.name,
        'apiKey': apiKey,
        'model': model,
      };

  factory AiConfig.fromMap(Map<String, dynamic> map) {
    return AiConfig(
      provider: AiProvider.values.firstWhere(
        (p) => p.name == map['provider'],
        orElse: () => AiProvider.unknown,
      ),
      apiKey: map['apiKey'] as String? ?? '',
      model: map['model'] as String? ?? '',
    );
  }
}

/// One chat message.
class AiChatMessage {
  const AiChatMessage({required this.role, required this.content});

  /// 'user' or 'assistant'.
  final String role;
  final String content;

  bool get isUser => role == 'user';
}
