// lib/widgets/preview_pane.dart
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

  // 用于追踪控制器，避免重复释放
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

    // 只有当频道真正改变时才更新
    if (widget.channel != null &&
        widget.channel!.url != oldWidget.channel?.url) {
      _switchChannel(widget.channel!);
    }
  }

  /// 切换频道的主要方法
  void _switchChannel(Channel newChannel) {
    // 取消所有待处理的操作
    _debounce?.cancel();
    _initTimeout?.cancel();

    // 增加版本号，使旧的异步操作失效
    _controllerVersion++;
    final currentVersion = _controllerVersion;

    // 保存旧控制器引用
    final oldController = _controller;

    // 立即清空状态
    setState(() {
      _controller = null;
      _isInitializing = true;
      _errorMessage = null;
      _currentChannel = newChannel;
    });

    // 使用防抖，避免快速切换时创建过多控制器
    _debounce = Timer(const Duration(milliseconds: 300), () {
      // 在防抖期间，可能又发生了新的切换
      if (currentVersion != _controllerVersion) {
        oldController?.dispose();
        return;
      }

      // 延迟释放旧控制器，确保切换平滑
      Future.delayed(const Duration(milliseconds: 100), () {
        oldController?.dispose();
      });

      // 初始化新控制器
      if (mounted && !_isPaused) {
        _initializePlayerForChannel(newChannel, currentVersion);
      }
    });
  }

  /// 初始化播放器
  void _initializePlayerForChannel(Channel? channel, [int? version]) {
    if (channel == null || !mounted || _isPaused) {
      setState(() {
        _isInitializing = false;
      });
      return;
    }

    // 如果提供了版本号，检查是否已过期
    final currentVersion = version ?? _controllerVersion;
    if (currentVersion != _controllerVersion) {
      return;
    }

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    // 创建新控制器
    final newController = VideoPlayerController.networkUrl(
      Uri.parse(channel.url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );

    _controller = newController;

    // 设置超时保护（10秒）
    _initTimeout?.cancel();
    _initTimeout = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;

      // 检查是否还是当前版本的控制器
      if (currentVersion == _controllerVersion &&
          newController == _controller &&
          _isInitializing) {

        print("Preview initialization timeout for ${channel.name}");

        setState(() {
          _errorMessage = "加载超时";
          _isInitializing = false;
        });

        // 清理失败的控制器
        _controller = null;
        newController.dispose();
      }
    });

    // 初始化控制器
    newController.initialize().then((_) {
      // 双重检查：版本号和挂载状态
      if (!mounted || currentVersion != _controllerVersion) {
        newController.dispose();
        return;
      }

      // 再次确认这个控制器还是当前控制器
      if (newController != _controller) {
        newController.dispose();
        return;
      }

      _initTimeout?.cancel();

      setState(() {
        _isInitializing = false;
        _errorMessage = null;
      });

      // 只有在未暂停状态下才播放
      if (!_isPaused) {
        newController.play();
        newController.setVolume(0.5);
      }

      print("Preview initialized successfully for ${channel.name}");

    }).catchError((error) {
      print("Preview initialization error for ${channel.name}: $error");

      if (!mounted || currentVersion != _controllerVersion) {
        newController.dispose();
        return;
      }

      if (newController != _controller) {
        newController.dispose();
        return;
      }

      _initTimeout?.cancel();

      setState(() {
        _errorMessage = "加载失败";
        _isInitializing = false;
      });

      // 清理失败的控制器
      _controller = null;
      newController.dispose();
    });
  }

  /// 暂停预览
  void pausePreview() {
    print("Preview paused");
    _isPaused = true;
    _controller?.pause();
  }

  /// 恢复预览
  void resumePreview() {
    print("Preview resumed");
    _isPaused = false;

    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.play();
    } else if (_currentChannel != null) {
      // 如果当前没有有效的控制器，重新初始化
      _controllerVersion++;
      _initializePlayerForChannel(_currentChannel, _controllerVersion);
    }
  }

  @override
  void dispose() {
    print("PreviewPane disposing...");

    WidgetsBinding.instance.removeObserver(this);

    // 取消所有计时器
    _debounce?.cancel();
    _initTimeout?.cancel();

    // 释放控制器
    _controller?.dispose();

    // 增加版本号，使所有待处理的异步操作失效
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
            // 视频播放区域
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

            // 频道信息
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

  /// 获取状态文本
  String _getStatusText() {
    if (_isPaused) return "预览已暂停";
    if (_isInitializing) return "正在加载...";
    if (_errorMessage != null) return "加载失败: $_errorMessage";
    if (_controller != null && _controller!.value.isInitialized) {
      return "预览播放中";
    }
    return "等待加载";
  }

  /// 获取状态颜色
  Color _getStatusColor() {
    if (_isPaused) return Colors.grey.shade400;
    if (_isInitializing) return Colors.blue.shade300;
    if (_errorMessage != null) return Colors.red.shade300;
    if (_controller != null && _controller!.value.isInitialized) {
      return Colors.green.shade300;
    }
    return Colors.grey.shade400;
  }

  /// 构建视频播放组件
  Widget _buildVideoWidget() {
    // 暂停状态
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

    // 加载中
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

    // 加载失败
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text(
              "该频道源可能不可用",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // 播放成功
    if (_controller != null && _controller!.value.isInitialized) {
      return VideoPlayer(_controller!);
    }

    // 没有频道
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

    // 默认等待状态
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