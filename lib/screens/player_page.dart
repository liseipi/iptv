// lib/screens/player_page.dart (优化版 - 修复画面静止问题)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/channel.dart';

class PlayerPage extends StatefulWidget {
  final Channel channel;
  final List<Channel> channels;
  final int initialIndex;
  final VideoPlayerController? previewController;

  const PlayerPage({
    super.key,
    required this.channel,
    required this.channels,
    required this.initialIndex,
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

  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  Timer? _retryTimer;

  late int _currentIndex;
  late Channel _currentChannel;

  Timer? _switchChannelThrottle;
  static const Duration _switchChannelDelay = Duration(milliseconds: 800);
  bool _isSwitching = false;

  bool _showChannelInfo = false;
  Timer? _hideChannelInfoTimer;

  // 🎯 新增: 监控视频健康状态
  Timer? _healthCheckTimer;
  int _lastVideoFrameCount = 0;
  int _frozenFrameCount = 0;
  static const int _maxFrozenFrames = 3; // 连续3次检测到画面静止就重新加载

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentChannel = widget.channel;
    _enterFullScreen();
    _initializePlayer();
  }

  void _initializePlayer() {
    if (widget.previewController != null &&
        widget.previewController!.value.isInitialized) {

      _videoPlayerController = widget.previewController!;
      _isUsingPreviewController = true;

      setState(() {
        _isLoading = false;
      });

      _createChewieController();
      _startHealthCheck(); // 🎯 启动健康检查

      debugPrint("✅ 播放页面:使用预览控制器 + Chewie");
      return;
    }

    debugPrint("⚠️ 播放页面:预览控制器不可用,创建新控制器");
    _isUsingPreviewController = false;
    _retryCount = 0;

    _attemptInitialize();
  }

  void _createChewieController() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      debugPrint("⚠️ VideoPlayerController 未初始化,无法创建 Chewie");
      return;
    }

