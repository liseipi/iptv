// lib/widgets/preview_pane.dart (修复版 - 解决连接失败后无法切换的问题)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/channel.dart';

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

    // 🎯 关键修复1：立即取消所有计时器
    _debounce?.cancel();
    _initTimeout?.cancel();

    // 🎯 关键修复2：增加版本号，使旧的异步操作失效
    _controllerVersion++;
    final currentVersion = _controllerVersion;

    // 🎯 关键修复3：保存旧控制器的引用
    final oldController = _controller;

    // 🎯 关键修复4：立即清空状态和控制器引用
    setState(() {
      _controller = null;
      _isInitializing = true;
      _errorMessage = null;
      _currentChannel = newChannel;
    });

    // 🎯 关键修复5：同步停止并释放旧控制器（包括失败的）
    if (oldController != null) {
      try {
        // 先暂停
        if (oldController.value.isInitialized) {
          oldController.pause();
        }
      } catch (e) {
        debugPrint('⚠️ 预览面板：暂停旧控制器失败: $e');
      }

      // 延迟释放，避免阻塞UI
      Future.delayed(const Duration(milliseconds: 50), () {
        try {
          oldController.dispose();
          debugPrint("✅ 预览面板：已释放旧控制器");
        } catch (e) {
          debugPrint('⚠️ 预览面板：释放旧控制器失败: $e');
        }
      });
    }

    // 🎯 关键修复6：使用防抖，避免快速切换
    _debounce = Timer(const Duration(milliseconds: 300), () {
      // 检查版本号，防止过期操作
      if (currentVersion != _controllerVersion) {
        debugPrint("⚠️ 预览面板：操作已过期，跳过初始化");
        return;
      }

      if (mounted && !_isPaused) {
        _initializePlayerForChannel(newChannel, currentVersion);
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

    debugPrint("🚀 预览面板：开始初始化 ${channel.name}");

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    // 🎯 关键修复7：创建新控制器前确保旧的已清理
    VideoPlayerController newController;
    try {
      newController = VideoPlayerController.networkUrl(
        Uri.parse(channel.url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );
    } catch (e) {
      debugPrint("❌ 预览面板：创建控制器失败: $e");
      setState(() {
        _errorMessage = "创建播放器失败";
        _isInitializing = false;
      });
      return;
    }

    _controller = newController;

    // 🎯 关键修复8：设置合理的超时时间（8秒）
    _initTimeout?.cancel();
    _initTimeout = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;

      if (currentVersion == _controllerVersion &&
          newController == _controller &&
          _isInitializing) {

        debugPrint("⏱️ 预览面板：初始化超时 ${channel.name}");

        setState(() {
          _errorMessage = "连接超时";
          _isInitializing = false;
        });

        // 🎯 关键修复9：超时后立即清理失败的控制器
        if (_controller == newController) {
          _controller = null;
        }

        Future.delayed(const Duration(milliseconds: 50), () {
          try {
            newController.dispose();
            debugPrint("✅ 预览面板：已释放超时控制器");
          } catch (e) {
            debugPrint('⚠️ 预览面板：释放超时控制器失败: $e');
          }
        });
      }
    });

    // 🎯 关键修复10：初始化控制器
    newController.initialize().then((_) {
      // 双重检查：版本号和挂载状态
      if (!mounted || currentVersion != _controllerVersion) {
        debugPrint("⚠️ 预览面板：页面已卸载或版本不匹配，清理控制器");
        Future.delayed(const Duration(milliseconds: 50), () {
          try {
            newController.dispose();
          } catch (e) {
            debugPrint('⚠️ 预览面板：清理过期控制器失败: $e');
          }
        });
        return;
      }

      // 确认这个控制器还是当前控制器
      if (newController != _controller) {
        debugPrint("⚠️ 预览面板：控制器已被替换，清理旧控制器");
        Future.delayed(const Duration(milliseconds: 50), () {
          try {
            newController.dispose();
          } catch (e) {
            debugPrint('⚠️ 预览面板：清理被替换控制器失败: $e');
          }
        });
        return;
      }

      _initTimeout?.cancel();

      setState(() {
        _isInitializing = false;
        _errorMessage = null;
      });

      if (!_isPaused) {
        try {
          newController.play();
          newController.setVolume(0.5);
          debugPrint("✅ 预览面板：初始化成功并开始播放 ${channel.name}");
        } catch (e) {
          debugPrint("⚠️ 预览面板：播放失败: $e");
        }
      }

    }).catchError((error) {
      debugPrint("❌ 预览面板：初始化失败 ${channel.name}: $error");

      if (!mounted || currentVersion != _controllerVersion) {
        Future.delayed(const Duration(milliseconds: 50), () {
          try {
            newController.dispose();
          } catch (e) {
            debugPrint('⚠️ 预览面板：清理失败控制器错误: $e');
          }
        });
        return;
      }

      if (newController != _controller) {
        Future.delayed(const Duration(milliseconds: 50), () {
          try {
            newController.dispose();
          } catch (e) {
            debugPrint('⚠️ 预览面板：清理失败控制器错误: $e');
          }
        });
        return;
      }

      _initTimeout?.cancel();

      setState(() {
        _errorMessage = "加载失败";
        _isInitializing = false;
      });

      // 🎯 关键修复11：失败后立即清理控制器
      if (_controller == newController) {
        _controller = null;
      }

      Future.delayed(const Duration(milliseconds: 50), () {
        try {
          newController.dispose();
          debugPrint("✅ 预览面板：已释放失败的控制器");
        } catch (e) {
          debugPrint('⚠️ 预览面板：释放失败控制器错误: $e');
        }
      });
    });
  }

  VideoPlayerController? prepareControllerForPlayback() {
    if (_controller != null && _controller!.value.isInitialized) {
      debugPrint("✅ 预览面板：准备传递控制器到播放页面");

      _controller!.pause();
      final controllerToPass = _controller;
      _controller = null;
      _isPaused = true;

      setState(() {});

      return controllerToPass;
    }

    debugPrint("⚠️ 预览面板：控制器不可用");
    return null;
  }

  void receiveControllerFromPlayback(VideoPlayerController? returnedController) {
    debugPrint("🔙 预览面板：尝试接收返回的控制器");

    _debounce?.cancel();
    _initTimeout?.cancel();

    if (returnedController != null &&
        returnedController.value.isInitialized &&
        _currentChannel != null) {

      debugPrint("✅ 预览面板：接收到有效的控制器，无需重新加载");

      final oldController = _controller;
      if (oldController != null && oldController != returnedController) {
        Future.delayed(const Duration(milliseconds: 50), () {
          try {
            oldController.dispose();
          } catch (e) {
            debugPrint('⚠️ 预览面板：释放旧控制器失败: $e');
          }
        });
      }

      _controller = returnedController;
      _isPaused = false;
      _isInitializing = false;
      _errorMessage = null;

      setState(() {});

      try {
        _controller!.setVolume(0.5);
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

      if (_currentChannel != null) {
        _controllerVersion++;
        _initializePlayerForChannel(_currentChannel, _controllerVersion);
      }
    }
  }

  void pausePreview() {
    debugPrint("⏸️ 预览面板：暂停预览");
    _isPaused = true;

    final oldController = _controller;
    _controller = null;

    if (oldController != null) {
      try {
        if (oldController.value.isInitialized) {
          oldController.pause();
        }
      } catch (e) {
        debugPrint('⚠️ 预览面板：暂停控制器失败: $e');
      }

      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          oldController.dispose();
        } catch (e) {
          debugPrint('⚠️ 预览面板：释放暂停控制器失败: $e');
        }
      });
    }

    setState(() {});
  }

  void resumePreview() {
    debugPrint("▶️ 预览面板：恢复预览");
    _isPaused = false;

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

    final controller = _controller;
    _controller = null;

    if (controller != null) {
      try {
        if (controller.value.isInitialized) {
          controller.pause();
        }
        controller.dispose();
        debugPrint("✅ 预览面板：已释放控制器");
      } catch (e) {
        debugPrint('⚠️ 预览面板：dispose 时释放控制器失败: $e');
      }
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
                maxLines: 1,
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
    if (_isInitializing) return "正在连接...";
    if (_errorMessage != null) return "$_errorMessage (可切换其他频道)";
    if (_controller != null && _controller!.value.isInitialized) {
      return "预览播放中 (点击确认可无缝切换)";
    }
    return "等待加载";
  }

  Color _getStatusColor() {
    if (_isPaused) return Colors.grey.shade400;
    if (_isInitializing) return Colors.blue.shade300;
    if (_errorMessage != null) return Colors.orange.shade300; // 改为橙色，提示可继续操作
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "正在连接...",
              style: TextStyle(color: Colors.white70),
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
            const Icon(Icons.signal_wifi_off, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.orange),
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