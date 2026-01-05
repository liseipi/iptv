// lib/widgets/preview_pane.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/channel.dart';

class PreviewPane extends StatefulWidget {
  final Channel? channel;

  const PreviewPane({super.key, this.channel});

  @override
  State<PreviewPane> createState() => PreviewPaneState(); // 修改这里
}

// 去掉下划线，改为公开类
class PreviewPaneState extends State<PreviewPane> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Timer? _debounce;
  Channel? _currentChannel;
  bool _isInitializing = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentChannel = widget.channel;
    _initializePlayerForChannel(widget.channel);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed && !_isPaused) {
      _controller?.play();
    }
  }

  @override
  void didUpdateWidget(PreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channel != null && widget.channel!.url != oldWidget.channel?.url) {
      _debounce?.cancel();
      final controllerToDispose = _controller;

      setState(() {
        _controller = null;
        _isInitializing = true;
      });

      _debounce = Timer(const Duration(milliseconds: 300), () {
        controllerToDispose?.dispose();

        if (mounted && !_isPaused) {
          setState(() {
            _currentChannel = widget.channel;
          });
          _initializePlayerForChannel(widget.channel);
        }
      });
    }
  }

  void _initializePlayerForChannel(Channel? channel) {
    if (channel == null || !mounted || _isPaused) return;

    setState(() {
      _isInitializing = true;
    });

    final oldController = _controller;
    final newController = VideoPlayerController.networkUrl(
      Uri.parse(channel.url),
    );
    _controller = newController;

    newController.initialize().then((_) {
      if (!mounted) {
        newController.dispose();
        return;
      }

      if (newController == _controller && !_isPaused) {
        setState(() {
          _isInitializing = false;
        });
        newController.play();
        newController.setVolume(0.5);
        oldController?.dispose();
      } else {
        newController.dispose();
      }
    }).catchError((e) {
      print("Preview Player Error for ${channel.name}: $e");

      if (!mounted) {
        newController.dispose();
        return;
      }

      if (newController == _controller) {
        setState(() {
          _controller = null;
          _isInitializing = false;
        });
        oldController?.dispose();
      } else {
        newController.dispose();
      }
    });
  }

  // 公开方法：暂停预览
  void pausePreview() {
    _isPaused = true;
    _controller?.pause();
  }

  // 公开方法：恢复预览
  void resumePreview() {
    _isPaused = false;
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.play();
    } else if (_currentChannel != null) {
      _initializePlayerForChannel(_currentChannel);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _buildVideoWidget(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_currentChannel != null) ...[
              Text(
                _currentChannel!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "分类: ${_currentChannel!.groupTitle}",
                maxLines: 1,
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _isPaused
                    ? "预览已暂停"
                    : _isInitializing
                    ? "正在加载..."
                    : "预览播放中",
                maxLines: 1,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoWidget() {
    if (_isPaused) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pause_circle_outline, size: 64, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              "预览已暂停",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "正在加载预览...",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_controller != null && _controller!.value.isInitialized) {
      return VideoPlayer(_controller!);
    }

    if (_currentChannel == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_off, size: 64, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              "无预览",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            "加载失败",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}