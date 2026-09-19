class SyncOutcome {
  final String status; // 'ok' | 'noop' | 'disabled' | 'error'
  final String reason;
  final int added;
  final int updated;
  final int removed;
  final int purged;
  final int conflicts;
  final int resurrections;
  final int generation;
  final String message;
  final List<String> warnings;

  SyncOutcome({
    this.status = 'noop',
    this.reason = 'manual',
    this.added = 0,
    this.updated = 0,
    this.removed = 0,
    this.purged = 0,
    this.conflicts = 0,
    this.resurrections = 0,
    this.generation = 0,
    this.message = '',
    List<String>? warnings,
  }) : warnings = warnings ?? [];

  bool get changedLocally => added > 0 || updated > 0 || removed > 0;

  String summary() {
    if (status == 'error') return message.isNotEmpty ? message : 'Falha na sincronização.';
    if (status == 'disabled') return message.isNotEmpty ? message : 'Sincronização desativada.';

    List<String> parts = [];
    if (added > 0) parts.add('$added novo(s)');
    if (updated > 0) parts.add('$updated atualizado(s)');
    if (removed > 0) parts.add('$removed removido(s)');
    if (conflicts > 0) parts.add('$conflicts conflito(s)');

    if (parts.isEmpty) {
      return 'Cofre já estava atualizado.';
    }
    return 'Sincronizado: ${parts.join(', ')}.';
  }
}
