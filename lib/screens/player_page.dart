// lib/screens/player_page.dart (支持频道切换 + 节流控制)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/channel.dart';

class PlayerPage extends StatefulWidget {
  final Channel channel;
  final List<Channel> channels; // 🎯 新增：频道列表
  final int initialIndex; // 🎯 新增：初始索引
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

  // 重试相关变量
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  Timer? _retryTimer;

  // 🎯 新增：频道切换相关
  late int _currentIndex;
  late Channel _currentChannel;

  // 🎯 新增：节流控制
  Timer? _switchChannelThrottle;
  static const Duration _switchChannelDelay = Duration(milliseconds: 800);
  bool _isSwitching = false;

  // 🎯 新增：频道切换提示
  bool _showChannelInfo = false;
  Timer? _hideChannelInfoTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentChannel = widget.channel;
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
      debugPrint("🔄 播放页面：第 $_retryCount 次重试 ${_currentChannel.name}");
    } else {
      debugPrint("🚀 播放页面：开始初始化 ${_currentChannel.name}");
    }

    setState(() {
      _isLoading = true;
      _errorMessage = _retryCount > 0
          ? "连接失败，正在重试 ($_retryCount/$_maxRetries)..."
          : null;
    });

    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(_currentChannel.url),
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

      debugPrint("✅ 播放页面：初始化成功 ${_currentChannel.name}");
    }).catchError((error) {
      if (!mounted) return;

      debugPrint("❌ 播放页面：初始化失败 ${_currentChannel.name}: $error");
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

  // 🎯 新增：切换到上一个频道
  void _switchToPreviousChannel() {
    if (_isSwitching) {
      debugPrint("⚠️ 播放页面：正在切换频道，忽略操作");
      return;
    }

    if (_currentIndex <= 0) {
      debugPrint("⚠️ 播放页面：已经是第一个频道");
      _showToast("已经是第一个频道");
      return;
    }

    _currentIndex--;
    _switchToChannel(_currentIndex);
  }

  // 🎯 新增：切换到下一个频道
  void _switchToNextChannel() {
    if (_isSwitching) {
      debugPrint("⚠️ 播放页面：正在切换频道，忽略操作");
      return;
    }

    if (_currentIndex >= widget.channels.length - 1) {
      debugPrint("⚠️ 播放页面：已经是最后一个频道");
      _showToast("已经是最后一个频道");
      return;
    }

    _currentIndex++;
    _switchToChannel(_currentIndex);
  }

  // 🎯 新增：切换频道的核心逻辑（带节流）
  void _switchToChannel(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.channels.length) {
      debugPrint("⚠️ 播放页面：索引越界 $newIndex");
      return;
    }

    final newChannel = widget.channels[newIndex];

    // 🎯 节流控制：取消之前的切换定时器
    _switchChannelThrottle?.cancel();

    // 🎯 显示频道信息
    setState(() {
      _showChannelInfo = true;
      _currentChannel = newChannel;
    });

    // 🎯 自动隐藏频道信息
    _hideChannelInfoTimer?.cancel();
    _hideChannelInfoTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showChannelInfo = false;
        });
      }
    });

    debugPrint("🔄 播放页面：准备切换到 ${newChannel.name} (索引: $newIndex)");

    // 🎯 节流：延迟执行切换
    _switchChannelThrottle = Timer(_switchChannelDelay, () {
      if (!mounted) return;

      debugPrint("✅ 播放页面：开始切换频道到 ${newChannel.name}");

      _isSwitching = true;

      // 释放旧的 Chewie 控制器
      try {
        _chewieController?.pause();
        _chewieController?.dispose();
        _chewieController = null;
      } catch (e) {
        debugPrint("⚠️ 释放 Chewie 控制器失败: $e");
      }

      // 释放旧的 VideoPlayer 控制器
      try {
        _videoPlayerController?.dispose();
        _videoPlayerController = null;
      } catch (e) {
        debugPrint('⚠️ 释放 VideoPlayer 控制器失败: $e');
      }

      // 重置状态
      _retryCount = 0;
      _isUsingPreviewController = false;

      // 初始化新频道
      _attemptInitialize();

      _isSwitching = false;
    });
  }

  // 🎯 新增：显示提示消息
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
    _switchChannelThrottle?.cancel();
    _hideChannelInfoTimer?.cancel();

    final controller = _prepareControllerForReturn();

    // 🎯 返回控制器和当前频道信息
    Navigator.of(context).pop({
      'controller': controller,
      'lastChannel': _currentChannel,
    });
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
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          // 🎯 新增：上下键切换频道
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const _PreviousChannelIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const _NextChannelIntent(),
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
          },
          child: Focus(
            autofocus: true,
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

                  // 🎯 新增：频道信息提示（切换时显示）
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

// 🎯 新增：Intent 定义
class _PreviousChannelIntent extends Intent {
  const _PreviousChannelIntent();
}

class _NextChannelIntent extends Intent {
  const _NextChannelIntent();
}