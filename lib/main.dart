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

  // --- Focus Management ---
  final FocusScopeNode _categoryPaneFocusScope = FocusScopeNode();
  final FocusScopeNode _channelPaneFocusScope = FocusScopeNode();

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final data = await IptvService.fetchAndGroupChannels();
      setState(() {
        _groupedChannels = data;
        _categories = data.keys.toList();
        // 默认选中第一个分类，并让第一个分类的第一个频道成为初始焦点
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
          _focusedChannel = _groupedChannels[_selectedCategory]?.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("Error loading channels: $e");
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_categories.isEmpty) {
      return const Scaffold(body: Center(child: Text("没有加载到频道数据")));
    }

    // 使用 RawKeyboardListener 监听全局按键，实现左右栏焦点跳转
    return RawKeyboardListener(
      focusNode: FocusNode(), // 必须有一个根 FocusNode
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          // 在左栏按右键 -> 焦点跳到中栏
          if (event.logicalKey == LogicalKeyboardKey.arrowRight && _categoryPaneFocusScope.hasFocus) {
            _channelPaneFocusScope.requestFocus();
          }
          // 在中栏按左键 -> 焦点跳回左栏
          else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _channelPaneFocusScope.hasFocus) {
            _categoryPaneFocusScope.requestFocus();
          }
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 背景图
            Positioned.fill(
              child: Image.asset('assets/background.jpg', fit: BoxFit.cover), // 记得在项目里添加这张图
            ),
            // 主内容
            Row(
              children: [
                // --- 左栏: 分类 ---
                Expanded(
                  flex: 2,
                  child: CategoryPane(
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
    );
  }
}