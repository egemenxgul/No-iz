import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CloudSyncBanner extends StatelessWidget {
  const CloudSyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.redAccent.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bulut kotanız aşıldı! Eşzamanlama duraklatıldı. Yerel cihaz hafızası üzerinden mesajlaşıyorsunuz.',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  // Navigate to media management
                },
                child: const Text('Alanı Yönet', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  context.push('/economy');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.redAccent.shade700,
                  minimumSize: const Size(80, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Yükselt', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }
}
