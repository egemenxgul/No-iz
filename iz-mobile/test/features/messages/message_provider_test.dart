import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz_mobile/features/messages/providers/chat_provider.dart';
import 'package:iz_mobile/features/messages/providers/message_model.dart';
import 'package:iz_mobile/features/messages/providers/message_repository.dart';
import 'package:iz_mobile/core/network/websocket_provider.dart';
import 'package:iz_mobile/core/network/websocket_service.dart';

class FakeMessageRepository extends Fake implements MessageRepository {
  final List<Message> _messages = [];

  @override
  Future<List<Message>> getMessages(String chatId) async {
    return _messages.where((m) => m.chatId == chatId).toList();
  }

  @override
  Future<void> saveMessage(Message msg) async {
    _messages.add(msg);
  }
}

class FakeWebsocketService extends Fake implements WebsocketService {
  final List<Map<String, dynamic>> sentPayloads = [];

  @override
  void sendMessage(String event, Map<String, dynamic> payload) {
    sentPayloads.add({'event': event, 'payload': payload});
  }
}

void main() {
  group('ChatNotifier Tests', () {
    late ProviderContainer container;
    late FakeMessageRepository fakeRepo;
    late FakeWebsocketService fakeWs;

    setUp(() {
      fakeRepo = FakeMessageRepository();
      fakeWs = FakeWebsocketService();

      container = ProviderContainer(
        overrides: [
          messageRepositoryProvider.overrideWithValue(fakeRepo),
          websocketProvider.overrideWithValue(fakeWs),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is loading', () {
      final state = container.read(chatProvider('chat_1'));
      expect(state.isLoading, isTrue);
      expect(state.messages, isEmpty);
    });

    test('SendMessage saves message and sends via websocket', () async {
      final notifier = container.read(chatProvider('chat_1').notifier);
      
      // We simulate waiting for load
      await Future.delayed(const Duration(milliseconds: 100));

      await notifier.sendMessage('Hello world');

      final state = container.read(chatProvider('chat_1'));
      
      // Should exist in state
      expect(state.messages.length, 1);
      expect(state.messages.first.content, 'Hello world');

      // Should be sent to repo
      final repoMsgs = await fakeRepo.getMessages('chat_1');
      expect(repoMsgs.length, 1);
      expect(repoMsgs.first.content, 'Hello world');

      // Should be sent to WS
      expect(fakeWs.sentPayloads.length, 1);
      expect(fakeWs.sentPayloads.first['event'], 'chat_message');
      expect(fakeWs.sentPayloads.first['payload']['content'], 'Hello world');
    });
  });
}
