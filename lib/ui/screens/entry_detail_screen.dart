import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/vault_entry.dart';
import '../../providers/vault_provider.dart';
import '../../services/clipboard_service.dart';
import 'entry_edit_screen.dart';

class EntryDetailScreen extends StatefulWidget {
  final VaultEntry entry;
  final VaultProvider vaultProvider;

  const EntryDetailScreen({
    super.key,
    required this.entry,
    required this.vaultProvider,
  });

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  late VaultEntry _currentEntry;
  bool _revealPassword = false;
  Timer? _hideTimer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _currentEntry = widget.entry;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _toggleRevealPassword() {
    if (_revealPassword) {
      _hideTimer?.cancel();
      setState(() {
        _revealPassword = false;
        _secondsRemaining = 0;
      });
    } else {
      setState(() {
        _revealPassword = true;
        _secondsRemaining = 15;
      });
      _hideTimer?.cancel();
      _hideTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_secondsRemaining <= 1) {
          t.cancel();
          if (mounted) {
            setState(() {
              _revealPassword = false;
              _secondsRemaining = 0;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _secondsRemaining--;
            });
          }
        }
      });
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Registro'),
        content: Text('Deseja realmente excluir "${_currentEntry.title}"? Esta ação removerá o registro do cofre.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.vaultProvider.deleteEntry(_currentEntry.uid);
      if (mounted) Navigator.pop(context);
    }
  }

  void _handleEdit() async {
    final updated = await Navigator.push<VaultEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditScreen(
          vaultProvider: widget.vaultProvider,
          entry: _currentEntry,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _currentEntry = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentEntry.title),
        actions: [
          IconButton(
            icon: Icon(
              _currentEntry.favorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _currentEntry.favorite ? AppColors.warning : AppColors.textMain,
            ),
            onPressed: () async {
              await widget.vaultProvider.toggleFavorite(_currentEntry);
              setState(() {
                _currentEntry = _currentEntry.copyWith(favorite: !_currentEntry.favorite);
              });
            },
          ),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _handleEdit),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: _handleDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Usuário
            if (_currentEntry.username.isNotEmpty)
              _buildDetailTile(
                title: 'Usuário / Email',
                value: _currentEntry.username,
                icon: Icons.person_outline,
                onCopy: () => _copy(_currentEntry.username, 'Usuário copiado!'),
              ),

            // Senha
            if (_currentEntry.password.isNotEmpty)
              _buildPasswordTile(),

            // URL
            if (_currentEntry.url.isNotEmpty)
              _buildDetailTile(
                title: 'Endereço / URL',
                value: _currentEntry.url,
                icon: Icons.link,
                onCopy: () => _copy(_currentEntry.url, 'URL copiada!'),
              ),

            // Categoria
            if (_currentEntry.category.isNotEmpty)
              _buildDetailTile(
                title: 'Categoria',
                value: _currentEntry.category,
                icon: Icons.folder_outlined,
              ),

            // Notas
            if (_currentEntry.notes.isNotEmpty)
              _buildDetailTile(
                title: 'Notas e Anotações',
                value: _currentEntry.notes,
                icon: Icons.notes_outlined,
                onCopy: () => _copy(_currentEntry.notes, 'Notas copiadas!'),
              ),

            const SizedBox(height: 20),
            const Divider(color: AppColors.darkBorder),
            const SizedBox(height: 10),

            // Metadados
            Text(
              'Revisão: ${_currentEntry.rev} · Atualizado em: ${_currentEntry.updatedAt.substring(0, 16).replaceAll("T", " ")}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSubtle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onCopy,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSubtle),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const Spacer(),
              if (onCopy != null)
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.copy_rounded, color: AppColors.accent),
                  onPressed: onCopy,
                ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 15, color: AppColors.textMain, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.key_outlined, size: 16, color: AppColors.textSubtle),
              const SizedBox(width: 8),
              const Text('Senha', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              if (_revealPassword && _secondsRemaining > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${_secondsRemaining}s', style: const TextStyle(fontSize: 11, color: AppColors.warning)),
                ),
              ],
              const Spacer(),
              IconButton(
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(_revealPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSubtle),
                onPressed: _toggleRevealPassword,
              ),
              const SizedBox(width: 14),
              IconButton(
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.copy_rounded, color: AppColors.accent),
                onPressed: () => _copy(_currentEntry.password, 'Senha copiada! (Limpa em 30s)'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            _revealPassword ? _currentEntry.password : '••••••••••••••••',
            style: TextStyle(
              fontSize: 16,
              letterSpacing: _revealPassword ? 0.5 : 2.0,
              fontFamily: _revealPassword ? 'monospace' : null,
              color: AppColors.textMain,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _copy(String text, String message) {
    ClipboardService.copySecure(text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}
