import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/memory.model.dart';
import 'package:immich_mobile/domain/services/memory.service.dart';
import 'package:immich_mobile/infrastructure/repositories/memory.repository.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';

final driftMemoryRepositoryProvider = Provider<DriftMemoryRepository>(
  (ref) => DriftMemoryRepository(ref.watch(driftProvider)),
);

final driftMemoryServiceProvider = Provider<DriftMemoryService>(
  (ref) => DriftMemoryService(ref.watch(driftMemoryRepositoryProvider)),
);

final driftMemoryFutureProvider = FutureProvider.autoDispose<List<DriftMemory>>((ref) {
  final (userId, enabled) = ref.watch(currentUserProvider.select((user) => (user?.id, user?.memoryEnabled ?? true)));
  if (userId == null || !enabled) {
    return const [];
  }

  final service = ref.watch(driftMemoryServiceProvider);
  return service.getMemoryLane(userId);
});

/// Backs the Memories tab — every memory the user has, including AI-generated
/// ones, without the today-only show/hide filter that drives the lane.
final driftAllMemoriesFutureProvider = FutureProvider.autoDispose<List<DriftMemory>>((ref) {
  final (userId, enabled) = ref.watch(currentUserProvider.select((user) => (user?.id, user?.memoryEnabled ?? true)));
  if (userId == null || !enabled) {
    return const [];
  }

  final service = ref.watch(driftMemoryServiceProvider);
  return service.getAllForUser(userId);
});
