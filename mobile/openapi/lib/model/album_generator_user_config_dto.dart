//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AlbumGeneratorUserConfigDto {
  /// Returns a new [AlbumGeneratorUserConfigDto] instance.
  AlbumGeneratorUserConfigDto({
    this.hints = const [],
    required this.maxPerNight,
    required this.optIn,
  });

  /// Soft directives passed to the LLM and used as searchSmart queries when discovering memory candidates
  List<String> hints;

  /// Maximum number of AI memories to create for this user per nightly run
  ///
  /// Minimum value: 1
  /// Maximum value: 10
  int maxPerNight;

  /// Whether this user opts into nightly AI memory generation
  bool optIn;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AlbumGeneratorUserConfigDto &&
    _deepEquality.equals(other.hints, hints) &&
    other.maxPerNight == maxPerNight &&
    other.optIn == optIn;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (hints.hashCode) +
    (maxPerNight.hashCode) +
    (optIn.hashCode);

  @override
  String toString() => 'AlbumGeneratorUserConfigDto[hints=$hints, maxPerNight=$maxPerNight, optIn=$optIn]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'hints'] = this.hints;
      json[r'maxPerNight'] = this.maxPerNight;
      json[r'optIn'] = this.optIn;
    return json;
  }

  /// Returns a new [AlbumGeneratorUserConfigDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AlbumGeneratorUserConfigDto? fromJson(dynamic value) {
    upgradeDto(value, "AlbumGeneratorUserConfigDto");
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      return AlbumGeneratorUserConfigDto(
        hints: json[r'hints'] is Iterable
            ? (json[r'hints'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        maxPerNight: mapValueOfType<int>(json, r'maxPerNight')!,
        optIn: mapValueOfType<bool>(json, r'optIn')!,
      );
    }
    return null;
  }

  static List<AlbumGeneratorUserConfigDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AlbumGeneratorUserConfigDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AlbumGeneratorUserConfigDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AlbumGeneratorUserConfigDto> mapFromJson(dynamic json) {
    final map = <String, AlbumGeneratorUserConfigDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AlbumGeneratorUserConfigDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AlbumGeneratorUserConfigDto-objects as value to a dart map
  static Map<String, List<AlbumGeneratorUserConfigDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AlbumGeneratorUserConfigDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AlbumGeneratorUserConfigDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'hints',
    'maxPerNight',
    'optIn',
  };
}

