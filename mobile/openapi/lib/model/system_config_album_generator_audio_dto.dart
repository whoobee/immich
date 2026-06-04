//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SystemConfigAlbumGeneratorAudioDto {
  /// Returns a new [SystemConfigAlbumGeneratorAudioDto] instance.
  SystemConfigAlbumGeneratorAudioDto({
    required this.enabled,
    required this.libraryPath,
    required this.volume,
  });

  /// Mix background audio into composed memory videos
  bool enabled;

  /// Server-side directory containing CC0 audio files using the `<tags>__<name>.<ext>` convention
  String libraryPath;

  /// Linear audio gain (0.0–1.0)
  ///
  /// Minimum value: 0
  /// Maximum value: 1
  num volume;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SystemConfigAlbumGeneratorAudioDto &&
    other.enabled == enabled &&
    other.libraryPath == libraryPath &&
    other.volume == volume;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (enabled.hashCode) +
    (libraryPath.hashCode) +
    (volume.hashCode);

  @override
  String toString() => 'SystemConfigAlbumGeneratorAudioDto[enabled=$enabled, libraryPath=$libraryPath, volume=$volume]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'enabled'] = this.enabled;
      json[r'libraryPath'] = this.libraryPath;
      json[r'volume'] = this.volume;
    return json;
  }

  /// Returns a new [SystemConfigAlbumGeneratorAudioDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SystemConfigAlbumGeneratorAudioDto? fromJson(dynamic value) {
    upgradeDto(value, "SystemConfigAlbumGeneratorAudioDto");
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      return SystemConfigAlbumGeneratorAudioDto(
        enabled: mapValueOfType<bool>(json, r'enabled')!,
        libraryPath: mapValueOfType<String>(json, r'libraryPath')!,
        volume: num.parse('${json[r'volume']}'),
      );
    }
    return null;
  }

  static List<SystemConfigAlbumGeneratorAudioDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SystemConfigAlbumGeneratorAudioDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SystemConfigAlbumGeneratorAudioDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SystemConfigAlbumGeneratorAudioDto> mapFromJson(dynamic json) {
    final map = <String, SystemConfigAlbumGeneratorAudioDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SystemConfigAlbumGeneratorAudioDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SystemConfigAlbumGeneratorAudioDto-objects as value to a dart map
  static Map<String, List<SystemConfigAlbumGeneratorAudioDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SystemConfigAlbumGeneratorAudioDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SystemConfigAlbumGeneratorAudioDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'enabled',
    'libraryPath',
    'volume',
  };
}

