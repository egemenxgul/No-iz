import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';
import 'package:iz_mobile/features/auth/providers/auth_provider.dart';
import 'auth_widgets.dart';

class ExportDataDialog extends ConsumerStatefulWidget {
  const ExportDataDialog({super.key});

  @override
  ConsumerState<ExportDataDialog> createState() => _ExportDataDialogState();
}

class _ExportDataDialogState extends ConsumerState<ExportDataDialog> {
  bool _isLoading = true;
  String? _error;
  String? _dataSummary;

  @override
  void initState() {
    super.initState();
    _exportData();
  }

  Future<void> _exportData() async {
    try {
      final data = await ref.read(authServiceProvider).exportData();
      const encoder = JsonEncoder.withIndent('  ');
      final prettyString = encoder.convert(data);
      
      setState(() {
        _dataSummary = prettyString;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgElevated.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Verilerimi İndir (GDPR)",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const CircularProgressIndicator(color: AppColors.accentLight)
                else if (_dataSummary != null)
                  Column(
                    children: [
                      Text(
                        "İşte sistemdeki kişisel verilerinizin bir özeti:",
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 200,
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.glassMedium,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            _dataSummary!,
                            style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      IzButton(
                        label: "Kapat",
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  )
                else if (_error != null)
                  Column(
                    children: [
                      Text(_error!, style: GoogleFonts.inter(color: AppColors.danger)),
                      const SizedBox(height: 16),
                      IzButton(
                        label: "Kapat",
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
