import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/alert.dart';

/// BioGuard — Alert Banner
/// Glassmorphic banner that pops in when a new alert arrives and
/// auto-dismisses after a few seconds.
class AlertBanner extends StatefulWidget {
  final Alert alert;
  final VoidCallback? onDismiss;

  const AlertBanner({super.key, required this.alert, this.onDismiss});

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(const Duration(seconds: 5), () {
      widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = widget.alert.severity == 'critical';
    final color = isCritical ? Colors.redAccent : Colors.orangeAccent;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Icon(
                    isCritical
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
                    color: color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.alert.deviceId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.alert.message,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: widget.onDismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
