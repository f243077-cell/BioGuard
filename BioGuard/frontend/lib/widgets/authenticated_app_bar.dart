import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'glass.dart';

/// Frosted app bar with the brand mark, page title and a logout action.
/// Pair with `extendBodyBehindAppBar: true` so content blurs beneath it.
class AuthenticatedAppBar extends ConsumerWidget
    implements PreferredSizeWidget {
  const AuthenticatedAppBar({super.key, required this.title});
  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return AppBar(
      toolbarHeight: kToolbarHeight + 8,
      titleSpacing: canPop ? 0 : 16,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.graphite.withValues(alpha: 0.55),
              border: const Border(
                bottom: BorderSide(color: AppColors.glassBorder),
              ),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          if (!canPop) ...[
            const BrandMark(size: 36),
            const SizedBox(width: 12),
          ],
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BIOGUARD',
                style: TextStyle(
                  color: AppColors.skyMint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Logout',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.glassFill,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.glassBorder),
            ),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ),
      ],
    );
  }
}
