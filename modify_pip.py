import re

filepath = "/root/No-iz/iz-mobile/lib/features/call/presentation/widgets/call_overlay.dart"
with open(filepath, "r", encoding="utf-8") as f:
    content = f.read()

# We need to rewrite _MinimizedCallWidgetState to use AnimatedPositioned and snap to edges
old_state = """class _MinimizedCallWidgetState extends ConsumerState<MinimizedCallWidget> {
  double _xOffset = 20.0;
  double _yOffset = 100.0;

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.session.type == CallType.video;
    final isCameraOff = widget.session.isCameraOff;
    final webrtc = ref.watch(webrtcServiceProvider);

    return Positioned(
      right: _xOffset,
      bottom: _yOffset,
      width: 140,
      height: 200,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _xOffset -= details.delta.dx;
            _yOffset -= details.delta.dy;
          });
        },
        onTap: () {
          ref.read(callProvider.notifier).toggleMinimize();
        },"""

new_state = """class _MinimizedCallWidgetState extends ConsumerState<MinimizedCallWidget> with SingleTickerProviderStateMixin {
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
          },"""

if old_state in content:
    content = content.replace(old_state, new_state)
    print("Replaced _MinimizedCallWidgetState successfully.")
else:
    print("Could not find old state in call_overlay.dart")

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)
