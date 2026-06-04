//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AlbumGeneratorAudioScanResponseDto {
  /// Returns a new [AlbumGeneratorAudioScanResponseDto] instance.
  AlbumGeneratorAudioScanResponseDto({
    required this.queued,
  });

  /// Scan job accepted; check server logs / settings for progress
  bool queued;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AlbumGeneratorAudioScanResponseDto &&
    other.queued == queued;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (queued.hashCode);

  @override
  String toString() => 'AlbumGeneratorAudioScanResponseDto[queued=$queued]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'queued'] = this.queued;
    return json;
  }

  /// Returns a new [AlbumGeneratorAudioScanResponseDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AlbumGeneratorAudioScanResponseDto? fromJson(dynamic value) {
    upgradeDto(value, "AlbumGeneratorAudioScanResponseDto");
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      return AlbumGeneratorAudioScanResponseDto(
        queued: mapValueOfType<bool>(json, r'queued')!,
      );
    }
    return null;
  }

  static List<AlbumGeneratorAudioScanResponseDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AlbumGeneratorAudioScanResponseDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AlbumGeneratorAudioScanResponseDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AlbumGeneratorAudioScanResponseDto> mapFromJson(dynamic json) {
    final map = <String, AlbumGeneratorAudioScanResponseDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AlbumGeneratorAudioScanResponseDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AlbumGeneratorAudioScanResponseDto-objects as value to a dart map
  static Map<String, List<AlbumGeneratorAudioScanResponseDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AlbumGeneratorAudioScanResponseDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AlbumGeneratorAudioScanResponseDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'queued',
  };
}

