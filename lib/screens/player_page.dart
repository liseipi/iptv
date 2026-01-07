// lib/screens/player_page.dart (添加重试机制 - 最多尝试3次)
import 'dart:async';
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

  // 🎯 新增：重试相关变量
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
    _retryCount = 0; // 重置重试计数

    _attemptInitialize();
  }

  // 🎯 新增：尝试初始化的方法
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

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.channel.url),
    );

    _controller.initialize().then((_) {
      if (!mounted) return;

      // 🎯 成功初始化，重置重试计数
      _retryCount = 0;
      _retryTimer?.cancel();

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      _controller.play();

      debugPrint("✅ 播放页面：初始化成功 ${widget.channel.name}");
    }).catchError((error) {
      if (!mounted) return;

      debugPrint("❌ 播放页面：初始化失败 ${widget.channel.name}: $error");

      // 🎯 初始化失败，触发重试
      _handleInitializationFailure();
    });
  }

  // 🎯 新增：处理初始化失败的方法
  void _handleInitializationFailure() {
    // 检查是否还能重试
    if (_retryCount < _maxRetries) {
      _retryCount++;

      setState(() {
        _isLoading = true;
        _errorMessage = "连接失败，正在重试 ($_retryCount/$_maxRetries)...";
      });

      debugPrint("🔄 播放页面：准备第 $_retryCount 次重试，等待 ${_retryDelay.inSeconds} 秒");

      // 延迟后重试
      _retryTimer?.cancel();
      _retryTimer = Timer(_retryDelay, () {
        if (!mounted) {
          debugPrint("⚠️ 播放页面：重试取消（页面已卸载）");
          return;
        }

        debugPrint("🔄 播放页面：开始第 $_retryCount 次重试");

        // 释放旧控制器
        try {
          _controller.dispose();
        } catch (e) {
          debugPrint('⚠️ 播放页面：释放旧控制器失败: $e');
        }

        _attemptInitialize();
      });
    } else {
      // 达到最大重试次数
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
    _retryTimer?.cancel(); // 取消重试
    final controller = _prepareControllerForReturn();
    Navigator.of(context).pop(controller);
  }

  // 🎯 新增：手动重试方法
  void _manualRetry() {
    _retryCount = 0; // 重置计数，重新开始
    try {
      _controller.dispose();
    } catch (e) {
      debugPrint('⚠️ 播放页面：释放控制器失败: $e');
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
                    // 🎯 显示重试进度
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
                        _errorMessage ?? '未知错误',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 🎯 添加重试按钮
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
                              // 🎯 显示重试信息
                              if (!_isUsingPreviewController && _retryCount > 0)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.refresh,
                                      color: Colors.orange,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '已重试 $_retryCount 次',
                                      style: const TextStyle(
                                        color: Colors.orange,
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