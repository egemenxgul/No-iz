import re

filepath = "/root/No-iz/iz-mobile/lib/features/messages/presentation/screens/conversation_list_screen.dart"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Remove _buildShortcutStrip(context),
content = content.replace("                        _buildShortcutStrip(context),", "")

# 2. Remove the _buildShortcutStrip function entirely.
match = re.search(r"  Widget _buildShortcutStrip\(BuildContext context\) \{.*?\n  \}\n", content, re.DOTALL)
if match:
    content = content[:match.start()] + content[match.end():]
else:
    print("Could not find _buildShortcutStrip function")

# 3. Add Archive tile
archive_tile = """
                        if (_selectedTab == 0) // Only in 'Tümü'
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: GestureDetector(
                                onTap: () => context.push('/archived'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgHover,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.archive_outlined, color: AppColors.textSecondary, size: 22),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Arşivlenmiş Sohbetler',
                                        style: GoogleFonts.inter(
                                          color: AppColors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
"""
# insert before SliverPadding
content = content.replace("                          SliverPadding(\n                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),", archive_tile + "                          SliverPadding(\n                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),")

# 4. Modify _LiquidAppBarDelegate action buttons
action_buttons_start = """                  // Action buttons
                  Row(
                    children: [
                      LiquidIconButton(
                        icon: Icons.explore_outlined,
                        onTap: () => context.push('/communities'),
                      ),
                      const SizedBox(width: 8),
                      LiquidIconButton(
                        icon: Icons.people_outline_rounded,
                        onTap: () => context.push('/social'),
                      ),
                      const SizedBox(width: 8),"""

action_buttons_replacement = """                  // Action buttons
                  Row(
                    children: [
                      LiquidIconButton(
                        icon: Icons.qr_code_scanner_rounded,
                        onTap: () => context.push('/qr-scanner'),
                      ),
                      const SizedBox(width: 8),"""

content = content.replace(action_buttons_start, action_buttons_replacement)

settings_button = """                      const SizedBox(width: 8),
                      LiquidIconButton(
                        icon: Icons.settings_outlined,
                        onTap: () => context.push('/settings'),
                      ),"""
content = content.replace(settings_button, "")

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)

print("Conversation list screen updated successfully")
