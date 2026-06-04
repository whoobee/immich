//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AlbumGeneratorOnDemandRequestDto {
  /// Returns a new [AlbumGeneratorOnDemandRequestDto] instance.
  AlbumGeneratorOnDemandRequestDto({
    required this.hint,
  });

  /// Free-form prompt — passed as the lone hint to CLIP search and the LLM story prompt
  String hint;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AlbumGeneratorOnDemandRequestDto &&
    other.hint == hint;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (hint.hashCode);

  @override
  String toString() => 'AlbumGeneratorOnDemandRequestDto[hint=$hint]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'hint'] = this.hint;
    return json;
  }

  /// Returns a new [AlbumGeneratorOnDemandRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AlbumGeneratorOnDemandRequestDto? fromJson(dynamic value) {
    upgradeDto(value, "AlbumGeneratorOnDemandRequestDto");
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      return AlbumGeneratorOnDemandRequestDto(
        hint: mapValueOfType<String>(json, r'hint')!,
      );
    }
    return null;
  }

  static List<AlbumGeneratorOnDemandRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AlbumGeneratorOnDemandRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AlbumGeneratorOnDemandRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AlbumGeneratorOnDemandRequestDto> mapFromJson(dynamic json) {
    final map = <String, AlbumGeneratorOnDemandRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AlbumGeneratorOnDemandRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AlbumGeneratorOnDemandRequestDto-objects as value to a dart map
  static Map<String, List<AlbumGeneratorOnDemandRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AlbumGeneratorOnDemandRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AlbumGeneratorOnDemandRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'hint',
  };
}

