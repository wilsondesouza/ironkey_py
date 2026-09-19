import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../providers/vault_provider.dart';

class LockScreen extends StatefulWidget {
  final VaultProvider vaultProvider;
  final VoidCallback onUnlocked;

  const LockScreen({
    super.key,
    required this.vaultProvider,
    required this.onUnlocked,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    final password = _passwordController.text;
    if (password.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.vaultProvider.unlock(password);
      if (success) {
        widget.onUnlocked();
      } else {
        setState(() {
          _errorMessage = 'Senha mestre incorreta.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleImportEnrollment() async {
    final ikenrController = TextEditingController();
    final passController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar Entrada (.ikenr)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cole o conteúdo do arquivo .ikenr exportado do seu desktop:',
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
      setState(() => _isLoading = true);
      try {
        await widget.vaultProvider.importEnrollment(
          ikenrController.text.trim(),
          passController.text,
        );
        widget.onUnlocked();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha ao importar: ${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo & Branding
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 44,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cofre seguro e criptografado de ponta a ponta',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Campo de Senha Mestre
                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleUnlock(),
                  decoration: InputDecoration(
                    labelText: 'Senha Mestre',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSubtle),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.textSubtle,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    errorText: _errorMessage,
                  ),
                ),
                const SizedBox(height: 20),

                // Botão de Desbloqueio
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleUnlock,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Abrir Cofre', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 24),

                // Divisor
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.darkBorder)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OU', style: TextStyle(color: AppColors.textSubtle, fontSize: 12)),
                    ),
                    const Expanded(child: Divider(color: AppColors.darkBorder)),
                  ],
                ),
                const SizedBox(height: 20),

                // Botão de Pareamento / Importação de Entrada
                OutlinedButton.icon(
                  icon: const Icon(Icons.devices_outlined, size: 18),
                  label: const Text('Importar Entrada de Dispositivo (.ikenr)'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _handleImportEnrollment,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
