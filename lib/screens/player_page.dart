// lib/screens/player_page.dart (修复返回闪退问题)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/channel.dart';

class PlayerPage extends StatefulWidget {
  final Channel channel;
  final VideoPlayerController? previewController;
  final List<Channel> allChannels;
  final int initialIndex;

  const PlayerPage({
    super.key,
    required this.channel,
    this.previewController,
    this.allChannels = const [],
    this.initialIndex = 0,
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

  late int _currentChannelIndex;
  late Channel _currentChannel;

  Timer? _hintTimer;
  bool _showHint = false;
  String _hintText = '';

  // 🎯 标记是否正在返回（防止重复操作）
  bool _isReturning = false;

  @override
  void initState() {
    super.initState();
    _currentChannelIndex = widget.initialIndex;
    _currentChannel = widget.channel;

    // 延迟进入全屏
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _enterFullScreen();
      }
    });

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

      debugPrint("✅ 播放页面：使用预览控制器 + Chewie");
      return;
    }

    debugPrint("⚠️ 播放页面：预览控制器不可用，创建新控制器");
    _isUsingPreviewController = false;
    _retryCount = 0;

    _attemptInitialize();
  }

  void _createChewieController() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      debugPrint("⚠️ VideoPlayerController 未初始化，无法创建 Chewie");
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
                const Text('播放错误', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
    debugPrint("🚀 播放页面：初始化 ${_currentChannel.name} (重试 $_retryCount/$_maxRetries)");

    setState(() {
      _isLoading = true;
      _errorMessage = _retryCount > 0 ? "连接失败，正在重试 ($_retryCount/$_maxRetries)..." : null;
    });

    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(_currentChannel.url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
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

      _retryTimer?.cancel();
      _retryTimer = Timer(_retryDelay, () {
        if (!mounted) return;

        try {
          _videoPlayerController?.dispose();
        } catch (e) {
          debugPrint('⚠️ 释放旧控制器失败: $e');
        }

        _attemptInitialize();
      });
    } else {
      debugPrint("❌ 已达到最大重试次数");
      setState(() {
        _isLoading = false;
        _errorMessage = "连接失败（已重试 $_maxRetries 次）";
      });
    }
  }

  void _switchToPreviousChannel() {
    if (widget.allChannels.isEmpty || _currentChannelIndex <= 0) {
      _showTemporaryHint('已经是第一个频道');
      return;
    }
    _currentChannelIndex--;
    _switchToChannel(_currentChannelIndex);
  }

  void _switchToNextChannel() {
    if (widget.allChannels.isEmpty || _currentChannelIndex >= widget.allChannels.length - 1) {
      _showTemporaryHint('已经是最后一个频道');
      return;
    }
    _currentChannelIndex++;
    _switchToChannel(_currentChannelIndex);
  }

  void _switchToChannel(int index) {
    if (index < 0 || index >= widget.allChannels.length) return;

    final newChannel = widget.allChannels[index];
    debugPrint("🔄 切换到频道 ${newChannel.name} (${index + 1}/${widget.allChannels.length})");

    _showTemporaryHint('${newChannel.name} (${index + 1}/${widget.allChannels.length})');

    _retryTimer?.cancel();
    _retryCount = 0;

    try {
      _chewieController?.dispose();
      _chewieController = null;
    } catch (e) {
      debugPrint('⚠️ 释放 Chewie: $e');
    }

    try {
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
    } catch (e) {
      debugPrint('⚠️ 释放 VideoPlayer: $e');
    }

    setState(() {
      _currentChannel = newChannel;
      _isUsingPreviewController = false;
    });

    _attemptInitialize();
  }

  void _showTemporaryHint(String text) {
    setState(() {
      _hintText = text;
      _showHint = true;
    });

    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showHint = false;
        });
      }
    });
  }

  @override
  void dispose() {
    debugPrint("🗑️ 播放页面 dispose");
    _retryTimer?.cancel();
    _hintTimer?.cancel();
    // 注意：不在这里释放控制器，因为要返回给预览页面
    super.dispose();
  }

  void _enterFullScreen() {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (e) {
      debugPrint("⚠️ 全屏失败: $e");
    }
  }

  void _exitFullScreen() {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (e) {
      debugPrint("⚠️ 退出全屏失败: $e");
    }
  }

  Map<String, dynamic> _prepareReturn() {
    if (_isReturning) {
      debugPrint("⚠️ 已经在返回中");
      return {
        'controller': null,
        'channel': _currentChannel,
      };
    }

    _isReturning = true;
    VideoPlayerController? controllerToReturn;

    try {
      // 先释放 Chewie
      if (_chewieController != null) {
        debugPrint("🔄 释放 Chewie");
        _chewieController?.pause();
        _chewieController?.dispose();
        _chewieController = null;
      }

      // 准备返回 VideoPlayer
      if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        debugPrint("✅ 准备返回控制器");
        _videoPlayerController!.pause();
        _videoPlayerController!.setVolume(0.5);
        controllerToReturn = _videoPlayerController;
        _videoPlayerController = null; // 释放引用
      } else {
        debugPrint("⚠️ 控制器不可用");
      }
    } catch (e) {
      debugPrint("❌ 准备返回失败: $e");
      controllerToReturn = null;
    }

    return {
      'controller': controllerToReturn,
      'channel': _currentChannel,
    };
  }

  void _handleBack() {
    if (_isReturning) {
      debugPrint("⚠️ 重复返回请求，忽略");
      return;
    }

    debugPrint("🔙 处理返回");
    _exitFullScreen();
    _retryTimer?.cancel();
    _hintTimer?.cancel();

    final result = _prepareReturn();
    debugPrint("🔙 返回数据准备完成");

    // 使用 scheduleMicrotask 确保在下一帧执行
    scheduleMicrotask(() {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  void _manualRetry() {
    _retryCount = 0;

    try {
      _chewieController?.dispose();
      _chewieController = null;
    } catch (e) {
      debugPrint('⚠️ 释放 Chewie: $e');
    }

    try {
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
    } catch (e) {
      debugPrint('⚠️ 释放 VideoPlayer: $e');
    }

    _attemptInitialize();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleBack();
        return false; // 阻止默认返回
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _switchToPreviousChannel();
              return KeyEventResult.handled;
            }
            else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _switchToNextChannel();
              return KeyEventResult.handled;
            }
            else if (event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.escape) {
              _handleBack();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
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
                      _errorMessage ?? (_isUsingPreviewController ? '正在从预览切换...' : '正在加载...'),
                      style: TextStyle(color: _retryCount > 0 ? Colors.orange : Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    if (_retryCount > 0) ...[
                      const SizedBox(height: 8),
                      Text('重试 $_retryCount/$_maxRetries', style: const TextStyle(color: Colors.orange, fontSize: 14)),
                    ],
                  ],
                )
                    : _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                    ? Chewie(controller: _chewieController!)
                    : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      const Text('无法播放此频道', style: TextStyle(color: Colors.white, fontSize: 22)),
                      const SizedBox(height: 16),
                      Text(_errorMessage ?? '未知错误', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 16)),
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
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _handleBack,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('返回'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 顶部提示
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showHint ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tv, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _hintText,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 底部提示
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showHint ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                      ),
                    ),
                    child: const Text(
                      '↑ 上一个频道  ↓ 下一个频道  ← 返回',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
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