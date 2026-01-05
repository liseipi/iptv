// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/channel.dart';
import 'screens/player_page.dart';
import 'services/iptv_service.dart';
import 'widgets/category_pane.dart';
import 'widgets/channel_pane.dart';
import 'widgets/preview_pane.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter IPTV Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- State Management ---
  Map<String, List<Channel>> _groupedChannels = {};
  List<String> _categories = [];

  String? _selectedCategory;
  Channel? _focusedChannel;

  bool _isLoading = true;
  String? _errorMessage;

  // --- Focus Management ---
  final FocusScopeNode _categoryPaneFocusScope = FocusScopeNode();
  final FocusScopeNode _channelPaneFocusScope = FocusScopeNode();

  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _channelScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final data = await IptvService.fetchAndGroupChannels();
      if (!mounted) return;

      setState(() {
        _groupedChannels = data;
        _categories = data.keys.toList();
        // 默认选中第一个分类，并让第一个分类的第一个频道成为初始焦点
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
          _focusedChannel = _groupedChannels[_selectedCategory]?.first;
        }
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      _showError('加载频道失败: $e');
      print("Error loading channels: $e");
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '重试',
            onPressed: _loadChannels,
          ),
        ),
      );
    }
  }

  // 当在中栏的频道焦点变化时，由 ChannelPane 调用
  void _onChannelFocused(Channel channel) {
    // 使用 setState 更新焦点频道，从而触发 PreviewPane 的重建
    setState(() {
      _focusedChannel = channel;
    });
  }

  // 当在左栏选择新的分类时，由 CategoryPane 调用
  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      // 切换分类时，默认让新分类的第一个频道成为焦点
      _focusedChannel = _groupedChannels[category]?.first;
    });

    // 使用 Future.delayed 确保在下一帧渲染时执行，此时 ListView 已经更新
    Future.delayed(Duration.zero, () {
      if (_channelScrollController.hasClients) {
        _channelScrollController.jumpTo(0.0);
      }
    });
  }

  void _onChannelSubmitted(Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlayerPage(channel: channel)),
    );
  }

  @override
  void dispose() {
    _categoryPaneFocusScope.dispose();
    _channelPaneFocusScope.dispose();
    _categoryScrollController.dispose();
    _channelScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在加载频道列表...'),
            ],
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage ?? "没有加载到频道数据"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadChannels,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // 使用 Shortcuts 和 Actions 替代 RawKeyboardListener
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _MoveToChannelsIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _MoveToCategoriesIntent(),
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _MoveToChannelsIntent: CallbackAction<_MoveToChannelsIntent>(
            onInvoke: (_) {
              if (_categoryPaneFocusScope.hasFocus) {
                _channelPaneFocusScope.requestFocus();
              }
              return null;
            },
          ),
          _MoveToCategoriesIntent: CallbackAction<_MoveToCategoriesIntent>(
            onInvoke: (_) {
              if (_channelPaneFocusScope.hasFocus) {
                _categoryPaneFocusScope.requestFocus();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Stack(
              children: [
                // 背景图
                Positioned.fill(
                  child: Image.asset(
                    'assets/background.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: Colors.black);
                    },
                  ),
                ),
                // 主内容
                Row(
                  children: [
                    // --- 左栏: 分类 ---
                    Expanded(
                      flex: 2,
                      child: CategoryPane(
                        scrollController: _categoryScrollController,
                        focusScopeNode: _categoryPaneFocusScope,
                        categories: _categories,
                        selectedCategory: _selectedCategory!,
                        onCategorySelected: _onCategorySelected,
                      ),
                    ),
                    // --- 中栏: 频道 ---
                    Expanded(
                      flex: 3,
                      child: ChannelPane(
                        key: ValueKey(_selectedCategory),
                        scrollController: _channelScrollController,
                        focusScopeNode: _channelPaneFocusScope,
                        // 关键: 只传入当前选中分类的频道列表
                        channels: _groupedChannels[_selectedCategory] ?? [],
                        onChannelFocused: _onChannelFocused,
                        onChannelSubmitted: _onChannelSubmitted,
                      ),
                    ),
                    // --- 右栏: 预览 ---
                    Expanded(
                      flex: 5,
                      child: PreviewPane(
                        // 关键: 传入当前获得焦点的频道
                        channel: _focusedChannel,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Intent 类定义
class _MoveToChannelsIntent extends Intent {
  const _MoveToChannelsIntent();
}

class _MoveToCategoriesIntent extends Intent {
  const _MoveToCategoriesIntent();
}