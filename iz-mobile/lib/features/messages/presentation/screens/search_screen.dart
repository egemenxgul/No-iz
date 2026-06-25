import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_provider.dart';
import 'package:go_router/go_router.dart';

class MessageSearchScreen extends ConsumerStatefulWidget {
  const MessageSearchScreen({super.key});

  @override
  ConsumerState<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends ConsumerState<MessageSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query == _lastQuery) return;
    _lastQuery = query;
    if (query.trim().length < 2) {
      setState(() { _results = []; _loading = false; });
      return;
    }
    setState(() { _loading = true; });
    try {
      final repo = ref.read(messageRepositoryProvider);
      final results = await repo.searchMessages(query);
      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  String _getConversationName(String conversationId) {
    final conversations = ref.read(conversationProvider);
    try {
      final match = conversations.firstWhere((c) => c.otherUserId == conversationId);
      return match.otherDisplayName ?? match.otherUsername;
    } catch (_) {
      return conversationId.length > 8 ? conversationId.substring(0, 8) : conversationId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Mesajlarda ara...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
          onChanged: (v) {
            Future.delayed(const Duration(milliseconds: 300), () => _search(v));
          },
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _controller.clear();
                setState(() { _results = []; _lastQuery = ''; });
              },
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_controller.text.trim().length < 2 && _results.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_rounded, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('Aramak için en az 2 karakter girin',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        ]),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_results.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('"${_controller.text}" için sonuç bulunamadı',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        ]),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final m = _results[index];
        final plaintext = m['plaintext']?.toString() ?? '';
        final convId = m['conversation_id']?.toString() ?? '';
        final convName = _getConversationName(convId);
        final isGroup = m['_source'] == 'group';
        final createdAt = m['created_at']?.toString() ?? '';
        DateTime? dt;
        try { dt = DateTime.parse(createdAt).toLocal(); } catch (_) {}
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Icon(isGroup ? Icons.group_rounded : Icons.person_rounded,
                color: theme.colorScheme.primary, size: 20),
          ),
          title: Text(convName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: _HighlightText(text: plaintext, query: _controller.text),
          trailing: dt != null
              ? Text('${dt.day}/${dt.month}\n${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))
              : null,
          onTap: () { if (convId.isNotEmpty) context.push('/app/messages/$convId'); },
        );
      },
    );
  }
}

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  const _HighlightText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13);
    if (query.isEmpty) return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    final idx = text.toLowerCase().indexOf(query.toLowerCase());
    if (idx < 0) return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: base, children: [
        TextSpan(text: text.substring(0, idx)),
        TextSpan(text: text.substring(idx, idx + query.length),
            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1))),
        TextSpan(text: text.substring(idx + query.length)),
      ]),
    );
  }
}
