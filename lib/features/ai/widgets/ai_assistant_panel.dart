import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../models/ai_assistant_model.dart';
import '../../../providers/ai_providers.dart';

/// Slide-in AI assistant chat panel (left side). Shows a setup form until the
/// user has saved an API key, then a chat that can answer questions about all
/// HR data.
class AiAssistantPanel extends ConsumerWidget {
  const AiAssistantPanel({super.key});

  static const double width = 380;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(aiConfigProvider);

    return Material(
      elevation: 16,
      color: AppColors.surface,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: Column(
          children: [
            _Header(
              onClose: () =>
                  ref.read(aiPanelOpenProvider.notifier).state = false,
            ),
            const Divider(height: 1, color: AppColors.cardBorder),
            Expanded(
              child: configAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (config) => (config != null && config.isReady)
                    ? _ChatView(config: config)
                    : const _SetupView(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(aiConfigProvider).valueOrNull;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandBlue, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('HR Assistant',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.heading)),
                Text(
                  config != null && config.isReady
                      ? '${config.provider.label} · ${config.model}'
                      : 'Not connected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (config != null && config.isReady)
            IconButton(
              tooltip: 'Change API key / model',
              icon: const Icon(Icons.settings_outlined,
                  size: 18, color: AppColors.textMuted),
              onPressed: () => ref.read(aiConfigProvider.notifier).clear(),
            ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded,
                size: 20, color: AppColors.textMuted),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// ── Setup: paste key → auto-detect provider → fetch models → save ─────────
class _SetupView extends ConsumerStatefulWidget {
  const _SetupView();

  @override
  ConsumerState<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends ConsumerState<_SetupView> {
  final _keyController = TextEditingController();
  AiProvider _detected = AiProvider.unknown;
  List<String> _models = [];
  String? _selectedModel;
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final key = _keyController.text.trim();
    final guess = AiProviderX.detect(key);
    if (guess == AiProvider.unknown) {
      setState(() => _error =
          'Could not recognise this key. Paste a Claude (sk-ant-…), OpenAI / '
          'DeepSeek (sk-…), Groq (gsk_…) or Gemini (AIza…) key.');
      return;
    }
    setState(() {
      _detected = guess;
      _connecting = true;
      _error = null;
      _models = [];
      _selectedModel = null;
    });
    try {
      // connect() probes to resolve the OpenAI-vs-DeepSeek (sk-) ambiguity.
      final result =
          await ref.read(aiAssistantServiceProvider).connect(key);
      if (!mounted) return;
      setState(() {
        _detected = result.provider;
        _models = result.models;
        _selectedModel = result.models.isNotEmpty
            ? result.models.first
            : result.provider.fallbackModel;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Key worked enough to detect provider; allow a fallback model.
        _error = '$e';
        _models = [];
        _selectedModel = guess.fallbackModel;
      });
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _save() async {
    final model = _selectedModel ?? _detected.fallbackModel;
    if (model.isEmpty) return;
    await ref.read(aiConfigProvider.notifier).save(AiConfig(
          provider: _detected,
          apiKey: _keyController.text.trim(),
          model: model,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final connected = _detected != AiProvider.unknown && !_connecting;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.key_rounded, size: 40, color: AppColors.brandBlue),
        const SizedBox(height: 10),
        const Text('Connect your AI',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.heading)),
        const SizedBox(height: 6),
        const Text(
          'Paste any chat API key — Claude, OpenAI, DeepSeek, Groq or Gemini. '
          'We detect the provider automatically and load its models. The key '
          'is stored only on this device.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _keyController,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: 'API key',
            hintText: 'sk-ant-…  /  sk-…  /  gsk_…  /  AIza…',
            prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (v) {
            final p = AiProviderX.detect(v.trim());
            if (p != _detected) setState(() => _detected = p);
          },
          onSubmitted: (_) => _connect(),
        ),
        const SizedBox(height: 8),
        if (_keyController.text.trim().isNotEmpty)
          Row(
            children: [
              Icon(
                _detected == AiProvider.unknown
                    ? Icons.help_outline_rounded
                    : Icons.check_circle_rounded,
                size: 15,
                color: _detected == AiProvider.unknown
                    ? AppColors.textFaint
                    : AppColors.success,
              ),
              const SizedBox(width: 6),
              Text(
                _detected == AiProvider.unknown
                    ? 'Provider: not recognised yet'
                    : 'Detected: ${_detected.label}',
                style: TextStyle(
                    fontSize: 12,
                    color: _detected == AiProvider.unknown
                        ? AppColors.textFaint
                        : AppColors.success,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        const SizedBox(height: 12),
        if (_connecting)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Loading models…',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
          )
        else
          PrimaryButton(
            label: 'Connect',
            icon: Icons.link_rounded,
            onPressed: _connect,
          ),
        if (_models.isNotEmpty || (connected && _selectedModel != null)) ...[
          const SizedBox(height: 16),
          const Text('Model',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.cardBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _models.isNotEmpty
                ? DropdownButton<String>(
                    value: _selectedModel,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textBody),
                    items: [
                      for (final m in _models)
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (v) => setState(() => _selectedModel = v),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(_selectedModel ?? '',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textBody)),
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Save & Start',
              icon: Icons.check_rounded,
              color: AppColors.success,
              onPressed: _save,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pillRedBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.pillRedFg)),
          ),
        ],
      ],
    );
  }
}

/// ── Chat ──────────────────────────────────────────────────────────────────
class _ChatView extends ConsumerStatefulWidget {
  const _ChatView({required this.config});
  final AiConfig config;

  @override
  ConsumerState<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<_ChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<AiChatMessage> _messages = [];
  bool _sending = false;

  static const _suggestions = [
    'How many employees are active?',
    'Who is absent today?',
    'Show salary of the highest-paid employee',
    'Who took the most leaves this month?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _messages.add(AiChatMessage(role: 'user', content: text));
      _sending = true;
    });
    _scrollToEnd();
    try {
      final context = await ref.read(aiDataContextProvider.future);
      final system = _systemPrompt(context);
      final reply = await ref.read(aiAssistantServiceProvider).chat(
            config: widget.config,
            systemPrompt: system,
            messages: _messages,
          );
      if (!mounted) return;
      setState(() => _messages.add(
          AiChatMessage(role: 'assistant', content: reply.isEmpty
              ? '(empty response)'
              : reply)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages
          .add(AiChatMessage(role: 'assistant', content: '⚠️ $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  String _systemPrompt(String data) {
    return 'You are the HR Assistant inside an HR management app. Answer the '
        "user's questions using ONLY the HR data snapshot below. Be concise and "
        'specific; use names and numbers from the data. If the answer is not in '
        'the data, say you could not find it. Do not invent records.\n\n'
        '--- HR DATA SNAPSHOT ---\n$data\n--- END DATA ---';
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _empty()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(14),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= _messages.length) return const _TypingBubble();
                    return _Bubble(message: _messages[i]);
                  },
                ),
        ),
        const Divider(height: 1, color: AppColors.cardBorder),
        _inputBar(),
      ],
    );
  }

  Widget _empty() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.auto_awesome_rounded,
            size: 36, color: AppColors.brandBlue),
        const SizedBox(height: 10),
        const Text('Ask about your HR data',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.heading)),
        const SizedBox(height: 4),
        const Text(
          'Employees, attendance, leave, payroll and custom tables.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        for (final s in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _send(s),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.north_east_rounded,
                        size: 14, color: AppColors.textFaint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textBody)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: AppColors.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Ask anything about your HR data…',
                hintStyle: const TextStyle(fontSize: 13),
                filled: true,
                fillColor: AppColors.canvas,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _sending ? AppColors.textFaint : AppColors.brandBlue,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _sending ? null : () => _send(),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? AppColors.brandBlue : AppColors.canvas,
          borderRadius: BorderRadius.circular(12),
          border: isUser ? null : Border.all(color: AppColors.cardBorder),
        ),
        child: SelectableText(
          message.content,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: isUser ? Colors.white : AppColors.textBody,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
