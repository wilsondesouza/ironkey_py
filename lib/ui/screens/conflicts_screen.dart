import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/sync_conflict.dart';
import '../../providers/vault_provider.dart';
import '../../services/storage_service.dart';

class ConflictsScreen extends StatefulWidget {
  final VaultProvider vaultProvider;

  const ConflictsScreen({super.key, required this.vaultProvider});

  @override
  State<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState extends State<ConflictsScreen> {
  List<SyncConflict> _conflicts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConflicts();
  }

  Future<void> _loadConflicts() async {
    setState(() => _isLoading = true);
    final list = await StorageService.listPendingConflicts();
    setState(() {
      _conflicts = list;
      _isLoading = false;
    });
  }

  Future<void> _resolveAll() async {
    await StorageService.resolveAllConflicts();
    await widget.vaultProvider.checkPendingConflicts();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conflitos de Sincronização'),
        actions: [
          if (_conflicts.isNotEmpty)
            TextButton(
              onPressed: _resolveAll,
              child: const Text('Marcar Resolvidos', style: TextStyle(color: AppColors.accent)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conflicts.isEmpty
              ? const Center(
                  child: Text('Nenhum conflito pendente.', style: TextStyle(color: AppColors.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _conflicts.length,
                  itemBuilder: (context, idx) {
                    final c = _conflicts[idx];
                    final detail = c.detail;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.compare_arrows, color: AppColors.warning),
                                SizedBox(width: 8),
                                Text(
                                  'Edição Concorrente Detectada',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Versão preservada: ${detail["preserved_title"] ?? "Cópia de conflito"}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Detectado em: ${c.createdAt.substring(0, 16).replaceAll("T", " ")}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSubtle),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
