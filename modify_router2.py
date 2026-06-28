import re

filepath = "/root/No-iz/iz-mobile/lib/main.dart"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

# Let's remove the flat routes for social, communities, settings.
content = re.sub(
    r"\s*GoRoute\(\s*path: '/social',\s*builder: \(context, state\) => const FriendsScreen\(\),\s*\),",
    "",
    content
)
content = re.sub(
    r"\s*GoRoute\(\s*path: '/communities',\s*builder: \(context, state\) => const CommunityListScreen\(\),\s*\),",
    "",
    content
)
content = re.sub(
    r"\s*GoRoute\(\s*path: '/settings',\s*builder: \(context, state\) => const SettingsScreen\(\),\s*\),",
    "",
    content
)

# Find the /app GoRoute
match = re.search(r"(\s*GoRoute\(\s*path: '/app',\s*builder: \(context, state\) => const ConversationListScreen\(\),\s*routes: \[)(.*?)(\],\s*\),)", content, re.DOTALL)

if match:
    prefix = match.group(1)
    sub_routes = match.group(2)
    suffix = match.group(3)

    # We want to add parentNavigatorKey: rootNavigatorKey to the sub_routes
    sub_routes = sub_routes.replace("builder: (context, state) => ChatScreen(", "parentNavigatorKey: rootNavigatorKey,\n            builder: (context, state) => ChatScreen(")
    sub_routes = sub_routes.replace("builder: (context, state) => const CreateGroupScreen(),", "parentNavigatorKey: rootNavigatorKey,\n            builder: (context, state) => const CreateGroupScreen(),")
    sub_routes = sub_routes.replace("builder: (context, state) => GroupSettingsScreen(", "parentNavigatorKey: rootNavigatorKey,\n            builder: (context, state) => GroupSettingsScreen(")
    sub_routes = sub_routes.replace("builder: (context, state) => const SubscriptionScreen(),", "parentNavigatorKey: rootNavigatorKey,\n            builder: (context, state) => const SubscriptionScreen(),")

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
                routes: [{sub_routes}],
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

    # Replace the old /app route block with the new shell route
    content = content[:match.start()] + "\n" + shell_route + content[match.end():]
    
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)
    print("Successfully replaced /app with shell route")
else:
    print("Could not find /app route")
