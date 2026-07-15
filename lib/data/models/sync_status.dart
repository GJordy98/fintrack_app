import 'package:hive/hive.dart';

import '../hive_config.dart';

part 'sync_status.g.dart';

/// État de synchronisation d'une entité vis-à-vis du serveur (Phase 8).
/// En local-first, toute entité naît `dirty` et passe `synced` après push.
@HiveType(typeId: HiveTypeIds.syncStatus)
enum SyncStatus {
  @HiveField(0)
  dirty,
  @HiveField(1)
  synced,
  @HiveField(2)
  pendingDelete,
}
