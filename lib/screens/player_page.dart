// lib/screens/player_page.dart (Chewie 版本 - 更好的音画同步)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
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
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  bool _isLoading = true;
  String? _errorMessage;
  bool _isUsingPreviewController = false;

  // 重试相关变量
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  Timer? _retryTimer;

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

      _videoPlayerController = widget.previewController!;
      _isUsingPreviewController = true;

      setState(() {
        _isLoading = false;
      });

      // 创建 Chewie 控制器
      _createChewieController();

      debugPrint("✅ 播放页面：使用预览控制器 + Chewie");
      return;
    }

    // 创建新控制器
    debugPrint("⚠️ 播放页面：预览控制器不可用，创建新控制器");
    _isUsingPreviewController = false;
    _retryCount = 0;

    _attemptInitialize();
  }

  /// 创建 Chewie 控制器
  void _createChewieController() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      debugPrint("⚠️ VideoPlayerController 未初始化，无法创建 Chewie");
      return;
    }

    try {
      // 先暂停，将播放控制权交给 Chewie，避免音画不同步
      _videoPlayerController!.pause();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,

        // 🎯 播放器配置
        autoPlay: true,
        looping: false,

        // 🎯 UI 配置
        showControls: true,
        showControlsOnInitialize: false,
        controlsSafeAreaMinimum: const EdgeInsets.all(8),

        // 🎯 全屏配置
        allowFullScreen: false, // 已经是全屏页面，禁用 Chewie 的全屏按钮
        allowMuting: true,
        allowPlaybackSpeedChanging: false,

        // 🎯 宽高比
        // aspectRatio: _videoPlayerController!.value.aspectRatio,
        aspectRatio: 16 / 9,

        // 🎯 错误构建器
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  '播放错误',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        },

        // 🎯 占位符构建器
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),

        // 🎯 材质进度条颜色
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blueAccent,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.lightBlue.withOpacity(0.5),
        ),
      );

      // 🎯 关键：确保音量正常
      _videoPlayerController!.setVolume(1.0);

      // autoPlay: true 会自动处理播放，无需手动延迟和调用 play()
      // 这可以解决音画不同步问题
      debugPrint("✅ Chewie 控制器创建完成，将自动播放");

    } catch (e) {
      debugPrint("❌ 创建 Chewie 控制器失败: $e");
      setState(() {
        _errorMessage = "播放器初始化失败";
      });
    }
  }

  void _attemptInitialize() {
    if (_retryCount > 0) {
      debugPrint("🔄 播放页面：第 $_retryCount 次重试 ${widget.channel.name}");
    } else {
      debugPrint("🚀 播放页面：开始初始化 ${widget.channel.name}");
    }

    setState(() {
      _isLoading = true;
      _errorMessage = _retryCount > 0
          ? "连接失败，正在重试 ($_retryCount/$_maxRetries)..."
          : null;
    });

    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.channel.url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false, // 独占音频会话
        allowBackgroundPlayback: false,
      ),
    );

    _videoPlayerController!.initialize().then((_) {
      if (!mounted) return;

      _retryCount = 0;
      _retryTimer?.cancel();

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      // 创建 Chewie 控制器
      _createChewieController();

      debugPrint("✅ 播放页面：初始化成功 ${widget.channel.name}");
    }).catchError((error) {
      if (!mounted) return;

      debugPrint("❌ 播放页面：初始化失败 ${widget.channel.name}: $error");
      _handleInitializationFailure();
    });
  }

  void _handleInitializationFailure() {
    if (_retryCount < _maxRetries) {
      _retryCount++;

      setState(() {
        _isLoading = true;
        _errorMessage = "连接失败，正在重试 ($_retryCount/$_maxRetries)...";
      });

      debugPrint("🔄 播放页面：准备第 $_retryCount 次重试，等待 ${_retryDelay.inSeconds} 秒");

      _retryTimer?.cancel();
      _retryTimer = Timer(_retryDelay, () {
        if (!mounted) {
          debugPrint("⚠️ 播放页面：重试取消（页面已卸载）");
          return;
        }

        debugPrint("🔄  播放页面：开始第 $_retryCount 次重试");

        try {
          _videoPlayerController?.dispose();
        } catch (e) {
          debugPrint('⚠️ 播放页面：释放旧控制器失败: $e');
        }

        _attemptInitialize();
      });
    } else {
      debugPrint("❌ 播放页面：已达到最大重试次数 ($_maxRetries)");

      setState(() {
        _isLoading = false;
        _errorMessage = "连接失败（已重试 $_maxRetries 次）";
      });
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();

    // 🎯 先释放 Chewie 控制器
    _chewieController?.dispose();

    // 🎯 不要立即释放 VideoPlayerController
    // 因为要返回给预览页面
    debugPrint("✅ 播放页面：保留 VideoPlayerController，准备返回");

    super.dispose();
  }

  void _enterFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  VideoPlayerController? _prepareControllerForReturn() {
    if (_videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized) {

      debugPrint("✅ 播放页面：准备返回控制器");

      // 🎯 先释放 Chewie 控制器
      try {
        _chewieController?.pause();
        _chewieController?.dispose();
        _chewieController = null;
      } catch (e) {
        debugPrint("⚠️ 释放 Chewie 控制器失败: $e");
      }

      // 🎯 暂停并降低音量
      try {
        _videoPlayerController!.pause();
        _videoPlayerController!.setVolume(0.5);
      } catch (e) {
        debugPrint("⚠️ 设置控制器失败: $e");
      }

      final controllerToReturn = _videoPlayerController;
      _videoPlayerController = null;

      return controllerToReturn;
    }

    return null;
  }

  void _handleBack() {
    _exitFullScreen();
    _retryTimer?.cancel();
    final controller = _prepareControllerForReturn();
    Navigator.of(context).pop(controller);
  }

  void _manualRetry() {
    _retryCount = 0;

    // 先释放 Chewie
    try {
      _chewieController?.dispose();
      _chewieController = null;
    } catch (e) {
      debugPrint('⚠️ 释放 Chewie 控制器失败: $e');
    }

    // 再释放 VideoPlayer
    try {
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
    } catch (e) {
      debugPrint('⚠️ 释放 VideoPlayer 控制器失败: $e');
    }

    _attemptInitialize();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _exitFullScreen();
          return;
        }
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 🎯 Chewie 播放器
            Center(
              child: _isLoading
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? (_isUsingPreviewController
                        ? '正在从预览切换...'
                        : '正在加载...'),
                    style: TextStyle(
                      color: _retryCount > 0
                          ? Colors.orange
                          : Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_retryCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '重试 $_retryCount/$_maxRetries',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              )
                  : _chewieController != null &&
                  _chewieController!.videoPlayerController.value.isInitialized
                  ? Chewie(controller: _chewieController!)
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
                      _errorMessage ?? '未知错误',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _manualRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _handleBack,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('返回'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
