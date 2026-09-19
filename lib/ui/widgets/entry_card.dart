import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/vault_entry.dart';
import '../../services/clipboard_service.dart';

class EntryCard extends StatelessWidget {
  final VaultEntry entry;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const EntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      entry.favorite ? Icons.star_rounded : Icons.star_border_rounded,
                      color: entry.favorite ? AppColors.warning : AppColors.textSubtle,
                    ),
                    onPressed: onToggleFavorite,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (entry.category.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        entry.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (entry.username.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    entry.username,
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (entry.username.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.person_outline, size: 16),
                      label: const Text('Usuário', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        ClipboardService.copySecure(entry.username);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Usuário copiado!'), duration: Duration(seconds: 2)),
                        );
                      },
                    ),
                  if (entry.password.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.key_outlined, size: 16),
                      label: const Text('Senha', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        ClipboardService.copySecure(entry.password);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Senha copiada! (Limpa em 30s)'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
