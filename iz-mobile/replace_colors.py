import os

def replace_colors(directory):
    replacements = {
        '0xFF6366F1': '0xFF3B82F6',
        '0xFF818CF8': '0xFF60A5FA',
        '0xFF8B5CF6': '0xFFA855F7',
        '0xFFA5B4FC': '0xFF93C5FD'
    }

    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    changed = False
                    for old, new in replacements.items():
                        if old in content:
                            content = content.replace(old, new)
                            changed = True
                    
                    if changed:
                        with open(filepath, 'w', encoding='utf-8') as f:
                            f.write(content)
                        print(f"Updated {filepath}")
                except Exception as e:
                    print(f"Error reading {filepath}: {e}")

if __name__ == "__main__":
    replace_colors('/root/No-iz/iz-mobile/lib')
