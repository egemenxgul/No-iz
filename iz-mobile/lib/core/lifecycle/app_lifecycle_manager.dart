import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/websocket_provider.dart';
import '../../features/messages/providers/chat_provider.dart';

class AppLifecycleManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppLifecycleManager({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends ConsumerState<AppLifecycleManager> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconnect WebSocket instantly
      final wsService = ref.read(webSocketProvider);
      if (wsService != null && !wsService.isConnected) {
        wsService.connect();
      }
      
      // Flush outbound queue just in case
      ref.read(outboundQueueProvider.notifier).flushQueue();
      
      // Load latest conversations
      ref.read(conversationProvider.notifier).loadConversations();
    } else if (state == AppLifecycleState.paused) {
      // Disconnect WebSocket to save battery
      final wsService = ref.read(webSocketProvider);
      if (wsService != null) {
        wsService.disconnect();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
