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
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _enterFullScreen();
    _initializePlayer();
  }

  void _initializePlayer() {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.channel.url),
    )
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _controller.play();
      }).catchError((error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = error.toString();
        });
        print("Video Player Error: $error");
      });
  }

  @override
  void dispose() {
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

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _exitFullScreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              // 视频播放器
              Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : _controller.value.isInitialized
                    ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
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
                        '错误详情: $_errorMessage',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('返回'),
                      ),
                    ],
                  ),
                ),
              ),
              // 播放/暂停指示器
              if (!_controller.value.isPlaying && !_isLoading && _controller.value.isInitialized)
                Center(
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white.withOpacity(0.7),
                    size: 80,
                  ),
                ),
              // 控制栏
              if (_showControls && _controller.value.isInitialized)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            widget.channel.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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