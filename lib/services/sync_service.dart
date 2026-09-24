import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/vault_entry.dart';
import '../models/sync_outcome.dart';
import 'storage_service.dart';

class SyncService {
  static const MethodChannel _storageChannel = MethodChannel('com.ironkey.storage');
  static const MethodChannel _syncChannel = MethodChannel('com.ironkey.sync_native');

  /// Executa a sincronização bidirecional completa com a pasta em nuvem via SAF.
  static Future<SyncOutcome> synchronize({
    required String treeUriStr,
    required String deviceId,
    String reason = 'manual',
  }) async {
    if (treeUriStr.isEmpty) {
      return SyncOutcome(status: 'disabled', message: 'Nenhuma pasta de sincronização configurada.');
    }

    try {
      final List<String> syncWarnings = [];

      // 1. Lê arquivos da pasta SAF
      final Map<dynamic, dynamic>? remoteData = await _storageChannel.invokeMethod('readRemoteFiles', {
        'treeUri': treeUriStr,
      });

      final bool hasBlob = remoteData != null && remoteData['hasBlob'] == true;
      final List<dynamic> rawConflicts = remoteData?['conflicts'] as List<dynamic>? ?? [];

      if (!hasBlob && rawConflicts.isEmpty) {
        // Primeira sincronização ou pasta vazia: faz upload do estado local inicial
        return await _initialUpload(treeUriStr, deviceId);
      }

      int remoteGen = 0;
      final List<VaultEntry> remoteEntries = [];

      // 2. Decifra o blob principal
      if (hasBlob) {
        final String blobBase64 = remoteData!['blobBase64'] as String;
        final String manifestStr = remoteData['manifest'] as String;

        if (manifestStr.isNotEmpty) {
          try {
            final Map<dynamic, dynamic>? valRes = await _syncChannel.invokeMethod('verifyManifest', {
              'manifest': manifestStr,
              'blobBase64': blobBase64,
            });

            if (valRes == null || valRes['valid'] != true) {
              final String reasonMsg = valRes?['reason'] ?? 'Aviso na verificação do manifesto.';
              syncWarnings.add(reasonMsg);
            }
          } catch (_) {}
        }

        try {
          final Map<dynamic, dynamic>? doc = await _syncChannel.invokeMethod('readSyncBlob', {
            'blobBase64': blobBase64,
          });
          if (doc != null) {
            remoteGen = (doc['generation'] as num?)?.toInt() ?? 0;
            final List<dynamic> remoteEntriesRaw = doc['entries'] as List<dynamic>? ?? [];
            for (final m in remoteEntriesRaw) {
              remoteEntries.add(VaultEntry.fromMap(Map<String, dynamic>.from(m)));
            }
          }
        } on PlatformException catch (e) {
          syncWarnings.add('Erro na decifragem do arquivo principal: ${e.message}');
        } catch (e) {
          syncWarnings.add('Falha ao decifrar blob principal: $e');
        }
      }

      // 3. Incorpora cópias de conflito criadas por provedores de nuvem (Dropbox/Drive/OneDrive)
      for (final conflict in rawConflicts) {
        try {
          final cBlobBase64 = conflict['dataBase64'] as String;
          final cFilename = conflict['filename'] as String? ?? 'conflito';
          final Map<dynamic, dynamic>? cDoc = await _syncChannel.invokeMethod('readSyncBlob', {
            'blobBase64': cBlobBase64,
          });
          if (cDoc != null) {
            final int cGen = (cDoc['generation'] as num?)?.toInt() ?? 0;
            if (cGen > remoteGen) {
              remoteGen = cGen;
            }
            final cEntriesRaw = cDoc['entries'] as List<dynamic>? ?? [];
            for (final item in cEntriesRaw) {
              remoteEntries.add(VaultEntry.fromMap(Map<String, dynamic>.from(item)));
            }
            syncWarnings.add('Cópia de nuvem incorporada: $cFilename (geração $cGen)');
          }
        } catch (_) {}
      }

      if (remoteEntries.isEmpty && !hasBlob) {
        return SyncOutcome(
          status: 'error',
          message: 'Nenhum arquivo de sincronização válido encontrado na pasta.',
          warnings: syncWarnings,
        );
      }

      // Desduplica lista remota se houver registros com o mesmo UID vindos de arquivos de conflito
      final Map<String, VaultEntry> canonicalRemoteMap = {};
      for (final r in remoteEntries) {
        final existing = canonicalRemoteMap[r.uid];
        if (existing == null || r.rev > existing.rev || (r.rev == existing.rev && r.updatedAt.compareTo(existing.updatedAt) > 0)) {
          canonicalRemoteMap[r.uid] = r;
        }
      }
      final List<VaultEntry> consolidatedRemote = canonicalRemoteMap.values.toList();

      // 4. Executa a Mesclagem (Merge) Registro por Registro
      final List<VaultEntry> localEntries = await StorageService.getAllEntries(includeDeleted: true);
      final mergeResult = await _mergeEntries(localEntries, consolidatedRemote, deviceId);

      // Salva os registros atualizados localmente
      for (final entry in mergeResult.toSaveLocally) {
        await StorageService.saveEntry(entry);
      }

      final lastGenStr = await StorageService.getMeta('sync_last_generation');
      final int knownGen = int.tryParse(lastGenStr ?? '0') ?? 0;
      final int newGen = (remoteGen > knownGen ? remoteGen : knownGen) + 1;

      // 5. Grava de volta na nuvem se houve modificações ou novos registros
      final bool needsUpload = mergeResult.added > 0 ||
          mergeResult.updated > 0 ||
          mergeResult.removed > 0 ||
          mergeResult.conflicts > 0 ||
          localEntries.length != consolidatedRemote.length;

      if (needsUpload) {
        final List<VaultEntry> allCurrent = await StorageService.getAllEntries(includeDeleted: true);
        final List<Map<String, dynamic>> syncList = allCurrent.map((e) => e.toSyncMap()).toList();

        final Map<dynamic, dynamic>? buildRes = await _syncChannel.invokeMethod('buildSyncPayload', {
          'generation': newGen,
          'entries': syncList,
          'deviceId': deviceId,
          'purgedUids': <String>[],
        });

        if (buildRes != null) {
          await _storageChannel.invokeMethod('writeRemoteFiles', {
            'treeUri': treeUriStr,
            'blobBase64': buildRes['blobBase64'],
            'manifest': buildRes['manifest'],
          });
          await StorageService.setMeta('sync_last_generation', newGen.toString());
        }
      } else {
        await StorageService.setMeta('sync_last_generation', remoteGen.toString());
      }

      return SyncOutcome(
        status: 'ok',
        reason: reason,
        added: mergeResult.added,
        updated: mergeResult.updated,
        removed: mergeResult.removed,
        conflicts: mergeResult.conflicts,
        generation: needsUpload ? newGen : remoteGen,
        warnings: syncWarnings,
      );
    } catch (e) {
      return SyncOutcome(status: 'error', message: e.toString());
    }
  }

