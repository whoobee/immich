import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/memory.model.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/presentation/pages/drift_memory.page.dart';
import 'package:immich_mobile/presentation/widgets/images/thumbnail.widget.dart';
import 'package:immich_mobile/providers/infrastructure/memory.provider.dart';
import 'package:immich_mobile/routing/router.dart';

@RoutePage()
class MemoriesPage extends ConsumerWidget {
  const MemoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesAsync = ref.watch(driftAllMemoriesFutureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('memories').tr(), centerTitle: false),
      body: memoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(err.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (memories) {
          if (memories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'ai_album_generator_hints_empty'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(driftAllMemoriesFutureProvider),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: memories.length,
              itemBuilder: (context, index) {
                final memory = memories[index];
                return _MemoryTile(
                  memory: memory,
                  onTap: () {
                    if (memory.assets.isNotEmpty) {
                      DriftMemoryPage.setMemory(ref, memory);
                    }
                    context.pushRoute(
                      DriftMemoryRoute(memories: memories, memoryIndex: index),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.memory, required this.onTap});

  final DriftMemory memory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (memory.assets.isNotEmpty)
              Thumbnail.remote(
                remoteId: memory.assets.first.id,
                thumbhash: memory.assets.first.thumbHash ?? '',
                fit: BoxFit.cover,
              )
            else
              const ColoredBox(color: Colors.black26),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(_typeIcon, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        _typeLabel(context),
                        style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _typeIcon => memory.type == MemoryTypeEnum.aiStory ? Icons.auto_fix_high : Icons.history;

  String _typeLabel(BuildContext context) {
    if (memory.type == MemoryTypeEnum.aiStory) {
      return 'ai_generated_memory'.t(context: context);
    }
    return DateFormat.yMMMd(context.locale.toLanguageTag()).format(memory.memoryAt);
  }

  String _title(BuildContext context) {
    if (memory.type == MemoryTypeEnum.aiStory) {
      final aiTitle = memory.data.title;
      if (aiTitle != null && aiTitle.isNotEmpty) {
        return aiTitle;
      }
      return 'ai_generated_memory'.t(context: context);
    }
    final year = memory.data.year;
    if (year != null) {
      final yearsAgo = DateTime.now().year - year;
      return 'years_ago'.t(context: context, args: {'years': yearsAgo.toString()});
    }
    return DateFormat.yMMMd(context.locale.toLanguageTag()).format(memory.memoryAt);
  }
}
