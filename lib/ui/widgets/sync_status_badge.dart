import 'package:flutter/material.dart';
import '../../core/constants.dart';

class SyncStatusBadge extends StatelessWidget {
  final bool isSyncing;
  final bool hasConflicts;
  final bool isConfigured;
  final VoidCallback onTap;

  const SyncStatusBadge({
    super.key,
    required this.isSyncing,
    required this.hasConflicts,
    required this.isConfigured,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isConfigured) {
      return IconButton(
        icon: const Icon(Icons.cloud_off_outlined, color: AppColors.textSubtle),
        tooltip: 'Sincronização desativada',
        onPressed: onTap,
      );
    }

    if (isSyncing) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
        ),
      );
    }

    if (hasConflicts) {
      return IconButton(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        tooltip: 'Conflitos de sincronização pendentes',
        onPressed: onTap,
      );
    }

    return IconButton(
      icon: const Icon(Icons.cloud_done_outlined, color: AppColors.success),
      tooltip: 'Sincronizado',
      onPressed: onTap,
    );
  }
}
