import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:iz_mobile/core/theme/app_theme.dart';
import 'package:iz_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:iz_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:iz_mobile/features/messages/presentation/screens/conversation_list_screen.dart';
import 'package:iz_mobile/features/messages/presentation/screens/chat_screen.dart';
import 'package:iz_mobile/features/messages/presentation/screens/settings_screen.dart';
import 'package:iz_mobile/features/messages/presentation/screens/user_search_screen.dart';
import 'package:iz_mobile/features/messages/presentation/screens/profile_detail_screen.dart';
import 'package:iz_mobile/features/messages/presentation/screens/privacy_settings_screen.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'package:iz_mobile/core/network/notification_service.dart';
import 'package:iz_mobile/features/call/presentation/widgets/call_overlay.dart';
import 'package:iz_mobile/features/social/presentation/screens/friends_screen.dart';
import 'package:iz_mobile/features/messages/presentation/screens/create_group_screen.dart';
import 'package:iz_mobile/features/messages/presentation/screens/group_settings_screen.dart';
import 'package:iz_mobile/features/community/presentation/screens/community_list_screen.dart';
import 'package:iz_mobile/features/community/presentation/screens/create_community_screen.dart';
import 'package:iz_mobile/features/community/presentation/screens/community_detail_screen.dart';
import 'package:iz_mobile/features/notification/presentation/screens/notification_list_screen.dart';

import 'package:iz_mobile/features/auth/presentation/screens/qr_scanner_screen.dart';
import 'package:iz_mobile/features/story/presentation/screens/story_list_screen.dart';
import 'package:iz_mobile/features/story/presentation/screens/story_viewer_screen.dart';
import 'package:iz_mobile/features/story/presentation/screens/create_story_screen.dart';
import 'package:iz_mobile/features/story/models/story_model.dart';
import 'package:iz_mobile/features/backup/presentation/screens/backup_screen.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:iz_mobile/core/services/callkit_service.dart';

void main() async {
  // Required before any async work in main().
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (needed by both foreground and background isolates).
  // Note: Replace the placeholder config files with real ones before production.
  try {
    await Firebase.initializeApp();
    // Register the background message handler BEFORE runApp().
    // Must be a top-level function — see notification_service.dart.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    // Firebase not configured yet (missing google-services.json).
    // The app works without FCM; push notifications will be unavailable.
    debugPrint('[FCM] Firebase init skipped: $e');
  }

  runApp(
    const ProviderScope(
      child: IzApp(),
    ),
  );

  // UX-8: Listen to CallKit accept/decline events from native UI
  FlutterCallkitIncoming.onEvent.listen((event) {
    if (event == null) return;
    switch (event.event) {
      case Event.actionCallDecline:
      case Event.actionCallEnded:
        // CallKit dismiss — end call if still active
        CallKitService().endAllCalls();
        break;
      default:
        break;
    }
  });
}

// Global navigator key for secure and direct routing (e.g. forced logouts)
final rootNavigatorKey = GlobalKey<NavigatorState>();

// Reactive Router Configuration using Riverpod
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      if (!authState.isInitialized) {
        return null;
      }
      final isAuthenticated = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final isAddingAccount = state.uri.queryParameters['adding'] == 'true';

      if (!isAuthenticated) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn && !isAddingAccount) {
        return '/app';
      }

      if (state.matchedLocation == '/') {
        return '/app';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const UserSearchScreen(),
      ),
      GoRoute(
        path: '/social',
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        path: '/communities',
        builder: (context, state) => const CommunityListScreen(),
      ),
      GoRoute(
        path: '/communities/create',
        builder: (context, state) => const CreateCommunityScreen(),
      ),
      GoRoute(
        path: '/communities/detail/:slug',
        builder: (context, state) => CommunityDetailScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/profile',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          return ProfileDetailScreen(accountId: id);
        },
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (context, state) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path: '/qr-scanner',
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationListScreen(),
      ),
      GoRoute(
        path: '/stories',
        builder: (context, state) => const StoryListScreen(),
      ),
      GoRoute(
        path: '/stories/create',
        builder: (context, state) => const CreateStoryScreen(),
      ),
      GoRoute(
        path: '/stories/view',
        builder: (context, state) {
          final feedItem = state.extra as FriendStoryFeedModel;
          return StoryViewerScreen(feedItem: feedItem);
        },
      ),
      GoRoute(
        path: '/backup',
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) => const ConversationListScreen(),
        routes: [
          GoRoute(
            path: 'messages/:id',
            builder: (context, state) => ChatScreen(
              otherUserId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'groups/create',
            builder: (context, state) => const CreateGroupScreen(),
          ),
          GoRoute(
            path: 'groups/:id/settings',
            builder: (context, state) => GroupSettingsScreen(
              groupId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  );
});

class IzApp extends ConsumerWidget {
  const IzApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final authState = ref.watch(authProvider);

    if (authState.isAuthenticated) {
      Future.microtask(() {
        final svc = ref.read(notificationServiceProvider);
        // Wire the deep link callback so FCM tap events route to the right chat.
        svc.setDeepLinkCallback((route) => router.go(route));
        svc.init();
      });
    }

    return MaterialApp.router(
      title: 'iz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const CallOverlay(),
          ],
        );
      },
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          'iz $title Screen',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
