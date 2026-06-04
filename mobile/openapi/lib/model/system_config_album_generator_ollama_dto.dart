//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SystemConfigAlbumGeneratorOllamaDto {
  /// Returns a new [SystemConfigAlbumGeneratorOllamaDto] instance.
  SystemConfigAlbumGeneratorOllamaDto({
    required this.endpoint,
    required this.textModel,
    required this.visionModel,
  });

  /// Ollama API endpoint
  String endpoint;

  /// Text model used for naming when vision is unavailable
  String textModel;

  /// Vision model used for thumbnail-aware story generation
  String visionModel;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SystemConfigAlbumGeneratorOllamaDto &&
    other.endpoint == endpoint &&
    other.textModel == textModel &&
    other.visionModel == visionModel;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (endpoint.hashCode) +
    (textModel.hashCode) +
    (visionModel.hashCode);

  @override
  String toString() => 'SystemConfigAlbumGeneratorOllamaDto[endpoint=$endpoint, textModel=$textModel, visionModel=$visionModel]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'endpoint'] = this.endpoint;
      json[r'textModel'] = this.textModel;
      json[r'visionModel'] = this.visionModel;
    return json;
  }

  /// Returns a new [SystemConfigAlbumGeneratorOllamaDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SystemConfigAlbumGeneratorOllamaDto? fromJson(dynamic value) {
    upgradeDto(value, "SystemConfigAlbumGeneratorOllamaDto");
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      return SystemConfigAlbumGeneratorOllamaDto(
        endpoint: mapValueOfType<String>(json, r'endpoint')!,
        textModel: mapValueOfType<String>(json, r'textModel')!,
        visionModel: mapValueOfType<String>(json, r'visionModel')!,
      );
    }
    return null;
  }

  static List<SystemConfigAlbumGeneratorOllamaDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SystemConfigAlbumGeneratorOllamaDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SystemConfigAlbumGeneratorOllamaDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SystemConfigAlbumGeneratorOllamaDto> mapFromJson(dynamic json) {
    final map = <String, SystemConfigAlbumGeneratorOllamaDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SystemConfigAlbumGeneratorOllamaDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SystemConfigAlbumGeneratorOllamaDto-objects as value to a dart map
  static Map<String, List<SystemConfigAlbumGeneratorOllamaDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SystemConfigAlbumGeneratorOllamaDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SystemConfigAlbumGeneratorOllamaDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'endpoint',
    'textModel',
    'visionModel',
  };
}

