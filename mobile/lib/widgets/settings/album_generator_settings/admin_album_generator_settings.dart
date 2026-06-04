import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';
import 'package:immich_mobile/widgets/settings/setting_group_title.dart';
import 'package:openapi/api.dart';

class AdminAlbumGeneratorSettings extends ConsumerStatefulWidget {
  const AdminAlbumGeneratorSettings({super.key});

  @override
  ConsumerState<AdminAlbumGeneratorSettings> createState() => _AdminAlbumGeneratorSettingsState();
}

class _AdminAlbumGeneratorSettingsState extends ConsumerState<AdminAlbumGeneratorSettings> {
  bool _loading = true;
  bool _saving = false;
  bool _audioScanSubmitting = false;

  SystemConfigDto? _config;

  late bool _enabled;
  late String _cronExpression;
  late int _jitterMinutes;
  late int _extraRunsPerWeek;
  late String _ollamaEndpoint;
  late String _ollamaTextModel;
  late String _ollamaVisionModel;
  late bool _audioEnabled;
  late String _audioLibraryPath;
  late double _audioVolume;

  final _themeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cfg = await ref.read(apiServiceProvider).systemConfigApi.getConfig();
      if (!mounted || cfg == null) {
        return;
      }
      setState(() {
        _config = cfg;
        final ag = cfg.albumGenerator;
        _enabled = ag.enabled;
        _cronExpression = ag.cronExpression;
        _jitterMinutes = ag.jitterMinutes;
        _extraRunsPerWeek = ag.extraRunsPerWeek;
        _ollamaEndpoint = ag.ollama.endpoint;
        _ollamaTextModel = ag.ollama.textModel;
        _ollamaVisionModel = ag.ollama.visionModel;
        _audioEnabled = ag.audio.enabled;
        _audioLibraryPath = ag.audio.libraryPath;
        _audioVolume = ag.audio.volume.toDouble();
        _themeController.text = ag.themeVocabulary.join('\n');
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
    final current = _config;
    if (current == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final themes = _themeController.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      current.albumGenerator = SystemConfigAlbumGeneratorDto(
        enabled: _enabled,
        cronExpression: _cronExpression,
        jitterMinutes: _jitterMinutes,
        extraRunsPerWeek: _extraRunsPerWeek,
        ollama: SystemConfigAlbumGeneratorOllamaDto(
          endpoint: _ollamaEndpoint,
          textModel: _ollamaTextModel,
          visionModel: _ollamaVisionModel,
        ),
        themeVocabulary: themes,
        audio: SystemConfigAlbumGeneratorAudioDto(
          enabled: _audioEnabled,
          libraryPath: _audioLibraryPath,
          volume: _audioVolume,
        ),
      );
      await ref.read(apiServiceProvider).systemConfigApi.updateConfig(current);
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

  Future<void> _rescanAudio() async {
    setState(() => _audioScanSubmitting = true);
    try {
      await ref.read(apiServiceProvider).albumGeneratorApi.triggerAudioScan(
            AlbumGeneratorAudioScanRequestDto(),
          );
      if (!mounted) {
        return;
      }
      ImmichToast.show(context: context, msg: 'ai_album_generator_audio_scan_queued'.tr());
    } catch (_) {
      if (!mounted) {
        return;
      }
      ImmichToast.show(
        context: context,
        msg: 'ai_album_generator_audio_scan_failed'.tr(),
        toastType: ToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _audioScanSubmitting = false);
      }
    }
  }

  Widget _textField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    bool enabled = true,
  }) {
    final controller = TextEditingController(text: value);
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            title: Text('admin.album_generator_enabled'.tr()),
            subtitle: Text('admin.album_generator_enabled_description'.tr()),
            onChanged: (v) => setState(() => _enabled = v),
          ),

          const SizedBox(height: 16),
          SettingGroupTitle(
            title: 'admin.cron_expression'.tr(),
            icon: Icons.schedule,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          _textField(
            label: 'admin.cron_expression'.tr(),
            value: _cronExpression,
            enabled: _enabled,
            onChanged: (v) => _cronExpression = v,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: '$_jitterMinutes')
                    ..selection = TextSelection.collapsed(offset: '$_jitterMinutes'.length),
                  enabled: _enabled,
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 0 && n <= 360) {
                      _jitterMinutes = n;
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'admin.album_generator_jitter_minutes'.tr(),
                    helperText: 'admin.album_generator_jitter_minutes_description'.tr(),
                    helperMaxLines: 3,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: TextEditingController(text: '$_extraRunsPerWeek')
              ..selection = TextSelection.collapsed(offset: '$_extraRunsPerWeek'.length),
            enabled: _enabled,
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n >= 0 && n <= 21) {
                _extraRunsPerWeek = n;
              }
            },
            decoration: InputDecoration(
              labelText: 'admin.album_generator_extra_runs_per_week'.tr(),
              helperText: 'admin.album_generator_extra_runs_per_week_description'.tr(),
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),

          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
          SettingGroupTitle(
            title: 'admin.album_generator_ollama'.tr(),
            subtitle: 'admin.album_generator_ollama_description'.tr(),
            icon: Icons.smart_toy_outlined,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          _textField(
            label: 'admin.album_generator_ollama_endpoint'.tr(),
            value: _ollamaEndpoint,
            enabled: _enabled,
            onChanged: (v) => _ollamaEndpoint = v,
          ),
          const SizedBox(height: 12),
          _textField(
            label: 'admin.album_generator_ollama_text_model'.tr(),
            value: _ollamaTextModel,
            enabled: _enabled,
            onChanged: (v) => _ollamaTextModel = v,
          ),
          const SizedBox(height: 12),
          _textField(
            label: 'admin.album_generator_ollama_vision_model'.tr(),
            value: _ollamaVisionModel,
            enabled: _enabled,
            onChanged: (v) => _ollamaVisionModel = v,
          ),

          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
          SettingGroupTitle(
            title: 'admin.album_generator_theme_vocabulary'.tr(),
            subtitle: 'admin.album_generator_theme_vocabulary_description'.tr(),
            icon: Icons.tag,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _themeController,
            enabled: _enabled,
            maxLines: 6,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),

          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
          SettingGroupTitle(
            title: 'admin.album_generator_audio'.tr(),
            subtitle: 'admin.album_generator_audio_description'.tr(),
            icon: Icons.music_note_outlined,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _audioEnabled,
            title: Text('admin.album_generator_audio_enabled'.tr()),
            onChanged: !_enabled ? null : (v) => setState(() => _audioEnabled = v),
          ),
          const SizedBox(height: 8),
          _textField(
            label: 'admin.album_generator_audio_library_path'.tr(),
            value: _audioLibraryPath,
            enabled: _enabled && _audioEnabled,
            onChanged: (v) => _audioLibraryPath = v,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('admin.album_generator_audio_volume'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge),
                    Text(_audioVolume.toStringAsFixed(2),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Slider(
                  value: _audioVolume.clamp(0.0, 1.0),
                  divisions: 20,
                  label: _audioVolume.toStringAsFixed(2),
                  onChanged: (_enabled && _audioEnabled)
                      ? (v) => setState(() => _audioVolume = v)
                      : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _audioScanSubmitting ? null : _rescanAudio,
            icon: _audioScanSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: Text(
              _audioScanSubmitting
                  ? 'ai_album_generator_audio_scan_submitting'.tr()
                  : 'ai_album_generator_audio_scan_button'.tr(),
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
