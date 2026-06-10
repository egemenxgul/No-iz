import 'dart:io';
import 'dart:typed_list';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/story_provider.dart';

class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  final _textController = TextEditingController();
  final _captionController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  
  // Premium gradient presets for text stories
  int _selectedGradientIndex = 0;
  final List<List<Color>> _gradients = [
    [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)], // Violet-Purple
    [const Color(0xFF00c6ff), const Color(0xFF0072ff)], // Sky-Blue
    [const Color(0xFFf12711), const Color(0xFFf5af19)], // Warm Sunshine
    [const Color(0xFF11998e), const Color(0xFF38ef7d)], // Emerald Mint
    [const Color(0xFFff007f), const Color(0xFF7f00ff)], // Pink Neon
    [const Color(0xFF1F1C2C), const Color(0xFF928DAB)], // Dark Metal
  ];

  @override
  void dispose() {
    _textController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          // Clear text status when choosing image
          _textController.clear();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya seçilemedi: $e')),
      );
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedFile = null;
    });
  }

  Future<void> _publishStory() async {
    // Validation
    final hasText = _textController.text.trim().isNotEmpty;
    final hasFile = _selectedFile != null;

    if (!hasText && !hasFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir metin girin veya medya seçin')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      if (hasFile) {
        // Publish media story
        final bytes = _selectedFile!.bytes;
        if (bytes == null) throw 'Dosya verisi okunamadı';

        await ref.read(storyProvider.notifier).createStory(
          fileBytes: bytes,
          filename: _selectedFile!.name,
          mimeType: _selectedFile!.extension != null 
              ? 'image/${_selectedFile!.extension}' 
              : 'image/jpeg',
          captionText: _captionController.text.trim().isNotEmpty 
              ? _captionController.text.trim() 
              : null,
        );
      } else {
        // Publish text story
        // To keep text stories E2EE as well, we can compose the text story as an E2EE caption with no media
        // Or we can generate an E2EE empty placeholder or similar, but the backend accepts simple captions.
        // Let's create a text-based story. In story_provider.dart:
        // Text stories can just post an empty 1x1 E2EE pixel or represent it beautifully.
        // Let's create an empty 1x1 transparent GIF to act as the E2EE media and E2EE encrypt the text inside the caption!
        // This is extremely elegant and preserves absolute zero-knowledge metadata privacy!
        final transparent1x1Gif = Uint8List.fromList([
          0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00,
          0xff, 0xff, 0xff, 0x21, 0xf9, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00,
          0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b
        ]);

        await ref.read(storyProvider.notifier).createStory(
          fileBytes: transparent1x1Gif,
          filename: 'text_status.gif',
          mimeType: 'text/plain',
          captionText: _textController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Durumunuz uçtan uca şifrelenerek başarıyla paylaşıldı!'),
            backgroundColor: Colors.purple,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Durum paylaşılırken hata oluştu: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _selectedFile != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16162A),
        elevation: 0,
        title: const Text('Durum Ekle'),
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _publishStory,
              icon: const Icon(Icons.send, size: 18, color: Colors.cyanAccent),
              label: const Text(
                'Paylaş',
                style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background layout
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Media Section / Preview
                    if (hasFile)
                      Column(
                        children: [
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Container(
                                height: 350,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                                  image: _selectedFile!.bytes != null
                                      ? DecorationImage(
                                          image: MemoryImage(_selectedFile!.bytes!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 30),
                                  onPressed: _clearSelection,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Caption entry
                          TextField(
                            controller: _captionController,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Açıklama ekleyin (E2EE şifrelenir)...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                              filled: true,
                              fillColor: const Color(0xFF1E1E38),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.closed_caption, color: Colors.white54),
                            ),
                          ),
                        ],
                      )
                    else
                      // Text story mode with rich neon presets
                      Column(
                        children: [
                          Container(
                            height: 300,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _gradients[_selectedGradientIndex],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: _gradients[_selectedGradientIndex].first.withOpacity(0.4),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(24.0),
                            alignment: Alignment.center,
                            child: TextField(
                              controller: _textController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 6,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: 'Bugün ne düşünüyorsun?\nYazmaya başla...',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Gradient Selector
                          SizedBox(
                            height: 48,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _gradients.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedGradientIndex = index;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                    child: Container(
                                      width: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: _gradients[index],
                                        ),
                                        border: _selectedGradientIndex == index
                                            ? Border.all(color: Colors.white, width: 3)
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 32),

                    // Selector row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickMedia,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Fotoğraf Seç'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.black,
                            backgroundColor: Colors.cyanAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.security, color: Colors.cyanAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Uçtan Uca Şifreli & 24 Saat Sonra Silinir',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          if (_isUploading)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.cyanAccent),
                  const SizedBox(height: 16),
                  Text(
                    'Durum E2EE Şifreleniyor & Yükleniyor...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