  static Future<SyncOutcome> _initialUpload(String treeUriStr, String deviceId) async {
    final List<VaultEntry> localEntries = await StorageService.getAllEntries(includeDeleted: true);
    final List<Map<String, dynamic>> syncList = localEntries.map((e) => e.toSyncMap()).toList();

    final Map<dynamic, dynamic>? buildRes = await _syncChannel.invokeMethod('buildSyncPayload', {
      'generation': 1,
      'entries': syncList,
      'deviceId': deviceId,
      'purgedUids': <String>[],
    });

    if (buildRes != null) {
      await _storageChannel.invokeMethod('writeRemoteFiles', {
        'treeUri': treeUriStr,
        'blobBase64': buildRes['blobBase64'],
        'manifest': buildRes['manifest'],
      });
      await StorageService.setMeta('sync_last_generation', '1');
    }

    return SyncOutcome(status: 'ok', added: localEntries.length, generation: 1);
  }

  static Future<_MergeResult> _mergeEntries(
    List<VaultEntry> localList,
    List<VaultEntry> remoteList,
    String localDeviceId,
  ) async {
    final Map<String, VaultEntry> localMap = {for (var e in localList) e.uid: e};
    final Map<String, VaultEntry> remoteMap = {for (var e in remoteList) e.uid: e};

    final Set<String> allUids = {...localMap.keys, ...remoteMap.keys};
    final List<VaultEntry> toSaveLocally = [];
    int added = 0, updated = 0, removed = 0, conflicts = 0;

    for (final uid in allUids) {
      final local = localMap[uid];
      final remote = remoteMap[uid];

      if (local == null && remote != null) {
        // Registro novo vindo da nuvem
        toSaveLocally.add(remote);
        if (remote.isDeleted) {
          removed++;
        } else {
          added++;
        }
      } else if (local != null && remote == null) {
        // Registro local que ainda não existe na nuvem — mantém
      } else if (local != null && remote != null) {
        // Ambos existem: compara `rev`
        if (remote.rev > local.rev) {
          toSaveLocally.add(remote);
          if (remote.isDeleted && !local.isDeleted) {
            removed++;
          } else {
            updated++;
          }
        } else if (local.rev > remote.rev) {
          // Local é mais recente — mantém local
        } else {
          // Mesma revisão (local.rev == remote.rev)
          final localJson = jsonEncode(local.toSyncMap());
          final remoteJson = jsonEncode(remote.toSyncMap());

          if (localJson != remoteJson) {
            // Conflito Real de Edição Simultânea
            conflicts++;
            final bool remoteWins = remote.updatedAt.compareTo(local.updatedAt) >= 0;
            final winner = remoteWins ? remote : local;
            final loser = remoteWins ? local : remote;

            // Preserva a versão perdedora como um novo registro separado
            final nowStamp = DateTime.now().toUtc().toIso8601String().substring(0, 16).replaceAll('T', ' ');
            final loserPreserved = loser.copyWith(
              title: '${loser.title} (conflito: ${loser.deviceId.isNotEmpty ? loser.deviceId : "remoto"} $nowStamp)',
              rev: 1,
              deletedAt: null,
            );

            toSaveLocally.add(winner);
            toSaveLocally.add(loserPreserved);

            await StorageService.logConflict(winner.uid, loser.deviceId, {
              'kind': 'concurrent_edit',
              'winner_rev': winner.rev,
              'loser_rev': loser.rev,
              'preserved_uid': loserPreserved.uid,
              'preserved_title': loserPreserved.title,
            });
          }
        }
      }
    }

    return _MergeResult(
      toSaveLocally: toSaveLocally,
      added: added,
      updated: updated,
      removed: removed,
      conflicts: conflicts,
    );
  }
}

class _MergeResult {
  final List<VaultEntry> toSaveLocally;
  final int added;
  final int updated;
  final int removed;
  final int conflicts;

  _MergeResult({
    required this.toSaveLocally,
    required this.added,
    required this.updated,
    required this.removed,
    required this.conflicts,
  });
}
