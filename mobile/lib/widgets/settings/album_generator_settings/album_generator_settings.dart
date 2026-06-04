import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:immich_mobile/services/album_generator_background.service.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';
import 'package:immich_mobile/widgets/settings/setting_group_title.dart';
import 'package:openapi/api.dart';

class AlbumGeneratorSettings extends ConsumerStatefulWidget {
  const AlbumGeneratorSettings({super.key});

  @override
  ConsumerState<AlbumGeneratorSettings> createState() => _AlbumGeneratorSettingsState();
}

class _AlbumGeneratorSettingsState extends ConsumerState<AlbumGeneratorSettings> {
  bool _loading = true;
  bool _saving = false;
  bool _onDemandSubmitting = false;

  bool _optIn = false;
  int _maxPerNight = 2;
  List<String> _hints = const [];

  final _hintController = TextEditingController();
  final _onDemandController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hintController.dispose();
    _onDemandController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cfg = await ref.read(apiServiceProvider).albumGeneratorApi.getAlbumGeneratorConfig();
      if (!mounted || cfg == null) {
        return;
      }
      setState(() {
        _optIn = cfg.optIn;
        _maxPerNight = cfg.maxPerNight;
        _hints = List<String>.from(cfg.hints);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ImmichToast.show(
        context: context,
        msg: 'ai_album_generator_load_failed'.tr(),
        toastType: ToastType.error,
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiServiceProvider).albumGeneratorApi.updateAlbumGeneratorConfig(
            AlbumGeneratorUserConfigDto(
              optIn: _optIn,
              maxPerNight: _maxPerNight,
              hints: _hints,
            ),
          );
      // Match the periodic background poll to the opt-in state: only schedule
      // when the user wants nightly memories, otherwise free the worker slot.
      if (_optIn) {
        await registerAiMemoryBackgroundCheck();
      } else {
        await unregisterAiMemoryBackgroundCheck();
      }
      if (!mounted) {
        return;
      }
      ImmichToast.show(context: context, msg: 'saved_settings'.tr());
    } catch (_) {
      if (!mounted) {
        return;
      }
      ImmichToast.show(
        context: context,
        msg: 'ai_album_generator_save_failed'.tr(),
        toastType: ToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _addHint() {
    final trimmed = _hintController.text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (_hints.contains(trimmed)) {
      _hintController.clear();
      return;
    }
    if (_hints.length >= 20) {
      ImmichToast.show(context: context, msg: 'ai_album_generator_max_hints_reached'.tr());
      return;
    }
    setState(() {
      _hints = [..._hints, trimmed];
      _hintController.clear();
    });
  }

  void _removeHint(String hint) {
    setState(() => _hints = _hints.where((h) => h != hint).toList());
  }

  Future<void> _generateOnDemand() async {
    final prompt = _onDemandController.text.trim();
    if (prompt.length < 2) {
      ImmichToast.show(context: context, msg: 'ai_album_generator_on_demand_prompt_too_short'.tr());
      return;
    }
    setState(() => _onDemandSubmitting = true);
    try {
      await ref.read(apiServiceProvider).albumGeneratorApi.triggerOnDemand(
            AlbumGeneratorOnDemandRequestDto(hint: prompt),
          );
      if (!mounted) {
        return;
      }
      ImmichToast.show(context: context, msg: 'ai_album_generator_on_demand_queued'.tr());
      _onDemandController.clear();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ImmichToast.show(
        context: context,
        msg: 'ai_album_generator_on_demand_failed'.tr(),
        toastType: ToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _onDemandSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // On-demand
          SettingGroupTitle(
            title: 'ai_album_generator_on_demand_title'.tr(),
            subtitle: 'ai_album_generator_on_demand_description'.tr(),
            icon: Icons.auto_fix_high,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _onDemandController,
            enabled: !_onDemandSubmitting,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'ai_album_generator_on_demand_placeholder'.tr(),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _generateOnDemand(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _onDemandSubmitting ? null : _generateOnDemand,
              icon: _onDemandSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(
                _onDemandSubmitting
                    ? 'ai_album_generator_on_demand_submitting'.tr()
                    : 'ai_album_generator_on_demand_generate'.tr(),
              ),
            ),
          ),

          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),

          // Nightly opt-in
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _optIn,
            title: Text('ai_album_generator_enabled'.tr()),
            subtitle: Text('ai_album_generator_enabled_description'.tr()),
            onChanged: (v) => setState(() => _optIn = v),
          ),

          const SizedBox(height: 8),

          // Max per night
          Opacity(
            opacity: _optIn ? 1.0 : 0.5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ai_album_generator_max_per_night'.tr(),
                          style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 4),
                      Text('ai_album_generator_max_per_night_description'.tr(),
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: DropdownButtonFormField<int>(
                    initialValue: _maxPerNight,
                    items: List.generate(10, (i) => i + 1)
                        .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: !_optIn ? null : (v) => setState(() => _maxPerNight = v ?? _maxPerNight),
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Hints
          Opacity(
            opacity: _optIn ? 1.0 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ai_album_generator_hints'.tr(), style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text('ai_album_generator_hints_description'.tr(),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                if (_hints.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'ai_album_generator_hints_empty'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                if (_hints.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _hints
                        .map(
                          (hint) => InputChip(
                            label: Text(hint),
                            onDeleted: !_optIn ? null : () => _removeHint(hint),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hintController,
                        enabled: _optIn,
                        maxLength: 80,
                        decoration: InputDecoration(
                          hintText: 'ai_album_generator_hints_placeholder'.tr(),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          counterText: '',
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addHint(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _optIn ? _addHint : null,
                      icon: const Icon(Icons.add),
                      label: Text('add'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('save'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
