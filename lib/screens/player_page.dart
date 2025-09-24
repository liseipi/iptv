// lib/screens/player_page.dart
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.channel.url),
    )
      ..initialize().then((_) {
        // 确保在初始化视频后 setState
        setState(() {
          _isLoading = false;
        });
        _controller.play();
      }).catchError((error) {
        // 处理初始化错误
        setState(() {
          _isLoading = false;
        });
        print("Video Player Error: $error");
        // 可以在这里显示一个错误提示
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _controller.value.isInitialized
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        )
            : const Text(
          '无法播放此频道',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}