import 'dart:async';

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
  bool _muted = false;
  int _positionMs = 0;
  int _durationMs = 0;
  bool _showControls = true;
  bool _scrubbing = false;
  Timer? _hideTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _scrubbing) {
        return;
      }
      setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _scheduleHide();
    }
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
      controller.onPlaybackReady.addListener(_onReady);
      controller.onPlaybackStatusChanged.addListener(_onStatus);
      controller.onPlaybackPositionChanged.addListener(_onPosition);
      controller.onPlaybackEnded.addListener(_onEnded);
    } catch (err) {
      if (mounted) {
        setState(() => _error = err.toString());
      }
    }
  }

  Future<void> _onReady() async {
    if (!mounted) {
      return;
    }
    final controller = _controller!;
    // Native player defaults to volume=0 on every load — without this the
    // composed video plays back silently even though the mp4 has audio.
    await controller.setVolume(1.0);
    final info = controller.videoInfo;
    setState(() {
      _ready = true;
      _durationMs = info?.duration ?? 0;
    });
    await controller.play();
  }

  void _onStatus() {
    if (!mounted) {
      return;
    }
    final status = _controller?.playbackInfo?.status;
    setState(() => _isPlaying = status == PlaybackStatus.playing);
  }

  void _onPosition() {
    if (!mounted || _scrubbing) {
      return;
    }
    final pos = _controller?.playbackInfo?.position ?? 0;
    setState(() => _positionMs = pos);
  }

  void _onEnded() {
    if (!mounted) {
      return;
    }
    setState(() {
      _isPlaying = false;
      _showControls = true;
    });
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (_isPlaying) {
      await controller.pause();
    } else {
      // Replay from the start if we're at the end.
      if (_durationMs > 0 && _positionMs >= _durationMs - 200) {
        await controller.seekTo(0);
      }
      await controller.play();
    }
    _scheduleHide();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final next = !_muted;
    await controller.setVolume(next ? 0.0 : 1.0);
    setState(() => _muted = next);
    _scheduleHide();
  }

  String _fmt(int ms) {
    final s = (ms ~/ 1000).clamp(0, 1 << 31);
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              foregroundColor: Colors.white,
              elevation: 0,
              title: widget.title != null
                  ? Text(widget.title!, overflow: TextOverflow.ellipsis)
                  : null,
            )
          : null,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              )
            else
              // The native player is a platform view that swallows touches
              // before the parent GestureDetector sees them — IgnorePointer
              // lets taps fall through so we can toggle the controls overlay.
              IgnorePointer(
                child: NativeVideoPlayerView(onViewReady: _initController),
              ),

            if (_error == null && !_ready) const CircularProgressIndicator(),

            // Center play / pause hint.
            if (_ready && _showControls)
              IconButton(
                iconSize: 80,
                color: Colors.white,
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                onPressed: _togglePlay,
              ),

            if (_ready && _showControls)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ControlsBar(
                  positionMs: _positionMs,
                  durationMs: _durationMs,
                  muted: _muted,
                  fmt: _fmt,
                  onScrubStart: () => setState(() => _scrubbing = true),
                  onScrubChanged: (ms) => setState(() => _positionMs = ms),
                  onScrubEnd: (ms) async {
                    await _controller?.seekTo(ms);
                    setState(() => _scrubbing = false);
                    _scheduleHide();
                  },
                  onToggleMute: _toggleMute,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ControlsBar extends StatelessWidget {
  const _ControlsBar({
    required this.positionMs,
    required this.durationMs,
    required this.muted,
    required this.fmt,
    required this.onScrubStart,
    required this.onScrubChanged,
    required this.onScrubEnd,
    required this.onToggleMute,
  });

  final int positionMs;
  final int durationMs;
  final bool muted;
  final String Function(int) fmt;
  final VoidCallback onScrubStart;
  final ValueChanged<int> onScrubChanged;
  final ValueChanged<int> onScrubEnd;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    final maxV = durationMs > 0 ? durationMs.toDouble() : 1.0;
    final value = positionMs.toDouble().clamp(0.0, maxV);
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewPaddingOf(context).bottom + 8,
        top: 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: Row(
        children: [
          Text(fmt(positionMs), style: const TextStyle(color: Colors.white, fontVariations: [FontVariation('wght', 500)])),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
              ),
              child: Slider(
                min: 0,
                max: maxV,
                value: value,
                onChangeStart: (_) => onScrubStart(),
                onChanged: (v) => onScrubChanged(v.toInt()),
                onChangeEnd: (v) => onScrubEnd(v.toInt()),
              ),
            ),
          ),
          Text(fmt(durationMs), style: const TextStyle(color: Colors.white)),
          IconButton(
            color: Colors.white,
            icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
            onPressed: onToggleMute,
            tooltip: muted ? 'Unmute' : 'Mute',
          ),
        ],
      ),
    );
  }
}
