import os
import re

filepath = "/root/No-iz/iz-mobile/lib/main.dart"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

# Add import for app_shell
if "app_shell.dart" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:iz_mobile/features/shell/presentation/screens/app_shell.dart';")

# Replace the router keys and provider
new_keys = """
// Global navigator key for secure and direct routing (e.g. forced logouts)
final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorMessagesKey = GlobalKey<NavigatorState>(debugLabel: 'shellMessages');
final _shellNavigatorCommunitiesKey = GlobalKey<NavigatorState>(debugLabel: 'shellCommunities');
final _shellNavigatorSocialKey = GlobalKey<NavigatorState>(debugLabel: 'shellSocial');
final _shellNavigatorSettingsKey = GlobalKey<NavigatorState>(debugLabel: 'shellSettings');

// Reactive Router Configuration using Riverpod
"""
content = content.replace("// Global navigator key for secure and direct routing (e.g. forced logouts)\nfinal rootNavigatorKey = GlobalKey<NavigatorState>();\n\n// Reactive Router Configuration using Riverpod", new_keys.strip())

# Remove old flat routes for /social, /communities, /settings, /app
# We will use regex to find and remove them, or just replace the whole GoRoute blocks if it's easier.
# It is safer to do string replacements on specific blocks.

social_route = """      GoRoute(
        path: '/social',
        builder: (context, state) => const FriendsScreen(),
      ),"""

communities_route = """      GoRoute(
        path: '/communities',
        builder: (context, state) => const CommunityListScreen(),
      ),"""

settings_route = """      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),"""

content = content.replace(social_route, "")
content = content.replace(communities_route, "")
content = content.replace(settings_route, "")

app_route_start = """      GoRoute(
        path: '/app',
        builder: (context, state) => const ConversationListScreen(),
        routes: ["""

app_route_end = """          ),
        ],
      ),"""

# Let's extract the /app routes block carefully.
match = re.search(r"      GoRoute\(\s*path: '/app',[\s\S]*?builder: \(context, state\) => const ConversationListScreen\(\),\s*routes: \[(.*?)\]\n      \),", content, re.DOTALL)
if match:
    sub_routes = match.group(1)
    content = content[:match.start()] + content[match.end():]
else:
    print("Could not find /app route block")


# Now we construct the StatefulShellRoute
shell_route = f"""      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {{
          return AppShell(navigationShell: navigationShell);
        }},
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorMessagesKey,
            routes: [
              GoRoute(
                path: '/app',
                builder: (context, state) => const ConversationListScreen(),
                routes: [{sub_routes}]
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorCommunitiesKey,
            routes: [
              GoRoute(
                path: '/communities',
                builder: (context, state) => const CommunityListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSocialKey,
            routes: [
              GoRoute(
                path: '/social',
                builder: (context, state) => const FriendsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSettingsKey,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),"""

# Insert shell_route where /social was (or at the end of routes)
# We can just insert it after the backup route
backup_route = """      GoRoute(
        path: '/backup',
        builder: (context, state) => const BackupScreen(),
      ),"""

if backup_route in content:
    content = content.replace(backup_route, backup_route + "\n" + shell_route)
else:
    print("Could not find backup route")

# Wait, the sub routes of /app (like messages/:id) should probably use parentNavigatorKey: rootNavigatorKey to hide the bottom nav bar!
# Let's modify the sub routes string.
sub_routes_mod = sub_routes.replace("builder: (context, state) => ChatScreen(", "parentNavigatorKey: rootNavigatorKey,\n            builder: (context, state) => ChatScreen(")
sub_routes_mod = sub_routes_mod.replace("builder: (context, state) => const CreateGroupScreen(),", "parentNavigatorKey: rootNavigatorKey,\n            builder: (context, state) => const CreateGroupScreen(),")
content = content.replace(sub_routes, sub_routes_mod)

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)

print("Done modifying router")
