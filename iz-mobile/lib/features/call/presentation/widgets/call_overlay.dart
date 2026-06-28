import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../providers/call_provider.dart';
import '../../models/call_session.dart';
import '../screens/ringing_screen.dart';
import '../screens/call_screen.dart';

class CallOverlay extends ConsumerWidget {
  const CallOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(callProvider);

    if (session == null) {
      return const SizedBox.shrink();
    }

    // If the call is minimized and active/dialing, show the floating PiP window
    if (session.isMinimized && (session.status == CallStatus.active || session.status == CallStatus.dialing)) {
      return MinimizedCallWidget(session: session);
    }

    // Capture the overlay so it intercepts touches and renders full screen
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: _buildCallUI(session),
      ),
    );
  }

  Widget _buildCallUI(CallSession session) {
    switch (session.status) {
      case CallStatus.ringing:
        return RingingScreen(session: session);
      case CallStatus.dialing:
      case CallStatus.active:
        return CallScreen(session: session);
      case CallStatus.ended:
      case CallStatus.idle:
        return const SizedBox.shrink();
    }
  }
}

class MinimizedCallWidget extends ConsumerStatefulWidget {
  final CallSession session;
  const MinimizedCallWidget({super.key, required this.session});

  @override
  ConsumerState<MinimizedCallWidget> createState() => _MinimizedCallWidgetState();
}

class _MinimizedCallWidgetState extends ConsumerState<MinimizedCallWidget> with SingleTickerProviderStateMixin {
  double _xOffset = 20.0;
  double _yOffset = 100.0;
  bool _isDragging = false;
  
  late AnimationController _appearController;

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 350)
    )..forward();
  }

  @override
  void dispose() {
    _appearController.dispose();
    super.dispose();
  }

  void _snapToEdge() {
    final size = MediaQuery.of(context).size;
    setState(() {
      _isDragging = false;
      // Snap to closest edge
      if (_xOffset < size.width / 2 - 70) {
        _xOffset = 20.0;
      } else {
        _xOffset = size.width - 160.0;
      }
      
      // Keep within vertical bounds
      if (_yOffset < 100) _yOffset = 100;
      if (_yOffset > size.height - 250) _yOffset = size.height - 250;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.session.type == CallType.video;
    final isCameraOff = widget.session.isCameraOff;
    final webrtc = ref.watch(webrtcServiceProvider);

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      right: _xOffset,
      bottom: _yOffset,
      width: 140,
      height: 200,
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: _appearController,
          curve: Curves.easeOutBack,
        ),
        child: GestureDetector(
          onPanStart: (_) {
            setState(() => _isDragging = true);
          },
          onPanUpdate: (details) {
            setState(() {
              _xOffset -= details.delta.dx;
              _yOffset -= details.delta.dy;
            });
          },
          onPanEnd: (_) => _snapToEdge(),
          onPanCancel: () => _snapToEdge(),
          onTap: () {
            ref.read(callProvider.notifier).toggleMinimize();
          },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Video / Avatar background
              if (isVideo && !isCameraOff)
                Positioned.fill(
                  child: RTCVideoView(
                    webrtc.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF020617)],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Center(
                          child: Text(
                            widget.session.peerName.isNotEmpty ? widget.session.peerName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Frosted Glass Header Label
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.session.peerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // Control Overlays (Maximize/Hangup)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Hangup Icon Button
                    GestureDetector(
                      onTap: () {
                        ref.read(callProvider.notifier).endCall();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 16),
                      ),
                    ),
                    // Maximize Icon Button
                    GestureDetector(
                      onTap: () {
                        ref.read(callProvider.notifier).toggleMinimize();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
