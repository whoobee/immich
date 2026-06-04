import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:native_video_player/native_video_player.dart';

@RoutePage()
class MemoryVideoPlayerPage extends ConsumerStatefulWidget {
  /// Id of the Asset row that holds the composed memory mp4 (server-side
  /// `data.videoAssetId`). Streamed from `<endpoint>/assets/<id>/original`.
  final String videoAssetId;

  /// LLM-picked title shown in the app bar.
  final String? title;

  const MemoryVideoPlayerPage({
    required this.videoAssetId,
    this.title,
    super.key,
  });

  @override
  ConsumerState<MemoryVideoPlayerPage> createState() => _MemoryVideoPlayerPageState();
}

class _MemoryVideoPlayerPageState extends ConsumerState<MemoryVideoPlayerPage> {
  NativeVideoPlayerController? _controller;
  bool _ready = false;
  bool _isPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _initController(NativeVideoPlayerController controller) async {
    _controller = controller;
    final endpoint = Store.tryGet(StoreKey.serverEndpoint);
    if (endpoint == null || endpoint.isEmpty) {
      setState(() => _error = 'No server endpoint configured');
      return;
    }
    final url = '$endpoint/assets/${widget.videoAssetId}/original';
    try {
      await controller.loadVideoSource(
        await VideoSource.init(
          path: url,
          type: VideoSourceType.network,
          headers: ApiService.getRequestHeaders(),
        ),
      );
      controller.onPlaybackReady.addListener(() {
        if (!mounted) {
          return;
        }
        setState(() => _ready = true);
        controller.play();
      });
      controller.onPlaybackStatusChanged.addListener(() {
        if (!mounted) {
          return;
        }
        final status = controller.playbackInfo?.status;
        setState(() => _isPlaying = status == PlaybackStatus.playing);
      });
    } catch (err) {
      if (mounted) {
        setState(() => _error = err.toString());
      }
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (_isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: widget.title != null
            ? Text(widget.title!, overflow: TextOverflow.ellipsis)
            : null,
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  NativeVideoPlayerView(onViewReady: _initController),
                  if (!_ready) const CircularProgressIndicator(),
                  if (_ready)
                    Positioned(
                      bottom: 48,
                      child: IconButton(
                        iconSize: 56,
                        color: Colors.white,
                        icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                        onPressed: _togglePlay,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
