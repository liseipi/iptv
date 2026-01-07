// lib/screens/player_page.dart (修复版 - 解决导航错误)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/channel.dart';

class PlayerPage extends StatefulWidget {
  final Channel channel;
  final VideoPlayerController? previewController;

  const PlayerPage({
    super.key,
    required this.channel,
    this.previewController,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late VideoPlayerController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showControls = false;
  bool _isUsingPreviewController = false;

  @override
  void initState() {
    super.initState();
    _enterFullScreen();
    _initializePlayer();
  }

  void _initializePlayer() {
    // 优先使用预览控制器
    if (widget.previewController != null &&
        widget.previewController!.value.isInitialized) {

      _controller = widget.previewController!;
      _isUsingPreviewController = true;

      setState(() {
        _isLoading = false;
      });

      // 恢复音量和播放
      _controller.setVolume(1.0);
      if (!_controller.value.isPlaying) {
        _controller.play();
      }

      debugPrint("✅ 播放页面：使用预览控制器，无需重新加载");
      return;
    }

    // 创建新控制器
    debugPrint("⚠️ 播放页面：预览控制器不可用，创建新控制器");
    _isUsingPreviewController = false;

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.channel.url),
    )
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _controller.play();
      }).catchError((error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = error.toString();
        });
        debugPrint("Video Player Error: $error");
      });
  }

  @override
  void dispose() {
    // 🎯 关键：不释放控制器，让预览页面接管
    debugPrint("✅ 播放页面：保留控制器，准备返回");
    super.dispose();
  }

  void _enterFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  // 🎯 准备返回时的控制器
  VideoPlayerController? _prepareControllerForReturn() {
    if (_controller.value.isInitialized) {
      // 降低音量，准备返回预览模式
      _controller.setVolume(0.5);
      debugPrint("✅ 播放页面：准备返回控制器");
      return _controller;
    }
    return null;
  }

  // 🎯 处理返回操作
  void _handleBack() {
    _exitFullScreen();
    final controller = _prepareControllerForReturn();
    Navigator.of(context).pop(controller);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // ✅ 阻止自动弹出，我们手动处理
      onPopInvokedWithResult: (didPop, result) {
        // ✅ 如果已经弹出，只需退出全屏
        if (didPop) {
          _exitFullScreen();
          return;
        }
        // ✅ 如果没有弹出，手动处理返回逻辑
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              // 视频播放器
              Center(
                child: _isLoading
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _isUsingPreviewController
                          ? '正在从预览切换...'
                          : '正在加载...',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                )
                    : _controller.value.isInitialized
                    ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
                    : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '无法播放此频道',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '错误详情: $_errorMessage',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _handleBack,
                        child: const Text('返回'),
                      ),
                    ],
                  ),
                ),
              ),

              // 播放/暂停指示器
              if (!_controller.value.isPlaying &&
                  !_isLoading &&
                  _controller.value.isInitialized)
                Center(
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white.withOpacity(0.7),
                    size: 80,
                  ),
                ),

              // 控制栏
              if (_showControls && _controller.value.isInitialized)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: _handleBack,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.channel.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_isUsingPreviewController)
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 12,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '无缝切换',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}