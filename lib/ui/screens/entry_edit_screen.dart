import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/vault_entry.dart';
import '../../providers/vault_provider.dart';

class EntryEditScreen extends StatefulWidget {
  final VaultProvider vaultProvider;
  final VaultEntry? entry;

  const EntryEditScreen({
    super.key,
    required this.vaultProvider,
    this.entry,
  });

  @override
  State<EntryEditScreen> createState() => _EntryEditScreenState();
}

class _EntryEditScreenState extends State<EntryEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _urlController;
  late TextEditingController _categoryController;
  late TextEditingController _notesController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _titleController = TextEditingController(text: e?.title ?? '');
    _usernameController = TextEditingController(text: e?.username ?? '');
    _passwordController = TextEditingController(text: e?.password ?? '');
    _urlController = TextEditingController(text: e?.url ?? '');
    _categoryController = TextEditingController(text: e?.category ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.entry;
    final updated = VaultEntry(
      uid: existing?.uid,
      title: _titleController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      url: _urlController.text.trim(),
      category: _categoryController.text.trim(),
      notes: _notesController.text.trim(),
      favorite: existing?.favorite ?? false,
      rev: (existing?.rev ?? 0) + 1,
      createdAt: existing?.createdAt,
    );

    await widget.vaultProvider.saveEntry(updated);
    if (mounted) Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.entry == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Novo Registro' : 'Editar Registro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.accent),
            onPressed: _handleSave,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título *',
                hintText: 'Ex: GitHub, Banco, Email...',
                prefixIcon: Icon(Icons.title, color: AppColors.textSubtle),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um título' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Usuário ou Email',
                hintText: 'Ex: usuario@email.com',
                prefixIcon: Icon(Icons.person_outline, color: AppColors.textSubtle),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Senha',
                hintText: 'Digite ou gere uma senha',
                prefixIcon: const Icon(Icons.key_outlined, color: AppColors.textSubtle),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL / Site',
                hintText: 'https://...',
                prefixIcon: Icon(Icons.link, color: AppColors.textSubtle),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                hintText: 'Ex: Trabalho, Pessoal, Financeiro',
                prefixIcon: Icon(Icons.folder_outlined, color: AppColors.textSubtle),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notas e Anotações',
                hintText: 'Informações adicionais...',
                prefixIcon: Icon(Icons.notes, color: AppColors.textSubtle),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: Text(isNew ? 'Salvar Registro' : 'Atualizar Registro'),
              onPressed: _handleSave,
            ),
          ],
        ),
      ),
    );
  }
}
