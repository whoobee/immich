//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SystemConfigAlbumGeneratorDto {
  /// Returns a new [SystemConfigAlbumGeneratorDto] instance.
  SystemConfigAlbumGeneratorDto({
    required this.audio,
    required this.cronExpression,
    required this.enabled,
    required this.extraRunsPerWeek,
    required this.jitterMinutes,
    required this.ollama,
    this.themeVocabulary = const [],
  });

  SystemConfigAlbumGeneratorAudioDto audio;

  /// Cron expression
  String cronExpression;

  /// Enabled
  bool enabled;

  /// Additional random firings per week on top of the main cron (0 = disabled)
  ///
  /// Minimum value: 0
  /// Maximum value: 21
  int extraRunsPerWeek;

  /// Forward random delay (minutes) added to each cron firing so memories feel like surprises
  ///
  /// Minimum value: 0
  /// Maximum value: 360
  int jitterMinutes;

  SystemConfigAlbumGeneratorOllamaDto ollama;

  /// Theme keywords fed to searchSmart when discovering memory candidates
  List<String> themeVocabulary;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SystemConfigAlbumGeneratorDto &&
    other.audio == audio &&
    other.cronExpression == cronExpression &&
    other.enabled == enabled &&
    other.extraRunsPerWeek == extraRunsPerWeek &&
    other.jitterMinutes == jitterMinutes &&
    other.ollama == ollama &&
    _deepEquality.equals(other.themeVocabulary, themeVocabulary);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (audio.hashCode) +
    (cronExpression.hashCode) +
    (enabled.hashCode) +
    (extraRunsPerWeek.hashCode) +
    (jitterMinutes.hashCode) +
    (ollama.hashCode) +
    (themeVocabulary.hashCode);

  @override
  String toString() => 'SystemConfigAlbumGeneratorDto[audio=$audio, cronExpression=$cronExpression, enabled=$enabled, extraRunsPerWeek=$extraRunsPerWeek, jitterMinutes=$jitterMinutes, ollama=$ollama, themeVocabulary=$themeVocabulary]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'audio'] = this.audio;
      json[r'cronExpression'] = this.cronExpression;
      json[r'enabled'] = this.enabled;
      json[r'extraRunsPerWeek'] = this.extraRunsPerWeek;
      json[r'jitterMinutes'] = this.jitterMinutes;
      json[r'ollama'] = this.ollama;
      json[r'themeVocabulary'] = this.themeVocabulary;
    return json;
  }

  /// Returns a new [SystemConfigAlbumGeneratorDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SystemConfigAlbumGeneratorDto? fromJson(dynamic value) {
    upgradeDto(value, "SystemConfigAlbumGeneratorDto");
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      return SystemConfigAlbumGeneratorDto(
        audio: SystemConfigAlbumGeneratorAudioDto.fromJson(json[r'audio'])!,
        cronExpression: mapValueOfType<String>(json, r'cronExpression')!,
        enabled: mapValueOfType<bool>(json, r'enabled')!,
        extraRunsPerWeek: mapValueOfType<int>(json, r'extraRunsPerWeek')!,
        jitterMinutes: mapValueOfType<int>(json, r'jitterMinutes')!,
        ollama: SystemConfigAlbumGeneratorOllamaDto.fromJson(json[r'ollama'])!,
        themeVocabulary: json[r'themeVocabulary'] is Iterable
            ? (json[r'themeVocabulary'] as Iterable).cast<String>().toList(growable: false)
            : const [],
      );
    }
    return null;
  }

  static List<SystemConfigAlbumGeneratorDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SystemConfigAlbumGeneratorDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SystemConfigAlbumGeneratorDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SystemConfigAlbumGeneratorDto> mapFromJson(dynamic json) {
    final map = <String, SystemConfigAlbumGeneratorDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SystemConfigAlbumGeneratorDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SystemConfigAlbumGeneratorDto-objects as value to a dart map
  static Map<String, List<SystemConfigAlbumGeneratorDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SystemConfigAlbumGeneratorDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SystemConfigAlbumGeneratorDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'audio',
    'cronExpression',
    'enabled',
    'extraRunsPerWeek',
    'jitterMinutes',
    'ollama',
    'themeVocabulary',
  };
}