    try {
      _videoPlayerController!.pause();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        showControls: true,
        showControlsOnInitialize: false,
        controlsSafeAreaMinimum: const EdgeInsets.all(8),
        allowFullScreen: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: false,
        aspectRatio: 16 / 9,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text('播放错误', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              ],
            ),
          );
        },
        placeholder: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blueAccent,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.lightBlue.withOpacity(0.5),
        ),
      );

      _videoPlayerController!.setVolume(1.0);

      debugPrint("✅ Chewie 控制器创建完成");

    } catch (e) {
      debugPrint("❌ 创建 Chewie 控制器失败: $e");
      setState(() {
        _errorMessage = "播放器初始化失败";
      });
    }
  }

  void _attemptInitialize() {
    if (_retryCount > 0) {
      debugPrint("🔄 播放页面:第 $_retryCount 次重试 ${_currentChannel.name}");
    } else {
      debugPrint("🚀 播放页面:开始初始化 ${_currentChannel.name}");
    }

    setState(() {
      _isLoading = true;
      _errorMessage = _retryCount > 0
          ? "连接失败,正在重试 ($_retryCount/$_maxRetries)..."
          : null;
    });

    // 🎯 优化: 使用更好的 VideoPlayerOptions
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(_currentChannel.url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true, // ✅ 改为 true,允许与其他音频混合
        allowBackgroundPlayback: false,
      ),
      // 🎯 新增: HTTP 请求头,某些直播源需要
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
        'Connection': 'keep-alive',
      },
    );

    _videoPlayerController!.initialize().then((_) {
      if (!mounted) return;

      _retryCount = 0;
      _retryTimer?.cancel();

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      _createChewieController();
      _startHealthCheck(); // 🎯 启动健康检查

      debugPrint("✅ 播放页面:初始化成功 ${_currentChannel.name}");
    }).catchError((error) {
      if (!mounted) return;

      debugPrint("❌ 播放页面:初始化失败 ${_currentChannel.name}: $error");
      _handleInitializationFailure();
    });
  }

  // 🎯 新增: 视频健康检查(检测画面是否静止)
  void _startHealthCheck() {
    _stopHealthCheck();

    _healthCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || _videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
        timer.cancel();
        return;
      }

      // 检查视频是否在播放
      if (!_videoPlayerController!.value.isPlaying) {
        _frozenFrameCount = 0;
        return;
      }

      // 🎯 关键检测: 检查视频位置是否在变化
      final currentPosition = _videoPlayerController!.value.position.inMilliseconds;

      // 如果位置没有变化(画面可能静止了)
      if (currentPosition == _lastVideoFrameCount && currentPosition > 0) {
        _frozenFrameCount++;
        debugPrint("⚠️ 检测到画面可能静止 (计数: $_frozenFrameCount/$_maxFrozenFrames)");

        if (_frozenFrameCount >= _maxFrozenFrames) {
          debugPrint("❌ 画面静止超过阈值,尝试重新加载");
          _handleFrozenVideo();
        }
      } else {
        // 画面正常,重置计数
        if (_frozenFrameCount > 0) {
          debugPrint("✅ 画面恢复正常");
        }
        _frozenFrameCount = 0;
        _lastVideoFrameCount = currentPosition;
      }
    });
  }

  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _frozenFrameCount = 0;
    _lastVideoFrameCount = 0;
  }

  // 🎯 新增: 处理画面静止的情况
  void _handleFrozenVideo() {
    debugPrint("🔄 尝试修复画面静止问题...");

    _stopHealthCheck();
    _frozenFrameCount = 0;

    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      // 方法1: 先尝试暂停再播放(轻量级修复)
      try {
        final currentPosition = _videoPlayerController!.value.position;
        _videoPlayerController!.pause();

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _videoPlayerController != null) {
            _videoPlayerController!.seekTo(currentPosition);
            _videoPlayerController!.play();
            _startHealthCheck();
            debugPrint("✅ 尝试通过暂停/播放修复画面");
          }
        });
      } catch (e) {
        debugPrint("⚠️ 暂停/播放修复失败: $e,尝试完全重新加载");
        _forceReloadVideo();
      }
    } else {
      _forceReloadVideo();
    }
  }

  // 🎯 新增: 强制重新加载视频
  void _forceReloadVideo() {
    debugPrint("🔄 强制重新加载视频...");

    _showToast("视频异常,正在重新加载...");

    // 释放 Chewie
    try {
      _chewieController?.dispose();
      _chewieController = null;
    } catch (e) {
      debugPrint("⚠️ 释放 Chewie 失败: $e");
    }

    // 释放 VideoPlayer
    try {
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
    } catch (e) {
      debugPrint("⚠️ 释放 VideoPlayer 失败: $e");
    }

    _retryCount = 0;
    _isUsingPreviewController = false;

    // 延迟后重新初始化
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _attemptInitialize();
      }
    });
  }

  void _handleInitializationFailure() {
    if (_retryCount < _maxRetries) {
      _retryCount++;

      setState(() {
        _isLoading = true;
        _errorMessage = "连接失败,正在重试 ($_retryCount/$_maxRetries)...";
      });

      debugPrint("🔄 播放页面:准备第 $_retryCount 次重试,等待 ${_retryDelay.inSeconds} 秒");

      _retryTimer?.cancel();
      _retryTimer = Timer(_retryDelay, () {
        if (!mounted) {
          debugPrint("⚠️ 播放页面:重试取消(页面已卸载)");
          return;
        }

        debugPrint("🔄  播放页面:开始第 $_retryCount 次重试");

        try {
          _videoPlayerController?.dispose();
        } catch (e) {
          debugPrint('⚠️ 播放页面:释放旧控制器失败: $e');
        }

        _attemptInitialize();
      });
    } else {
      debugPrint("❌ 播放页面:已达到最大重试次数 ($_maxRetries)");

      setState(() {
        _isLoading = false;
        _errorMessage = "连接失败(已重试 $_maxRetries 次)";
      });
    }
  }

  void _switchToPreviousChannel() {
    if (_isSwitching) {
      debugPrint("⚠️ 播放页面:正在切换频道,忽略操作");
      return;
    }

    if (_currentIndex <= 0) {
      debugPrint("⚠️ 播放页面:已经是第一个频道");
      _showToast("已经是第一个频道");
      return;
    }

    _currentIndex--;
    _switchToChannel(_currentIndex);
  }

  void _switchToNextChannel() {
    if (_isSwitching) {
      debugPrint("⚠️ 播放页面:正在切换频道,忽略操作");
      return;
    }

    if (_currentIndex >= widget.channels.length - 1) {
      debugPrint("⚠️ 播放页面:已经是最后一个频道");
      _showToast("已经是最后一个频道");
      return;
    }

    _currentIndex++;
    _switchToChannel(_currentIndex);
  }

  void _switchToChannel(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.channels.length) {
      debugPrint("⚠️ 播放页面:索引越界 $newIndex");
      return;
    }

    final newChannel = widget.channels[newIndex];

    _switchChannelThrottle?.cancel();
    _stopHealthCheck(); // 🎯 停止健康检查

    setState(() {
      _showChannelInfo = true;
      _currentChannel = newChannel;
    });

    _hideChannelInfoTimer?.cancel();
    _hideChannelInfoTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showChannelInfo = false;
        });
      }
    });

    debugPrint("🔄 播放页面:准备切换到 ${newChannel.name} (索引: $newIndex)");

    _switchChannelThrottle = Timer(_switchChannelDelay, () {
      if (!mounted) return;

      debugPrint("✅ 播放页面:开始切换频道到 ${newChannel.name}");

      _isSwitching = true;

      try {
        _chewieController?.pause();
        _chewieController?.dispose();
        _chewieController = null;
      } catch (e) {
        debugPrint("⚠️ 释放 Chewie 控制器失败: $e");
      }

      try {
        _videoPlayerController?.dispose();
        _videoPlayerController = null;
      } catch (e) {
        debugPrint('⚠️ 释放 VideoPlayer 控制器失败: $e');
      }

      _retryCount = 0;
      _isUsingPreviewController = false;

      _attemptInitialize();

      _isSwitching = false;
    });
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
      ),
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _switchChannelThrottle?.cancel();
    _hideChannelInfoTimer?.cancel();
    _stopHealthCheck(); // 🎯 停止健康检查

    _chewieController?.dispose();

    debugPrint("✅ 播放页面:保留 VideoPlayerController,准备返回");

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

      debugPrint("✅ 播放页面:准备返回控制器");

      _stopHealthCheck(); // 🎯 停止健康检查

      try {
        _chewieController?.pause();
        _chewieController?.dispose();
        _chewieController = null;
      } catch (e) {
        debugPrint("⚠️ 释放 Chewie 控制器失败: $e");
      }

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
    _switchChannelThrottle?.cancel();
    _hideChannelInfoTimer?.cancel();
    _stopHealthCheck(); // 🎯 停止健康检查

    final controller = _prepareControllerForReturn();

    Navigator.of(context).pop({
      'controller': controller,
      'lastChannel': _currentChannel,
    });
  }

  void _manualRetry() {
    _retryCount = 0;
    _stopHealthCheck(); // 🎯 停止健康检查

    try {
      _chewieController?.dispose();
      _chewieController = null;
    } catch (e) {
      debugPrint('⚠️ 释放 Chewie 控制器失败: $e');
    }

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
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const _PreviousChannelIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const _NextChannelIntent(),
          // 🎯 新增: R键强制重新加载(调试用)
          LogicalKeySet(LogicalKeyboardKey.keyR): const _ForceReloadIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _PreviousChannelIntent: CallbackAction<_PreviousChannelIntent>(
              onInvoke: (_) {
                _switchToPreviousChannel();
                return null;
              },
            ),
            _NextChannelIntent: CallbackAction<_NextChannelIntent>(
              onInvoke: (_) {
                _switchToNextChannel();
                return null;
              },
            ),
            _ForceReloadIntent: CallbackAction<_ForceReloadIntent>(
              onInvoke: (_) {
                _forceReloadVideo();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
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

                  if (_showChannelInfo)
                    Positioned(
                      top: 40,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.tv,
                                    color: Colors.blue,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _currentChannel.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '频道 ${_currentIndex + 1}/${widget.channels.length}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviousChannelIntent extends Intent {
  const _PreviousChannelIntent();
}

class _NextChannelIntent extends Intent {
  const _NextChannelIntent();
}

// 🎯 新增
class _ForceReloadIntent extends Intent {
  const _ForceReloadIntent();
}