import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/vault_entry.dart';
import '../../providers/vault_provider.dart';
import '../widgets/entry_card.dart';
import '../widgets/sync_status_badge.dart';
import 'entry_detail_screen.dart';
import 'entry_edit_screen.dart';
import 'generator_screen.dart';
import 'settings_screen.dart';
import 'conflicts_screen.dart';

class VaultScreen extends StatefulWidget {
  final VaultProvider vaultProvider;

  const VaultScreen({super.key, required this.vaultProvider});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  int _currentTabIndex = 0;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEntryDetail(VaultEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryDetailScreen(
          entry: entry,
          vaultProvider: widget.vaultProvider,
        ),
      ),
    );
  }

  void _openNewEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditScreen(
          vaultProvider: widget.vaultProvider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vaultProvider,
      builder: (context, _) {
        final provider = widget.vaultProvider;

        return Scaffold(
          appBar: _buildAppBar(provider),
          body: _buildBody(provider),
          bottomNavigationBar: NavigationBar(
            backgroundColor: AppColors.darkCard,
            selectedIndex: _currentTabIndex,
            onDestinationSelected: (idx) {
              setState(() => _currentTabIndex = idx);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield, color: Color.fromARGB(255, 255, 255, 255)),
                label: 'Cofre',
              ),
              NavigationDestination(
                icon: Icon(Icons.password_outlined),
                selectedIcon: Icon(Icons.password, color: Color.fromARGB(255, 250, 251, 252)),
                label: 'Gerador',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings, color: Color.fromARGB(255, 255, 255, 255)),
                label: 'Ajustes',
              ),
            ],
          ),
          floatingActionButton: _currentTabIndex == 0
              ? FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo'),
                  onPressed: _openNewEntry,
                )
              : null,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(VaultProvider provider) {
    if (_currentTabIndex == 1) {
      return AppBar(title: const Text('Gerador de Senhas'));
    }
    if (_currentTabIndex == 2) {
      return AppBar(title: const Text('Configurações'));
    }

    return AppBar(
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.accent, size: 22),
          SizedBox(width: 8),
          Text('IronKey'),
        ],
      ),
      actions: [
        if (provider.pendingConflictsCount > 0)
          IconButton(
            icon: const Badge(
              label: Text('!'),
              backgroundColor: AppColors.warning,
              child: Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            ),
            tooltip: 'Revisar conflitos de sincronização',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConflictsScreen(vaultProvider: provider),
                ),
              );
            },
          ),
        SyncStatusBadge(
          isSyncing: provider.isSyncing,
          hasConflicts: provider.pendingConflictsCount > 0,
          isConfigured: provider.syncTreeUri.isNotEmpty,
          onTap: () async {
            final outcome = await provider.syncNow();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(outcome.summary()),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.lock_outline),
          tooltip: 'Trancar cofre',
          onPressed: () => provider.lock(),
        ),
      ],
    );
  }

  Widget _buildBody(VaultProvider provider) {
    if (_currentTabIndex == 1) {
      return const GeneratorScreen();
    }
    if (_currentTabIndex == 2) {
      return SettingsScreen(vaultProvider: provider);
    }

    final entries = provider.entries;

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.darkCard,
      onRefresh: () async {
        await provider.syncNow(reason: 'pull_refresh');
      },
      child: Column(
        children: [
          // Barra de Busca
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => provider.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Buscar registros...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSubtle, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          provider.setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              ),
            ),
          ),

          // Chips de Categorias e Favoritos
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: provider.selectedCategory == null && !provider.showFavoritesOnly,
                  onSelected: (_) {
                    provider.setCategory(null);
                    if (provider.showFavoritesOnly) provider.toggleFavoritesOnly();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: provider.showFavoritesOnly ? AppColors.warning : AppColors.textSubtle,
                  ),
                  label: const Text('Favoritos'),
                  selected: provider.showFavoritesOnly,
                  onSelected: (_) => provider.toggleFavoritesOnly(),
                ),
                ...provider.categories.map((cat) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: provider.selectedCategory == cat,
                        onSelected: (sel) => provider.setCategory(sel ? cat : null),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Lista de Registros
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.textSubtle.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'Nenhum registro encontrado',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80, top: 4),
                    itemCount: entries.length,
                    itemBuilder: (context, idx) {
                      final entry = entries[idx];
                      return EntryCard(
                        entry: entry,
                        onTap: () => _openEntryDetail(entry),
                        onToggleFavorite: () => provider.toggleFavorite(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
