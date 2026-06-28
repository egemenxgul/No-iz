import re

filepath = "/root/No-iz/iz-mobile/lib/features/messages/presentation/screens/chat_screen.dart"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

# Replace _showAttachmentMenu
attachment_menu_old = """  Future<void> _showAttachmentMenu() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: AppBackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgElevated.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Dosya Ekle',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAttachmentOption(
                        icon: Icons.image_rounded,
                        label: 'Galeri',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndSendFile(FileType.image);
                        },
                      ),
                      const SizedBox(width: 24),
                      _buildAttachmentOption(
                        icon: Icons.insert_drive_file_rounded,
                        label: 'Belge',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndSendFile(FileType.any);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }"""

attachment_menu_new = """  Future<void> _showAttachmentMenu() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: AppBackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated.withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border.all(color: AppColors.glassBorder, width: 0.5),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 48), // spacer to balance the switch
                          Text(
                            'Dosya Ekle',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'HD',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _isHDEnabled ? AppColors.accent : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Switch(
                                value: _isHDEnabled,
                                onChanged: (val) {
                                  setModalState(() => _isHDEnabled = val);
                                  setState(() => _isHDEnabled = val);
                                },
                                activeColor: AppColors.accent,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAttachmentOption(
                            icon: Icons.image_rounded,
                            label: 'Galeri',
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _pickAndSendFile(FileType.image);
                            },
                          ),
                          const SizedBox(width: 24),
                          _buildAttachmentOption(
                            icon: Icons.insert_drive_file_rounded,
                            label: 'Belge',
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _pickAndSendFile(FileType.any);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }"""

if attachment_menu_old in content:
    content = content.replace(attachment_menu_old, attachment_menu_new)
    print("Replaced _showAttachmentMenu successfully.")
else:
    print("Could not find _showAttachmentMenu to replace.")


# Replace _pickAndSendFile call to sendMediaMessage
send_media_old = """      await ref.read(chatProvider(widget.otherUserId).notifier).sendMediaMessage(
        fileBytes: fileBytes,
        filename: filename,
        mimeType: mimeType,
        fileSize: fileBytes.length,
      );"""

send_media_new = """      await ref.read(chatProvider(widget.otherUserId).notifier).sendMediaMessage(
        fileBytes: fileBytes,
        filename: filename,
        mimeType: mimeType,
        fileSize: fileBytes.length,
        isHD: _isHDEnabled,
      );"""

if send_media_old in content:
    content = content.replace(send_media_old, send_media_new)
    print("Replaced sendMediaMessage successfully.")
else:
    print("Could not find sendMediaMessage to replace.")

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)
