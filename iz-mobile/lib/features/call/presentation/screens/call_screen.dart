import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../providers/call_provider.dart';
import '../../models/call_session.dart';
import '../../../messages/providers/chat_provider.dart';
import '../../../messages/providers/message_model.dart';
import '../../../../core/network/webrtc_service.dart';
import '../../../../core/localization/locale_provider.dart';

import 'package:iz_mobile/core/theme/glass_widgets.dart';
class CallScreen extends ConsumerStatefulWidget {
  final CallSession session;

  const CallScreen({super.key, required this.session});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> with SingleTickerProviderStateMixin {
  // Draggable coordinate states for picture-in-picture local video preview
  double _localX = 20.0;
  double _localY = 120.0;
  bool _isDragging = false;

  late AnimationController _soundWaveController;

  @override
  void initState() {
    super.initState();
    _soundWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _soundWaveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(callProvider) ?? widget.session;
    final isVideo = session.type == CallType.video;
    final isDialing = session.status == CallStatus.dialing;
    final isMuted = session.isMuted;
    final isCameraOff = session.isCameraOff;
    final isSpeakerOn = session.isSpeakerOn;

    final webrtc = ref.watch(webrtcServiceProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── BACKGROUND & REMOTE STREAM GRID LAYER ─────────────────────────
          if (session.isGroup) ...[
            // Premium background for group calls
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [
                      Color(0xFF1E293B), // Charcoal Slate
                      Color(0xFF020617), // Near Black
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: _buildGroupGrid(session, webrtc),
            ),
          ] else if (isVideo && !isCameraOff && !isDialing) ...[
            // Fullscreen remote video feed (1-1 Call)
            Positioned.fill(
              child: RTCVideoView(
                webrtc.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ] else ...[
            // Rich frosted background for voice-only call or when camera is toggled off (1-1 Call)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [
                      Color(0xFF1E293B), // Charcoal Slate
                      Color(0xFF020617), // Near Black
                    ],
                  ),
                ),
                child: AppBackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],

          // ─── PEER IDENTIFICATION HEADER ────────────────────────────────────
          Positioned(
            top: 60.0,
            left: 24.0,
            right: 24.0,
            child: SafeArea(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Frosted WhatsApp-style minimize chevron button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        ref.read(callProvider.notifier).toggleMinimize();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        session.peerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isDialing
                              ? context.tr(ref, 'dialing')
                              : isVideo
                                  ? (session.isGroup ? context.tr(ref, 'group_video_call') : context.tr(ref, 'video_call_started'))
                                  : (session.isGroup ? context.tr(ref, 'group_voice_call') : context.tr(ref, 'voice_call_started')),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── AUDIO CALL DYNAMIC WAVE VISUALIZATION (1-1 ONLY) ──────────────
          if (!session.isGroup && (!isVideo || isCameraOff || isDialing)) ...[
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile Avatar Placeholder
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3B82F6), Color(0xFF4338CA)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 2,
                        )
                      ],
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        session.peerName.isNotEmpty ? session.peerName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Premium Animated Sound Wave Bars
                  if (!isDialing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return AnimatedBuilder(
                          animation: _soundWaveController,
                          builder: (context, child) {
                            // Creates offset heights for different bars to look natural
                            double factor = 0.3 + (index * 0.15);
                            double waveVal = _soundWaveController.value * factor;
                            if (waveVal > 1.0) waveVal = 1.0;
                            double h = 10 + (waveVal * 45);

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: h,
                              decoration: BoxDecoration(
                                color: const Color(0xFF60A5FA).withValues(alpha: 0.85 - (index * 0.08)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                ],
              ),
            ),
          ],

          // ─── DRAGGABLE LOCAL CAMERA PREVIEW (VIDEO ONLY) ───────────────────
          if (isVideo && !isCameraOff && !isDialing)
            LayoutBuilder(
              builder: (context, constraints) {
                // Ensure boundaries so picture-in-picture isn't dragged out of screen
                final double maxX = constraints.maxWidth - 120.0 - 20.0;
                final double maxY = constraints.maxHeight - 160.0 - 100.0;

                // Adjust positions inside screen area on orientation/resizes
                if (!_isDragging) {
                  if (_localX < 20.0) _localX = 20.0;
                  if (_localX > maxX) _localX = maxX;
                  if (_localY < 120.0) _localY = 120.0;
                  if (_localY > maxY) _localY = maxY;
                }

                return Positioned(
                  left: _localX,
                  top: _localY,
                  child: GestureDetector(
                    onPanStart: (_) => _isDragging = true,
                    onPanUpdate: (details) {
                      setState(() {
                        _localX += details.delta.dx;
                        _localY += details.delta.dy;

                        // Lock boundaries
                        if (_localX < 20.0) _localX = 20.0;
                        if (_localX > maxX) _localX = maxX;
                        if (_localY < 120.0) _localY = 120.0;
                        if (_localY > maxY) _localY = maxY;
                      });
                    },
                    onPanEnd: (_) => _isDragging = false,
                    child: Container(
                      width: 120,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black.withValues(alpha: 0.8),
                        border: Border.all(color: Colors.white24, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: Offset(0, 4),
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: RTCVideoView(
                        webrtc.localRenderer,
                        mirror: true,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                );
              },
            ),

          // ─── GLASSMORPHIC FLOATING CONTROLS PANEL ──────────────────────────
          Positioned(
            bottom: 50.0,
            left: 24.0,
            right: 24.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: AppBackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute Audio Toggle
                      _buildControlButton(
                        icon: isMuted ? Icons.mic_off : Icons.mic,
                        color: isMuted ? Colors.white24 : Colors.white10,
                        iconColor: isMuted ? const Color(0xFFF87171) : Colors.white.withValues(alpha: 0.87),
                        onPressed: () {
                          ref.read(callProvider.notifier).toggleMute();
                        },
                      ),

                      // Mute Video/Camera Toggle (Only accessible for video calls)
                      if (isVideo)
                        _buildControlButton(
                          icon: isCameraOff ? Icons.videocam_off : Icons.videocam,
                          color: isCameraOff ? Colors.white24 : Colors.white10,
                          iconColor: isCameraOff ? const Color(0xFFF87171) : Colors.white.withValues(alpha: 0.87),
                          onPressed: () {
                            ref.read(callProvider.notifier).toggleCamera();
                          },
                        ),

                      // Speakerphone Routing Toggle
                      _buildControlButton(
                        icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                        color: isSpeakerOn ? const Color(0xFF60A5FA).withValues(alpha: 0.2) : Colors.white10,
                        iconColor: isSpeakerOn ? const Color(0xFF60A5FA) : Colors.white.withValues(alpha: 0.87),
                        onPressed: () {
                          ref.read(callProvider.notifier).toggleSpeaker();
                        },
                      ),

                      // Invite/Add Participant (Ad-Hoc promotion / Call expansion)
                      if (session.status == CallStatus.active)
                        _buildControlButton(
                          icon: Icons.person_add_alt_1,
                          color: Colors.white10,
                          iconColor: Colors.white.withValues(alpha: 0.87),
                          onPressed: () {
                            _showInviteBottomSheet(context);
                          },
                        ),

                      // End / Hang Up Button
                      _buildControlButton(
                        icon: Icons.call_end,
                        color: const Color(0xFFEF4444),
                        iconColor: Colors.white,
                        onPressed: () {
                          ref.read(callProvider.notifier).endCall();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 24),
        onPressed: onPressed,
      ),
    );
  }

  // ─── PREMIUM RESPONSIVE GRID FOR GROUP CALLS ──────────────────────────────
  Widget _buildGroupGrid(CallSession session, WebrtcService webrtc) {
    final peers = session.peerNames.keys.toList();
    if (peers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(color: Color(0xFF60A5FA), strokeWidth: 3.5),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr(ref, 'waiting_participants'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 140.0, bottom: 150.0, left: 16.0, right: 16.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: peers.length == 1 ? 1 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: peers.length == 1 ? 0.85 : 0.75,
        ),
        itemCount: peers.length,
        itemBuilder: (context, index) {
          final peerId = peers[index];
          final peerName = session.peerNames[peerId] ?? context.tr(ref, 'contact');
          final hasVideo = session.type == CallType.video;
          final renderer = webrtc.remoteRenderers[peerId];
          final isConnected = renderer != null && renderer.srcObject != null;

          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Stack(
                children: [
                  // Video feed or styled profile avatar card
                  Positioned.fill(
                    child: (hasVideo && isConnected)
                        ? RTCVideoView(
                            renderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: peers.length == 1 ? 90 : 70,
                                    height: peers.length == 1 ? 90 : 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF60A5FA), Color(0xFF4F46E5)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF60A5FA).withValues(alpha: 0.3),
                                          blurRadius: 15,
                                        )
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: peers.length == 1 ? 36 : 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!isConnected && hasVideo) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      context.tr(ref, 'connecting'),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ),

                  // Glassmorphic nameplate tag
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AppBackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          color: Colors.black.withValues(alpha: 0.4),
                          child: Text(
                            peerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── SLIDING GLASSMORPHIC INVITATION DRAWER ───────────────────────────────
  void _showInviteBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: AppBackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
              ),
              child: _InviteSheetContent(
                activeSession: widget.session,
                onInvite: (userId) {
                  ref.read(callProvider.notifier).inviteParticipant(userId);
                  Navigator.pop(context);

                  // Show premium success toast feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      content: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AppBackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF60A5FA)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    context.tr(ref, 'invited_to_call'),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InviteSheetContent extends ConsumerStatefulWidget {
  final CallSession activeSession;
  final Function(String userId) onInvite;

  const _InviteSheetContent({
    required this.activeSession,
    required this.onInvite,
  });

  @override
  ConsumerState<_InviteSheetContent> createState() => _InviteSheetContentState();
}

class _InviteSheetContentState extends ConsumerState<_InviteSheetContent> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationProvider);

    // Extract unique invited contacts from existing conversation lists
    final uniqueUsers = <String, ConversationModel>{};
    for (final c in conversations) {
      if (c.otherUserId.isNotEmpty) {
        uniqueUsers[c.otherUserId] = c;
      }
    }

    // Filter out users who are already in the call
    final invitees = uniqueUsers.values.where((user) {
      final isAlreadyInCall = widget.activeSession.peerNames.containsKey(user.otherUserId) ||
          widget.activeSession.peerId == user.otherUserId;
      if (isAlreadyInCall) return false;

      if (_searchQuery.isEmpty) return true;
      final name = (user.otherDisplayName ?? user.otherUsername).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Drawer Handle Indicator
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(height: 18),

        // Sheet Title
        Text(
          context.tr(ref, 'add_participant_to_call'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),

        // Custom premium glassmorphic Search Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: context.tr(ref, 'search_contact'),
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.6)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // List of filtered invitees
        Expanded(
          child: invitees.isEmpty
              ? Center(
                  child: Text(
                    context.tr(ref, 'contact_not_found'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 15,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: invitees.length,
                  separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                  itemBuilder: (context, index) {
                    final c = invitees[index];
                    final displayName = c.otherDisplayName ?? c.otherUsername;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          // Circular contact badge
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF4F46E5)],
                              ),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Center(
                              child: Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Contact Name Plate
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${c.otherUsername}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Interactive Invite Action Trigger
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF60A5FA).withValues(alpha: 0.15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFF60A5FA), width: 1),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            onPressed: () => widget.onInvite(c.otherUserId),
                            child: const Text(
                              'Davet Et',
                              style: TextStyle(
                                color: Color(0xFF60A5FA),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
