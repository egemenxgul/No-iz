import re

filepath = "/root/No-iz/iz-mobile/lib/main.dart"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

import_statement = "import 'package:iz_mobile/core/lifecycle/app_lifecycle_manager.dart';"
if import_statement not in content:
    content = content.replace(
        "import 'package:iz_mobile/core/services/callkit_service.dart';",
        "import 'package:iz_mobile/core/services/callkit_service.dart';\n" + import_statement
    )

old_app_build = """    return MaterialApp.router(
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
    );"""

new_app_build = """    return AppLifecycleManager(
      child: MaterialApp.router(
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
      ),
    );"""

if old_app_build in content:
    content = content.replace(old_app_build, new_app_build)
    print("Replaced AppLifecycleManager successfully.")
else:
    print("Could not find old_app_build in main.dart")

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)
