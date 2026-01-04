// lib/widgets/preview_pane.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/channel.dart';

class PreviewPane extends StatefulWidget {
  final Channel? channel;

  const PreviewPane({super.key, this.channel});

  @override
  State<PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends State<PreviewPane> {
  VideoPlayerController? _controller;
  Timer? _debounce;
  Channel? _currentChannel;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    _initializePlayerForChannel(widget.channel);
  }

  @override
  void didUpdateWidget(PreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channel != null && widget.channel!.url != oldWidget.channel?.url) {
      // 取消之前的定时器
      _debounce?.cancel();

      // 标记当前控制器为待废弃，但不立即释放
      final controllerToDispose = _controller;

      setState(() {
        _controller = null;
        _isInitializing = false;
      });

      // 防抖：300ms 内没有新的频道焦点变化，才开始加载
      _debounce = Timer(const Duration(milliseconds: 300), () {
        // 现在可以安全释放旧控制器
        controllerToDispose?.dispose();

        if (mounted) {
          setState(() {
            _currentChannel = widget.channel;
          });
          _initializePlayerForChannel(widget.channel);
        }
      });
    }
  }

  void _initializePlayerForChannel(Channel? channel) {
    if (channel == null || !mounted) return;

    setState(() {
      _isInitializing = true;
    });

    // 保存旧的控制器引用
    final oldController = _controller;

    final newController = VideoPlayerController.networkUrl(
      Uri.parse(channel.url),
    );
    _controller = newController;

    newController.initialize().then((_) {
      // 检查控制器是否已经被替换
      if (!mounted) {
        newController.dispose();
        return;
      }

      if (newController == _controller) {
        setState(() {
          _isInitializing = false;
        });
        newController.play();
        newController.setVolume(0.5);

        // 在新控制器初始化成功后再释放旧控制器
        oldController?.dispose();
      } else {
        // 如果在初始化期间用户又切换了频道，则丢弃这个旧的控制器
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

  @override
  void dispose() {
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
            // 视频预览窗口
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
            // 节目信息
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
                _isInitializing ? "正在加载..." : "预览播放中",
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