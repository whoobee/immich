//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AlbumGeneratorApi {
  AlbumGeneratorApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Retrieve the current user's AI album generator settings
  ///
  /// Returns the opt-in flag, maxPerNight cap, and persistent hint list. Returns sensible defaults for users that have never set these.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getAlbumGeneratorConfigWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final apiPath = r'/album-generator/config';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      apiPath,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Retrieve the current user's AI album generator settings
  ///
  /// Returns the opt-in flag, maxPerNight cap, and persistent hint list. Returns sensible defaults for users that have never set these.
  Future<AlbumGeneratorUserConfigDto?> getAlbumGeneratorConfig({ Future<void>? abortTrigger, }) async {
    final response = await getAlbumGeneratorConfigWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AlbumGeneratorUserConfigDto',) as AlbumGeneratorUserConfigDto;
    
    }
    return null;
  }

  /// Stream the composed AI memory video
  ///
  /// Returns an mp4 stream of the slideshow video generated for an AI memory. Available only after the MemoryVideoCompose job has completed.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  Future<Response> getMemoryAiVideoWithHttpInfo(String id, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final apiPath = r'/album-generator/memories/{id}/video'
      .replaceAll('{id}', id);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      apiPath,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Stream the composed AI memory video
  ///
  /// Returns an mp4 stream of the slideshow video generated for an AI memory. Available only after the MemoryVideoCompose job has completed.
  ///
  /// Parameters:
  ///
  /// * [String] id (required):
  Future<void> getMemoryAiVideo(String id, { Future<void>? abortTrigger, }) async {
    final response = await getMemoryAiVideoWithHttpInfo(id, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Queue an AI scan of the audio library
  ///
  /// Walks the configured audio library, sends each track to the audio-capable Ollama model, and persists mood + scenario tags. Tags then enrich the music picker prompt. Set `force=true` to re-analyse every track even when its sha1 is unchanged.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AlbumGeneratorAudioScanRequestDto] albumGeneratorAudioScanRequestDto (required):
  Future<Response> triggerAudioScanWithHttpInfo(AlbumGeneratorAudioScanRequestDto albumGeneratorAudioScanRequestDto, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final apiPath = r'/album-generator/audio/scan';

    // ignore: prefer_final_locals
    Object? postBody = albumGeneratorAudioScanRequestDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      apiPath,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Queue an AI scan of the audio library
  ///
  /// Walks the configured audio library, sends each track to the audio-capable Ollama model, and persists mood + scenario tags. Tags then enrich the music picker prompt. Set `force=true` to re-analyse every track even when its sha1 is unchanged.
  ///
  /// Parameters:
  ///
  /// * [AlbumGeneratorAudioScanRequestDto] albumGeneratorAudioScanRequestDto (required):
  Future<AlbumGeneratorAudioScanResponseDto?> triggerAudioScan(AlbumGeneratorAudioScanRequestDto albumGeneratorAudioScanRequestDto, { Future<void>? abortTrigger, }) async {
    final response = await triggerAudioScanWithHttpInfo(albumGeneratorAudioScanRequestDto, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AlbumGeneratorAudioScanResponseDto',) as AlbumGeneratorAudioScanResponseDto;
    
    }
    return null;
  }

  /// Queue an on-demand AI memory for a custom hint
  ///
  /// Triggers a one-off generation for the authenticated user. The provided hint is used verbatim — persistent hints, the admin theme vocabulary, the maxPerNight cap, and the recently-used filter are all ignored. The pipeline runs asynchronously; the new memory appears on the Memories page when CLIP search + clustering + LLM + ffmpeg finish (typically 1–3 minutes).
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AlbumGeneratorOnDemandRequestDto] albumGeneratorOnDemandRequestDto (required):
  Future<Response> triggerOnDemandWithHttpInfo(AlbumGeneratorOnDemandRequestDto albumGeneratorOnDemandRequestDto, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final apiPath = r'/album-generator/runs';

    // ignore: prefer_final_locals
    Object? postBody = albumGeneratorOnDemandRequestDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      apiPath,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Queue an on-demand AI memory for a custom hint
  ///
  /// Triggers a one-off generation for the authenticated user. The provided hint is used verbatim — persistent hints, the admin theme vocabulary, the maxPerNight cap, and the recently-used filter are all ignored. The pipeline runs asynchronously; the new memory appears on the Memories page when CLIP search + clustering + LLM + ffmpeg finish (typically 1–3 minutes).
  ///
  /// Parameters:
  ///
  /// * [AlbumGeneratorOnDemandRequestDto] albumGeneratorOnDemandRequestDto (required):
  Future<AlbumGeneratorOnDemandResponseDto?> triggerOnDemand(AlbumGeneratorOnDemandRequestDto albumGeneratorOnDemandRequestDto, { Future<void>? abortTrigger, }) async {
    final response = await triggerOnDemandWithHttpInfo(albumGeneratorOnDemandRequestDto, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AlbumGeneratorOnDemandResponseDto',) as AlbumGeneratorOnDemandResponseDto;
    
    }
    return null;
  }

  /// Update the current user's AI album generator settings
  ///
  /// Set opt-in, max nightly memories, and hint list. Hints are soft directives — they bias both candidate selection (via CLIP search) and the LLM prompt.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [AlbumGeneratorUserConfigDto] albumGeneratorUserConfigDto (required):
  Future<Response> updateAlbumGeneratorConfigWithHttpInfo(AlbumGeneratorUserConfigDto albumGeneratorUserConfigDto, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final apiPath = r'/album-generator/config';

    // ignore: prefer_final_locals
    Object? postBody = albumGeneratorUserConfigDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      apiPath,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Update the current user's AI album generator settings
  ///
  /// Set opt-in, max nightly memories, and hint list. Hints are soft directives — they bias both candidate selection (via CLIP search) and the LLM prompt.
  ///
  /// Parameters:
  ///
  /// * [AlbumGeneratorUserConfigDto] albumGeneratorUserConfigDto (required):
  Future<AlbumGeneratorUserConfigDto?> updateAlbumGeneratorConfig(AlbumGeneratorUserConfigDto albumGeneratorUserConfigDto, { Future<void>? abortTrigger, }) async {
    final response = await updateAlbumGeneratorConfigWithHttpInfo(albumGeneratorUserConfigDto, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AlbumGeneratorUserConfigDto',) as AlbumGeneratorUserConfigDto;
    
    }
    return null;
  }
}
