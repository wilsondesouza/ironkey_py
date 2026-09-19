import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../providers/vault_provider.dart';
import '../../services/auto_lock_service.dart';
import 'conflicts_screen.dart';

class SettingsScreen extends StatelessWidget {
  final VaultProvider vaultProvider;

  const SettingsScreen({super.key, required this.vaultProvider});

  String _formatUriDisplay(String uri) {
    if (uri.isEmpty) return '';
    try {
      final decoded = Uri.decodeFull(uri);
      if (decoded.contains('com.google.android.apps.docs')) {
        return 'Google Drive (Nuvem)';
      }
      if (decoded.contains('tree/')) {
        final part = decoded.split('tree/').last;
        if (part.startsWith('primary:')) {
          return 'Armazenamento Principal / ' + part.replaceFirst('primary:', '');
        }
        return part.replaceAll(':', ' / ');
      }
    } catch (_) {}
    return uri;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vaultProvider,
      builder: (context, _) {
        final isSyncConfigured = vaultProvider.syncTreeUri.isNotEmpty;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Seção Sincronização
            _buildSectionHeader('Sincronização em Nuvem'),
            Container(
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
                      Icon(
                        isSyncConfigured ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                        color: isSyncConfigured ? AppColors.success : AppColors.textSubtle,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isSyncConfigured ? 'Sincronização Ativa' : 'Sincronização Não Configurada',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isSyncConfigured
                        ? 'Pasta: ${_formatUriDisplay(vaultProvider.syncTreeUri)}'
                        : 'Selecione a pasta compartilhada com seu provedor de nuvem (Google Drive, Dropbox, Nextcloud, Syncthing).',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: Text(isSyncConfigured ? 'Alterar Pasta' : 'Selecionar Pasta'),
                        onPressed: () => _pickSafFolder(context),
                      ),
                      if (isSyncConfigured) ...[
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.sync, size: 18),
                          label: const Text('Sincronizar'),
                          onPressed: () async {
                            final outcome = await vaultProvider.syncNow();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(outcome.summary())),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Conflitos de Sincronização
            if (vaultProvider.pendingConflictsCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${vaultProvider.pendingConflictsCount} conflito(s) aguardando revisão.',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.warning),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.black),
                      child: const Text('Revisar'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConflictsScreen(vaultProvider: vaultProvider),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Seção Dispositivo
            _buildSectionHeader('Identificação'),
            ListTile(
              tileColor: AppColors.darkCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Nome deste dispositivo'),
              subtitle: Text(vaultProvider.deviceLabel),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => _editDeviceName(context),
            ),
            const SizedBox(height: 20),

            // Pareamento e Entrada
            _buildSectionHeader('Pareamento'),
            ListTile(
              tileColor: AppColors.darkCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Re-importar Entrada (.ikenr)'),
              subtitle: const Text('Atualizar cabeçalho e chaves a partir do Desktop'),
              trailing: const Icon(Icons.devices_outlined, size: 20),
              onTap: () => _handleReimportEnrollment(context),
            ),
            const SizedBox(height: 20),

            // Seção Sobre
            _buildSectionHeader('Sobre'),
            ListTile(
              tileColor: AppColors.darkCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(AppConstants.appName),
              subtitle: const Text('Versão 1.0.0 (Criptografia AES-256-GCM + Argon2id)'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.accent,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _pickSafFolder(BuildContext context) async {
    AutoLockService().pauseAutoLock();
    try {
      const channel = MethodChannel('com.ironkey.storage');
      final String? selectedUri = await channel.invokeMethod<String>('pickDirectory');

      if (selectedUri != null && selectedUri.isNotEmpty) {
        await vaultProvider.setSyncTreeUri(selectedUri);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pasta de sincronização configurada com sucesso!')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar pasta: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      AutoLockService().resumeAutoLock();
    }
  }

  void _editDeviceName(BuildContext context) async {
    final nameController = TextEditingController(text: vaultProvider.deviceLabel);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome do Dispositivo'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Ex: Celular Pessoal'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );

    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      await vaultProvider.setDeviceLabel(nameController.text.trim());
    }
  }

  void _handleReimportEnrollment(BuildContext context) async {
    final ikenrController = TextEditingController();
    final passController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-importar Entrada (.ikenr)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cole o conteúdo do novo arquivo .ikenr exportado do Desktop:',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ikenrController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '{"magic":"IronKeyPy-Enroll"...}',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Senha Mestre do cofre:',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Digite a senha mestre...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (result == true && ikenrController.text.isNotEmpty && passController.text.isNotEmpty) {
      try {
        await vaultProvider.importEnrollment(
          ikenrController.text.trim(),
          passController.text,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entrada (.ikenr) atualizada com sucesso!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha ao importar: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }
}
