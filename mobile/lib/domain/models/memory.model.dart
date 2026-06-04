// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';

enum MemoryTypeEnum {
  // Stored as IntColumn via drift's intEnum<MemoryTypeEnum>() — preserve order
  // and only append new values, otherwise existing rows are misinterpreted.
  onThisDay,
  aiStory,
}

class MemoryData {
  /// Set for `onThisDay` memories; null for AI stories.
  final int? year;

  /// Set for AI-generated stories — the LLM-picked title.
  final String? title;

  /// Set for AI-generated stories — the LLM-written narrative.
  final String? story;

  /// Set for AI-generated stories — id of the composed mp4 promoted to a
  /// real Asset row server-side. Drives the in-app video player.
  final String? videoAssetId;

  const MemoryData({this.year, this.title, this.story, this.videoAssetId});

  MemoryData copyWith({int? year, String? title, String? story, String? videoAssetId}) {
    return MemoryData(
      year: year ?? this.year,
      title: title ?? this.title,
      story: story ?? this.story,
      videoAssetId: videoAssetId ?? this.videoAssetId,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (year != null) 'year': year,
      if (title != null) 'title': title,
      if (story != null) 'story': story,
      if (videoAssetId != null) 'videoAssetId': videoAssetId,
    };
  }

  factory MemoryData.fromMap(Map<String, dynamic> map) {
    return MemoryData(
      year: map['year'] is int ? map['year'] as int : null,
      title: map['title'] is String ? map['title'] as String : null,
      story: map['story'] is String ? map['story'] as String : null,
      videoAssetId: map['videoAssetId'] is String ? map['videoAssetId'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory MemoryData.fromJson(String source) {
    try {
      final decoded = json.decode(source);
      if (decoded is Map<String, dynamic>) {
        return MemoryData.fromMap(decoded);
      }
    } catch (_) {
      // Fall through to a safe empty value rather than crashing the whole
      // memory load over one malformed row.
    }
    return const MemoryData();
  }

  @override
  String toString() => 'MemoryData(year: $year, title: $title)';

  @override
  bool operator ==(covariant MemoryData other) {
    if (identical(this, other)) {
      return true;
    }

    return other.year == year &&
        other.title == title &&
        other.story == story &&
        other.videoAssetId == videoAssetId;
  }

  @override
  int get hashCode => year.hashCode ^ title.hashCode ^ story.hashCode ^ videoAssetId.hashCode;
}

// Model for a memory stored in the server
class DriftMemory {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String ownerId;

  // enum
  final MemoryTypeEnum type;
  final MemoryData data;
  final bool isSaved;
  final DateTime memoryAt;
  final DateTime? seenAt;
  final DateTime? showAt;
  final DateTime? hideAt;
  final List<RemoteAsset> assets;

  const DriftMemory({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.ownerId,
    required this.type,
    required this.data,
    required this.isSaved,
    required this.memoryAt,
    this.seenAt,
    this.showAt,
    this.hideAt,
    required this.assets,
  });

  DriftMemory copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? ownerId,
    MemoryTypeEnum? type,
    MemoryData? data,
    bool? isSaved,
    DateTime? memoryAt,
    DateTime? seenAt,
    DateTime? showAt,
    DateTime? hideAt,
    List<RemoteAsset>? assets,
  }) {
    return DriftMemory(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ownerId: ownerId ?? this.ownerId,
      type: type ?? this.type,
      data: data ?? this.data,
      isSaved: isSaved ?? this.isSaved,
      memoryAt: memoryAt ?? this.memoryAt,
      seenAt: seenAt ?? this.seenAt,
      showAt: showAt ?? this.showAt,
      hideAt: hideAt ?? this.hideAt,
      assets: assets ?? this.assets,
    );
  }

  @override
  String toString() {
    return '''Memory {
    id: $id,
    createdAt: $createdAt,
    updatedAt: $updatedAt,
    deletedAt: ${deletedAt ?? "<NA>"},
    ownerId: $ownerId,
    type: $type,
    data: $data,
    isSaved: $isSaved,
    memoryAt: $memoryAt,
    seenAt: ${seenAt ?? "<NA>"},
    showAt: ${showAt ?? "<NA>"},
    hideAt: ${hideAt ?? "<NA>"},
    assets: $assets
}''';
  }

  @override
  bool operator ==(covariant DriftMemory other) {
    if (identical(this, other)) {
      return true;
    }
    final listEquals = const DeepCollectionEquality().equals;

    return other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt &&
        other.ownerId == ownerId &&
        other.type == type &&
        other.data == data &&
        other.isSaved == isSaved &&
        other.memoryAt == memoryAt &&
        other.seenAt == seenAt &&
        other.showAt == showAt &&
        other.hideAt == hideAt &&
        listEquals(other.assets, assets);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        deletedAt.hashCode ^
        ownerId.hashCode ^
        type.hashCode ^
        data.hashCode ^
        isSaved.hashCode ^
        memoryAt.hashCode ^
        seenAt.hashCode ^
        showAt.hashCode ^
        hideAt.hashCode ^
        assets.hashCode;
  }
}
