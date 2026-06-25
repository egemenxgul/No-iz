import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/report_service.dart';

class ReportDialog extends ConsumerStatefulWidget {
  final String? reportedUserId;
  final String? reportedCommunityId;

  const ReportDialog({
    super.key,
    this.reportedUserId,
    this.reportedCommunityId,
  });

  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog> {
  final _descriptionController = TextEditingController();
  String _selectedReason = 'Harassment';
  bool _isSubmitting = false;

  final List<Map<String, String>> _reasons = [
    {'value': 'Spam', 'label': 'Spam / İstenmeyen Mesaj'},
    {'value': 'Harassment', 'label': 'Taciz / Rahatsız Etme'},
    {'value': 'Abuse', 'label': 'Kötüye Kullanım / Saldırı'},
    {'value': 'Other', 'label': 'Diğer Nedenler'},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final desc = _descriptionController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen şikayet ayrıntılarını açıklayın')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref.read(reportServiceProvider).submitReport(
        reportedUserId: widget.reportedUserId,
        reportedCommunityId: widget.reportedCommunityId,
        reason: _selectedReason,
        description: desc,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şikayetiniz başarıyla iletildi. Güvenliğiniz bizim için önemlidir.'),
            backgroundColor: Colors.purple,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Şikayet iletilemedi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E1E38).withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
        ),
        title: const Row(
          children: [
            Icon(Icons.report_problem, color: Colors.redAccent),
            SizedBox(width: 12),
            Text(
              'Şikayet Et',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: _isSubmitting
            ? const SizedBox(
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.cyanAccent),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Bu platform üyesini şikayet etme nedeninizi seçin ve ayrıntıları girin.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    
                    // Reason Dropdown Selection
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedReason,
                          dropdownColor: const Color(0xFF1E1E38),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedReason = val;
                              });
                            }
                          },
                          items: _reasons.map((r) {
                            return DropdownMenuItem<String>(
                              value: r['value'],
                              child: Text(r['label']!),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Description Input field
                    TextField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Durumu detaylandırın...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                        filled: true,
                        fillColor: const Color(0xFF0F0F1A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        actions: _isSubmitting
            ? []
            : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Şikayeti Gönder'),
                ),
              ],
      ),
    );
  }
}
