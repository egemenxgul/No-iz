import os
import re

lib_path = "/root/No-iz/iz-mobile/lib"

def process_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # If it doesn't contain BackdropFilter, skip
    if "BackdropFilter" not in content:
        return

    # Don't replace in glass_widgets.dart
    if "glass_widgets.dart" in filepath:
        return

    # Replace BackdropFilter( with AppBackdropFilter(
    new_content = content.replace("BackdropFilter(", "AppBackdropFilter(")

    if new_content != content:
        # Check if import is needed
        import_str = "import 'package:iz_mobile/core/theme/glass_widgets.dart';"
        if "glass_widgets.dart" not in new_content:
            # find last import and insert after
            imports = list(re.finditer(r"^import\s+.*;\s*$", new_content, re.MULTILINE))
            if imports:
                last_import = imports[-1]
                insert_idx = last_import.end()
                new_content = new_content[:insert_idx] + "\n" + import_str + new_content[insert_idx:]
            else:
                new_content = import_str + "\n\n" + new_content
        
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, dirs, files in os.walk(lib_path):
    for file in files:
        if file.endswith(".dart"):
            process_file(os.path.join(root, file))

print("Done")
