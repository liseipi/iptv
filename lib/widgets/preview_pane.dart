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

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    _initializePlayerForChannel(widget.channel);
  }

  // didUpdateWidget 是关键，当父 Widget 传入新的 channel 时会触发
  @override
  void didUpdateWidget(PreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channel != null && widget.channel!.url != oldWidget.channel?.url) {
      // 防抖：如果 500ms 内没有新的频道焦点变化，才开始加载
      if (_debounce?.isActive ?? false) _debounce!.cancel();

      _debounce = Timer(const Duration(milliseconds: 500), () {
        // 先清理旧的播放器
        _controller?.dispose();
        _controller = null;
        setState(() {
          _currentChannel = widget.channel;
        });
        _initializePlayerForChannel(widget.channel);
      });
    }
  }

  void _initializePlayerForChannel(Channel? channel) {
    if (channel == null) return;

    final newController = VideoPlayerController.networkUrl(Uri.parse(channel.url));
    _controller = newController;

    newController.initialize().then((_) {
      // 检查控制器是否已经被替换
      if (newController == _controller) {
        setState(() {}); // 更新 UI 以显示视频
        newController.play();
        newController.setVolume(0.5); // 预览音量小一点
      } else {
        // 如果在初始化期间用户又切换了频道，则丢弃这个旧的控制器
        newController.dispose();
      }
    }).catchError((e) {
      print("Preview Player Error for ${channel.name}: $e");
      if (newController == _controller) {
        setState(() {
          _controller = null; // 加载失败，清空控制器
        });
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
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              ),
              child: _controller != null && _controller!.value.isInitialized
                  ? VideoPlayer(_controller!)
                  : Center(
                child: _currentChannel != null
                    ? const CircularProgressIndicator()
                    : const Text("无预览", style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 节目信息
          if (_currentChannel != null)
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
            // 这里的节目信息是写死的，真实场景需要从 EPG 数据源获取
            "正在播放: 精彩节目",
            maxLines: 1,
            style: TextStyle(color: Colors.grey.shade300, fontSize: 18),
          ),
          Text(
            "稍后播放: 更多精彩",
            maxLines: 1,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          ),
        ],
      ),
    );
  }
}