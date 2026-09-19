import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/vault_entry.dart';
import '../models/sync_outcome.dart';
import '../services/crypto_bridge.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/auto_lock_service.dart';

class VaultProvider extends ChangeNotifier {
  final _secureStorage = const FlutterSecureStorage();

  bool _isUnlocked = false;
  bool get isUnlocked => _isUnlocked;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  List<VaultEntry> _entries = [];
  List<VaultEntry> get entries => _filteredEntries();

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String? _selectedCategory;
  String? get selectedCategory => _selectedCategory;

  bool _showFavoritesOnly = false;
  bool get showFavoritesOnly => _showFavoritesOnly;

  int _pendingConflictsCount = 0;
  int get pendingConflictsCount => _pendingConflictsCount;

  SyncOutcome? _lastSyncOutcome;
  SyncOutcome? get lastSyncOutcome => _lastSyncOutcome;

  String _deviceId = '';
  String get deviceId => _deviceId;

  String _deviceLabel = 'Android';
  String get deviceLabel => _deviceLabel;

  String _syncTreeUri = '';
  String get syncTreeUri => _syncTreeUri;

  String? _vaultConfigJson;
  String? get vaultConfigJson => _vaultConfigJson;

  VaultProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id') ?? '';
    if (_deviceId.isEmpty) {
      _deviceId = const Uuid().v4().replaceAll('-', '').substring(0, 8);
      await prefs.setString('device_id', _deviceId);
    }
    _deviceLabel = prefs.getString('device_label') ?? 'Android';

    // Carrega a URI do SharedPreferences com fallback redundante no SQLite meta
    String uri = prefs.getString('sync_tree_uri') ?? '';
    if (uri.isEmpty) {
      try {
        final metaUri = await StorageService.getMeta('sync_tree_uri');
        if (metaUri != null && metaUri.isNotEmpty) {
          uri = metaUri;
          await prefs.setString('sync_tree_uri', uri);
        }
      } catch (_) {}
    }
    _syncTreeUri = uri;

    _vaultConfigJson = await _secureStorage.read(key: 'vault_config_json');
    notifyListeners();
  }

  Future<bool> hasExistingVault() async {
    final cfg = await _secureStorage.read(key: 'vault_config_json');
    return cfg != null && cfg.isNotEmpty;
  }

  Future<bool> unlock(String masterPassword) async {
    await _loadSettings();
    final cfg = _vaultConfigJson ?? await _secureStorage.read(key: 'vault_config_json');
    if (cfg == null) return false;

    final success = await CryptoBridge.unlock(
      masterPassword: masterPassword,
      configJson: cfg,
    );

    if (success) {
      _isUnlocked = true;
      await reloadEntries();
      await checkPendingConflicts();

      AutoLockService().start(
        onLock: () => lock(),
        timeoutSec: 300,
        lockOnBg: false,
      );

      if (_syncTreeUri.isNotEmpty) {
        syncNow(reason: 'unlock');
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> lock() async {
    await CryptoBridge.lock();
    _isUnlocked = false;
    _entries.clear();
    AutoLockService().stop();
    notifyListeners();
  }

  Future<void> importEnrollment(String ikenrJson, String masterPassword) async {
    final data = await CryptoBridge.readEnrollment(
      ikenrJson: ikenrJson,
      masterPassword: masterPassword,
    );

    final headerJson = data['headerJson'] as String;
    await _secureStorage.write(key: 'vault_config_json', value: headerJson);
    _vaultConfigJson = headerJson;

    // Destrava imediatamente
    await unlock(masterPassword);
  }

  Future<void> clearVaultData() async {
    await lock();
    await _secureStorage.delete(key: 'vault_config_json');
    _vaultConfigJson = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sync_tree_uri');
    _syncTreeUri = '';
    notifyListeners();
  }

  Future<void> reloadEntries() async {
    _entries = await StorageService.getAllEntries();
    notifyListeners();
  }

  Future<void> checkPendingConflicts() async {
    _pendingConflictsCount = await StorageService.countPendingConflicts();
    notifyListeners();
  }

  // --- Filtros e Busca -----------------------------------------------

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setCategory(String? cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  void toggleFavoritesOnly() {
    _showFavoritesOnly = !_showFavoritesOnly;
    notifyListeners();
  }

  List<String> get categories {
    final set = <String>{};
    for (var e in _entries) {
      if (e.category.isNotEmpty) set.add(e.category);
    }
    return set.toList()..sort();
  }

  List<VaultEntry> _filteredEntries() {
    return _entries.where((e) {
      if (_showFavoritesOnly && !e.favorite) return false;
      if (_selectedCategory != null && e.category != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = e.title.toLowerCase().contains(q);
        final matchUser = e.username.toLowerCase().contains(q);
        final matchUrl = e.url.toLowerCase().contains(q);
        final matchNotes = e.notes.toLowerCase().contains(q);
        return matchTitle || matchUser || matchUrl || matchNotes;
      }
      return true;
    }).toList();
  }

  // --- CRUD de Registros ---------------------------------------------

  Future<void> saveEntry(VaultEntry entry) async {
    AutoLockService().recordActivity();
    entry.deviceId = _deviceId;
    entry.updatedAt = DateTime.now().toUtc().toIso8601String();
    await StorageService.saveEntry(entry);
    await reloadEntries();

    if (_syncTreeUri.isNotEmpty) {
      syncNow(reason: 'save_entry');
    }
  }

  Future<void> deleteEntry(String uid) async {
    AutoLockService().recordActivity();
    await StorageService.deleteEntry(uid, deviceId: _deviceId);
    await reloadEntries();

    if (_syncTreeUri.isNotEmpty) {
      syncNow(reason: 'delete_entry');
    }
  }

  Future<void> toggleFavorite(VaultEntry entry) async {
    final updated = entry.copyWith(favorite: !entry.favorite, rev: entry.rev + 1);
    await saveEntry(updated);
  }

  // --- Sincronização -------------------------------------------------

  Future<void> setSyncTreeUri(String uri) async {
    _syncTreeUri = uri;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_tree_uri', uri);
    } catch (_) {}

    try {
      await StorageService.setMeta('sync_tree_uri', uri);
    } catch (_) {}

    if (_isUnlocked && uri.isNotEmpty) {
      await syncNow(reason: 'configured');
    }
  }

  Future<void> setDeviceLabel(String label) async {
    _deviceLabel = label;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_label', label);
    notifyListeners();
  }

  Future<SyncOutcome> syncNow({String reason = 'manual'}) async {
    if (_isSyncing) {
      return SyncOutcome(status: 'noop', message: 'Sincronização já em andamento.');
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final outcome = await SyncService.synchronize(
        treeUriStr: _syncTreeUri,
        deviceId: _deviceId,
        reason: reason,
      );

      _lastSyncOutcome = outcome;
      await reloadEntries();
      await checkPendingConflicts();
      return outcome;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
