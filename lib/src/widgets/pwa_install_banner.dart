import 'dart:async';
import 'package:flutter/material.dart';
import 'pwa_helpers.dart';

/// Banner promocional elegante que invita a instalar la PWA para soporte offline y modelos 3D rápidos.
class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  bool _canInstall = false;
  bool _dismissed = false;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _canInstall = PwaHelpers.isPwaInstallAvailable();
    _sub = PwaHelpers.pwaInstallStream.listen((available) {
      if (mounted) {
        setState(() => _canInstall = available);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handleInstall() async {
    final accepted = await PwaHelpers.triggerPwaInstall();
    if (accepted && mounted) {
      setState(() => _canInstall = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canInstall || _dismissed) {
      return const SizedBox.shrink();
    }

    const magenta = Color(0xffd94f87);
    const stroke = Color(0xffe8d0da);
    const textPrimary = Color(0xff49343f);
    const textSecondary = Color(0xff7a5c6b);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xffffffff),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0fd94f87),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x1ad94f87),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.view_in_ar_rounded, color: magenta, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Instala My Love Depot',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Carga tus modelos 3D al instante y sin conexión',
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _handleInstall,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Instalar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: magenta,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => setState(() => _dismissed = true),
            icon: const Icon(Icons.close, size: 18, color: textSecondary),
            tooltip: 'Ocultar',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
