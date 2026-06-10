import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/story_model.dart';
import '../../providers/story_provider.dart';
import '../../../messages/providers/media_upload_service.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  final FriendStoryFeedModel feedItem;

  const StoryViewerScreen({
    super.key,
    required this.feedItem,
  });

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  int _currentIndex = 0;
  double _progress = 0.0;
  Timer? _timer;
  bool _isLoading = true;
  String? _error;
  Uint8List? _decryptedBytes;
  String? _decryptedCaption;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _loadStoryMedia();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadStoryMedia() async {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _decryptedBytes = null;
        _decryptedCaption = null;
        _progress = 0.0;
      });
    }

    final story = widget.feedItem.stories[_currentIndex];

    try {
      // 1. Fetch E2EE key from SQLite story_keys
      final mediaKey = await ref.read(storyProvider.notifier).getCachedStoryKey(story.id);
      
      if (mediaKey == null) {
        throw 'Bu duruma ait şifreleme anahtarı yerel cihazda bulunamadı.';
      }

      // 2. Decrypt caption if present
      if (story.caption != null && story.caption!.isNotEmpty) {
        _decryptedCaption = await ref.read(storyProvider.notifier).decryptCaption(
          story.caption,
          mediaKey,
        );
      }

      // 3. If image/video story, download and decrypt the media bytes
      if (story.mediaType == 'image' || story.mediaType == 'video') {
        final uploadSvc = ref.read(mediaUploadServiceProvider);
        _decryptedBytes = await uploadSvc.downloadAndDecryptMedia(
          mediaUrl: story.mediaUrl,
          mediaKeyBase64: mediaKey,
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    const duration = Duration(milliseconds: 50);
    final totalSteps = 100; // 5 seconds total (50ms * 100)
    var step = 0;

    _timer = Timer.periodic(duration, (timer) {
      if (_isPaused) return;

      step++;
      if (mounted) {
        setState(() {
          _progress = step / totalSteps;
        });
      }

      if (step >= totalSteps) {
        timer.cancel();
        _nextStory();
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.feedItem.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadStoryMedia();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadStoryMedia();
    } else {
      // Re-run first story
      _loadStoryMedia();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.feedItem.stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 100) {
            Navigator.pop(context);
          }
        },
        onLongPressStart: (_) {
          setState(() {
            _isPaused = true;
          });
        },
        onLongPressEnd: (_) {
          setState(() {
            _isPaused = false;
          });
        },
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width * 0.3) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Black background fallback
            Container(color: Colors.black),

            // Decrypted Content Render
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.cyanAccent)
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock, size: 64, color: Colors.purpleAccent),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : _decryptedBytes != null
                          ? Image.memory(
                              _decryptedBytes!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Container(
                              color: const Color(0xFF1E1E38),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                _decryptedCaption ?? '[Metin Durumu]',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
            ),

            // Top Status Overlay (Name, avatar, segments progress-bars)
            SafeArea(
              child: Column(
                children: [
                  // Progress segments at the very top
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Row(
                      children: List.generate(
                        widget.feedItem.stories.length,
                        (index) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: LinearProgressIndicator(
                              value: index < _currentIndex
                                  ? 1.0
                                  : index == _currentIndex
                                      ? _progress
                                      : 0.0,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                              minHeight: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Avatar, Username and timestamp
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                          child: Text(
                            widget.feedItem.displayName.isNotEmpty
                                ? widget.feedItem.displayName.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.feedItem.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Uçtan Uca Şifreli',
                                style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Caption Render (Only if there is media and caption)
            if (!_isLoading && _error == null && _decryptedBytes != null && _decryptedCaption != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.black.withOpacity(0.0),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 48, top: 40),
                  child: Text(
                    _decryptedCaption!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 4),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
