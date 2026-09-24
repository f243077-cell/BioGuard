import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/alert.dart';
import 'glass.dart';

/// BioGuard — Alert Banner
/// Frosted glass banner that pops in when a new alert arrives and
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
    final color = isCritical ? AppColors.danger : AppColors.warning;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              decoration: BoxDecoration(
                // Mostly-opaque graphite so the banner stays legible over
                // busy content, with a wash of the severity color on top.
                color: Color.alphaBlend(
                  color.withValues(alpha: 0.16),
                  AppColors.graphite.withValues(alpha: 0.88),
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.55)),
              ),
              child: Row(
                children: [
                  IconTile(
                    icon: isCritical
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline_rounded,
                    color: color,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.alert.deviceId,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.alert.message,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    tooltip: 'Dismiss',
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
