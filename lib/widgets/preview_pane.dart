// lib/widgets/preview_pane.dart (Chewie 可选版本 - 预览面板保持轻量)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/channel.dart';

/// 🎯 说明：预览面板继续使用 VideoPlayer 保持轻量
/// 只在播放页面使用 Chewie 以获得更好的音画同步
///
/// 如果想在预览面板也使用 Chewie，参考播放页面的实现

class PreviewPane extends StatefulWidget {
  final Channel? channel;

  const PreviewPane({super.key, this.channel});

  @override
  State<PreviewPane> createState() => PreviewPaneState();
}

class PreviewPaneState extends State<PreviewPane> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Timer? _debounce;
  Timer? _initTimeout;
  Channel? _currentChannel;
  bool _isInitializing = false;
  bool _isPaused = false;
  String? _errorMessage;
  int _controllerVersion = 0;

  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  Timer? _retryTimer;

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

    if (widget.channel != null &&
        widget.channel!.url != oldWidget.channel?.url) {
      _switchChannel(widget.channel!);
    }
  }

  void _switchChannel(Channel newChannel) {
    debugPrint("🔄 预览面板：开始切换频道 ${newChannel.name}");

    _debounce?.cancel();
    _initTimeout?.cancel();
    _retryTimer?.cancel();

    _retryCount = 0;
    _controllerVersion++;
    final currentVersion = _controllerVersion;

    final oldController = _controller;

    setState(() {
      _controller = null;
      _isInitializing = true;
      _errorMessage = null;
      _currentChannel = newChannel;
    });

    if (oldController != null) {
      _disposeControllerSafely(oldController);
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (currentVersion != _controllerVersion) {
        debugPrint("⚠️ 预览面板：操作已过期，跳过初始化");
        return;
      }

      if (mounted && !_isPaused) {
        _initializePlayerForChannel(newChannel, currentVersion);
      }
    });
  }

  void _disposeControllerSafely(VideoPlayerController controller) async {
    try {
      if (controller.value.isInitialized) {
        await controller.pause();
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      debugPrint('⚠️ 预览面板：暂停控制器失败: $e');
    }

    Future.delayed(const Duration(milliseconds: 100), () async {
      try {
        await controller.dispose();
        debugPrint("✅ 预览面板：已释放旧控制器");
      } catch (e) {
        debugPrint('⚠️ 预览面板：释放旧控制器失败: $e');
      }
    });
  }

  void _initializePlayerForChannel(Channel? channel, [int? version]) {
    if (channel == null || !mounted || _isPaused) {
      setState(() {
        _isInitializing = false;
      });
      return;
    }

    final currentVersion = version ?? _controllerVersion;
    if (currentVersion != _controllerVersion) {
      debugPrint("⚠️ 预览面板：版本不匹配，跳过初始化");
      return;
    }

    if (_retryCount > 0) {
      debugPrint("🔄 预览面板：第 $_retryCount 次重试 ${channel.name}");
    } else {
      debugPrint("🚀 预览面板：开始初始化 ${channel.name}");
    }

    setState(() {
      _isInitializing = true;
      _errorMessage = _retryCount > 0
          ? "连接失败，正在重试 ($_retryCount/$_maxRetries)..."
          : null;
    });

    VideoPlayerController newController;
    try {
      newController = VideoPlayerController.networkUrl(
        Uri.parse(channel.url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true, // 预览模式允许混音
          allowBackgroundPlayback: false,
        ),
      );
    } catch (e) {
      debugPrint("❌ 预览面板：创建控制器失败: $e");
      _handleInitializationFailure(channel, currentVersion);
      return;
    }

    _controller = newController;

    _initTimeout?.cancel();
    _initTimeout = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;

      if (currentVersion == _controllerVersion &&
          newController == _controller &&
          _isInitializing) {

        debugPrint("⏱️ 预览面板：初始化超时 ${channel.name}");
        _handleInitializationFailure(channel, currentVersion);
      }
    });

    newController.initialize().then((_) {
      if (!mounted || currentVersion != _controllerVersion) {
        debugPrint("⚠️ 预览面板：页面已卸载或版本不匹配，清理控制器");
        _disposeControllerSafely(newController);
        return;
      }

      if (newController != _controller) {
        debugPrint("⚠️ 预览面板：控制器已被替换，清理旧控制器");
        _disposeControllerSafely(newController);
        return;
      }

      _initTimeout?.cancel();
      _retryCount = 0;

      setState(() {
        _isInitializing = false;
        _errorMessage = null;
      });

      if (!_isPaused) {
        try {
          newController.setVolume(0.5); // 预览模式低音量
          newController.play();
          debugPrint("✅ 预览面板：初始化成功并开始播放 ${channel.name}");
        } catch (e) {
          debugPrint("⚠️ 预览面板：播放失败: $e");
        }
      }

    }).catchError((error) {
      debugPrint("❌ 预览面板：初始化失败 ${channel.name}: $error");

      if (!mounted || currentVersion != _controllerVersion) {
        _disposeControllerSafely(newController);
        return;
      }

      if (newController != _controller) {
        _disposeControllerSafely(newController);
        return;
      }

      _initTimeout?.cancel();
      _handleInitializationFailure(channel, currentVersion);
    });
  }

  void _handleInitializationFailure(Channel channel, int version) {
    if (_retryCount < _maxRetries) {
      _retryCount++;

      debugPrint("🔄 预览面板：准备第 $_retryCount 次重试，等待 ${_retryDelay.inSeconds} 秒");

      setState(() {
        _isInitializing = true;
        _errorMessage = "连接失败，正在重试 ($_retryCount/$_maxRetries)...";
      });

      final oldController = _controller;
      _controller = null;

      _retryTimer?.cancel();
      _retryTimer = Timer(_retryDelay, () async {
        if (!mounted || version != _controllerVersion) {
          debugPrint("⚠️ 预览面板：重试取消（页面已卸载或频道已切换）");

          if (oldController != null) {
            _disposeControllerSafely(oldController);
          }
          return;
        }

        if (oldController != null) {
          await oldController.dispose();
          debugPrint("✅ 预览面板：已释放失败的控制器，准备重试");
        }

        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted || version != _controllerVersion) {
          debugPrint("⚠️ 预览面板：重试前检查失败");
          return;
        }

        debugPrint("🔄 预览面板：开始第 $_retryCount 次重试");
        _initializePlayerForChannel(channel, version);
      });
    } else {
      debugPrint("❌ 预览面板：已达到最大重试次数 ($_maxRetries)");

      final oldController = _controller;
      _controller = null;

      if (oldController != null) {
        _disposeControllerSafely(oldController);
      }

      setState(() {
        _errorMessage = "加载失败（已重试 $_maxRetries 次）";
        _isInitializing = false;
      });

      _retryCount = 0;
    }
  }

  /// 🎯 准备控制器用于播放页面（将被 Chewie 包装）
  VideoPlayerController? prepareControllerForPlayback() {
    if (_controller != null && _controller!.value.isInitialized) {
      debugPrint("✅ 预览面板：准备传递控制器到播放页面（将使用 Chewie）");

      try {
        _controller!.pause();

        final controllerToPass = _controller;
        _controller = null;
        _isPaused = true;

        return controllerToPass;
      } catch (e) {
        debugPrint("⚠️ 预览面板：准备控制器失败: $e");
        return null;
      }
    }

    debugPrint("⚠️ 预览面板：控制器不可用");
    return null;
  }

  /// 🎯 接收从播放页面返回的控制器
  void receiveControllerFromPlayback(VideoPlayerController? returnedController) {
    debugPrint("🔙 预览面板：尝试接收返回的控制器");

    _debounce?.cancel();
    _initTimeout?.cancel();
    _retryTimer?.cancel();

    if (returnedController != null &&
        returnedController.value.isInitialized &&
        _currentChannel != null) {

      debugPrint("✅ 预览面板：接收到有效的控制器，无需重新加载");

      final oldController = _controller;
      if (oldController != null && oldController != returnedController) {
        _disposeControllerSafely(oldController);
      }

      _controller = returnedController;
      _isPaused = false;
      _isInitializing = false;
      _errorMessage = null;
      _retryCount = 0;

      setState(() {});

      try {
        _controller!.setVolume(0.5); // 恢复预览音量
        if (!_controller!.value.isPlaying) {
          _controller!.play();
        }
      } catch (e) {
        debugPrint('⚠️ 预览面板：设置控制器失败: $e');
      }

    } else {
      debugPrint("⚠️ 预览面板：返回的控制器不可用，重新初始化");

      _isPaused = false;
      _controller = null;
      _retryCount = 0;

      if (_currentChannel != null) {
        _controllerVersion++;
        _initializePlayerForChannel(_currentChannel, _controllerVersion);
      }
    }
  }

  void pausePreview() {
    debugPrint("⏸️ 预览面板：暂停预览");
    _isPaused = true;

    _retryTimer?.cancel();
    _retryCount = 0;

    final oldController = _controller;
    _controller = null;

    if (oldController != null) {
      _disposeControllerSafely(oldController);
    }

    setState(() {});
  }

  void resumePreview() {
    debugPrint("▶️ 预览面板：恢复预览");
    _isPaused = false;
    _retryCount = 0;

    if (_controller != null && _controller!.value.isInitialized) {
      try {
        _controller!.play();
      } catch (e) {
        debugPrint('⚠️ 预览面板：恢复播放失败: $e');
      }
    } else if (_currentChannel != null) {
      _controllerVersion++;
      _initializePlayerForChannel(_currentChannel, _controllerVersion);
    }
  }

  @override
  void dispose() {
    debugPrint("🗑️ 预览面板：Disposing...");

    WidgetsBinding.instance.removeObserver(this);

    _debounce?.cancel();
    _initTimeout?.cancel();
    _retryTimer?.cancel();

    final controller = _controller;
    _controller = null;

    if (controller != null) {
      _disposeControllerSafely(controller);
    }

    _controllerVersion++;

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
                    color: Colors.white.withValues(alpha: 0.5),
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
                _getStatusText(),
                maxLines: 2,
                style: TextStyle(
                  color: _getStatusColor(),
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    if (_isPaused) return "预览已暂停";
    if (_isInitializing) {
      if (_retryCount > 0) {
        return "连接失败，正在重试 ($_retryCount/$_maxRetries)...";
      }
      return "正在连接...";
    }
    if (_errorMessage != null) return "$_errorMessage (可切换其他频道)";
    if (_controller != null && _controller!.value.isInitialized) {
      return "预览播放中 (确认后使用 Chewie 播放器)";
    }
    return "等待加载";
  }

  Color _getStatusColor() {
    if (_isPaused) return Colors.grey.shade400;
    if (_isInitializing) {
      if (_retryCount > 0) {
        return Colors.orange.shade300;
      }
      return Colors.blue.shade300;
    }
    if (_errorMessage != null) return Colors.red.shade300;
    if (_controller != null && _controller!.value.isInitialized) {
      return Colors.green.shade300;
    }
    return Colors.grey.shade400;
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _retryCount > 0
                  ? "正在重试... ($_retryCount/$_maxRetries)"
                  : "正在连接...",
              style: TextStyle(
                color: _retryCount > 0 ? Colors.orange : Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text(
              "该频道源可能不可用\n可切换到其他频道",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
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
          Icon(Icons.hourglass_empty, size: 64, color: Colors.white38),
          SizedBox(height: 16),
          Text(
            "准备中...",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}