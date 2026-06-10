import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/core/localization/locale_provider.dart';
import 'package:iz_mobile/features/messages/providers/chat_provider.dart';
import 'package:iz_mobile/features/messages/providers/contacts_provider.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _globalResults = [];
  bool _isGlobalLoading = false;
  final Set<String> _invitedNumbers = {};

  @override
  void initState() {
    super.initState();
    // Sync local contacts with backend on start
    Future.microtask(() {
      ref.read(contactsProvider.notifier).syncContacts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) async {
    if (query.length < 2) {
      setState(() => _globalResults = []);
      return;
    }

    setState(() => _isGlobalLoading = true);
    try {
      final service = ref.read(messageServiceProvider);
      final users = await service.searchUsers(query);
      setState(() => _globalResults = users);
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() => _isGlobalLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsState = ref.watch(contactsProvider);
    final query = _searchController.text.trim().toLowerCase();

    // Filter local contacts based on search query
    final filteredContacts = contactsState.localContacts.where((c) {
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          c.phoneNumber.contains(query);
    }).toList();

    final activeContacts = filteredContacts.where((c) => c.isActive).toList();
    final inactiveContacts = filteredContacts.where((c) => !c.isActive).toList();

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: Text(
          context.tr(ref, 'select_contact'),
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        backgroundColor: AppColors.bgBase,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Elegant search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: GoogleFonts.inter(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: context.tr(ref, 'global_search'),
                hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                fillColor: AppColors.bgSurface.withValues(alpha: 0.5),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
          ),
          
          if (contactsState.isLoading || _isGlobalLoading)
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                // ─── SECTION 1: Active Contacts on No-iz ──────────────────
                if (activeContacts.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                    child: Text(
                      context.tr(ref, 'phonebook_contacts').toUpperCase(),
                      style: GoogleFonts.inter(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ...activeContacts.map((contact) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.05)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accentDim,
                          foregroundImage: contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty
                              ? NetworkImage(contact.avatarUrl!)
                              : null,
                          child: contact.avatarUrl == null || contact.avatarUrl!.isEmpty
                              ? Text(
                                  contact.name[0].toUpperCase(),
                                  style: GoogleFonts.inter(color: AppColors.accent, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Text(
                          contact.name,
                          style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '@${contact.username}',
                          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'No-iz',
                            style: GoogleFonts.inter(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () {
                          // Tap opens the chat screen directly
                          if (contact.userId != null) {
                            context.pushReplacement('/app/messages/${contact.userId}');
                          }
                        },
                      ),
                    );
                  }),
                ],

                // ─── SECTION 2: Inactive Contacts (Invites) ───────────────
                if (inactiveContacts.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                    child: Text(
                      context.tr(ref, 'invite_friend').toUpperCase(),
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ...inactiveContacts.map((contact) {
                    final isInvited = _invitedNumbers.contains(contact.phoneNumber);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.03)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.bgSurface,
                          child: Text(
                            contact.name[0].toUpperCase(),
                            style: GoogleFonts.inter(color: AppColors.textSecondary),
                          ),
                        ),
                        title: Text(
                          contact.name,
                          style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          contact.phoneNumber,
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
                        ),
                        trailing: TextButton(
                          onPressed: isInvited
                              ? null
                              : () {
                                  setState(() {
                                    _invitedNumbers.add(contact.phoneNumber);
                                  });
                                },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            backgroundColor: isInvited ? Colors.transparent : AppColors.accentDim,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isInvited ? AppColors.border.withValues(alpha: 0.2) : Colors.transparent,
                              ),
                            ),
                          ),
                          child: Text(
                            isInvited ? context.tr(ref, 'invited') : context.tr(ref, 'invite'),
                            style: GoogleFonts.inter(
                              color: isInvited ? AppColors.textMuted : AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],

                // ─── SECTION 3: Global User Search Results ────────────────
                if (query.length >= 2) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                    child: Text(
                      context.tr(ref, 'global_search').toUpperCase(),
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (_globalResults.isEmpty && !_isGlobalLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          context.tr(ref, 'no_contacts_found'),
                          style: GoogleFonts.inter(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ..._globalResults.map((user) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.05)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accentDim,
                          foregroundImage: user['avatar_url'] != null && user['avatar_url'].isNotEmpty
                              ? NetworkImage(user['avatar_url'])
                              : null,
                          child: user['avatar_url'] == null || user['avatar_url'].isEmpty
                              ? Text(
                                  user['username'][0].toUpperCase(),
                                  style: GoogleFonts.inter(color: AppColors.accent, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Text(
                          user['display_name'] ?? user['username'],
                          style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '@${user['username']}',
                          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        onTap: () {
                          context.pushReplacement('/app/messages/${user['id']}');
                        },
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
