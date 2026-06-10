import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class IzTextField extends StatefulWidget {
  final String label;
  final String hint;
  final bool isPassword;
  final TextEditingController? controller;
  final String? Function(String?)? validator;

  const IzTextField({
    super.key,
    required this.label,
    required this.hint,
    this.isPassword = false,
    this.controller,
    this.validator,
  });

  @override
  State<IzTextField> createState() => _IzTextFieldState();
}

class _IzTextFieldState extends State<IzTextField> {
  bool _obscureText = true;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              widget.label,
              style: GoogleFonts.inter(
                color: _isFocused ? AppColors.accentLight : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.isPassword ? _obscureText : false,
              validator: widget.validator,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.glassMedium,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.danger, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
                ),
                suffixIcon: widget.isPassword
                    ? IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IzButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;

  const IzButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
  });

  @override
  State<IzButton> createState() => _IzButtonState();
}

class _IzButtonState extends State<IzButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => widget.isLoading ? null : _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        if (!widget.isLoading) widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: widget.isLoading
                  ? [AppColors.bgHover, AppColors.bgHover]
                  : widget.isOutlined
                      ? [Colors.transparent, Colors.transparent]
                      : [
                          AppColors.accent,
                          AppColors.accentSecondary,
                        ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: widget.isOutlined ? Border.all(color: AppColors.glassBorder, width: 1.5) : null,
            boxShadow: widget.isLoading || widget.isOutlined
                ? []
                : [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: widget.isOutlined ? AppColors.accent : Colors.white,
                    ),
                  )
                : Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      color: widget.isOutlined ? AppColors.textPrimary : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
