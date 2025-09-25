// lib/screens/player_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/channel.dart';

class PlayerPage extends StatefulWidget {
  final Channel channel;
  const PlayerPage({super.key, required this.channel});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late VideoPlayerController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _enterFullScreen();

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.channel.url),
    )
      ..initialize().then((_) {
        setState(() {
          _isLoading = false;
        });
        _controller.play();
      }).catchError((error) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.toString();
        });
        print("Video Player Error: $error");
      });
  }

  @override
  void dispose() {
    _exitFullScreen();
    _controller.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 黑色背景将自动成为“黑边”
      body: GestureDetector(
        onTap: _togglePlayPause,
        child: Center( // Center Widget 会将视频居中
          child: _isLoading
              ? const CircularProgressIndicator()
              : _controller.value.isInitialized
          // --- 这里是核心改动：恢复使用 AspectRatio ---
              ? AspectRatio(
            // 关键：使用视频控制器提供的实际宽高比
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                // 播放/暂停的图标指示器 (保持不变)
                if (!_controller.value.isPlaying && !_isLoading)
                  Icon(
                    Icons.play_arrow,
                    color: Colors.white.withOpacity(0.7),
                    size: 80,
                  ),
              ],
            ),
          )
          // --- 核心改动结束 ---
              : Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '无法播放此频道',
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
                const SizedBox(height: 16),
                Text(
                  '错误详情: $_errorMessage',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}