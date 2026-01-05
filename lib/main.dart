// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/channel.dart';
import 'screens/player_page.dart';
import 'screens/settings_page.dart';
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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
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
  final FocusNode _settingsButtonFocus = FocusNode();

  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _channelScrollController = ScrollController();

  // 新增：PreviewPane 的 GlobalKey
  final GlobalKey<PreviewPaneState> _previewPaneKey = GlobalKey<PreviewPaneState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 添加生命周期监听
    _loadChannels();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用恢复时，确保预览也恢复
    if (state == AppLifecycleState.resumed) {
      _previewPaneKey.currentState?.resumePreview();
    }
  }

  Future<void> _loadChannels() async {
    try {
      final data = await IptvService.fetchAndGroupChannels();
      if (!mounted) return;

      setState(() {
        _groupedChannels = data;
        _categories = data.keys.toList();
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

  void _onChannelFocused(Channel channel) {
    setState(() {
      _focusedChannel = channel;
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _focusedChannel = _groupedChannels[category]?.first;
    });

    Future.delayed(Duration.zero, () {
      if (_channelScrollController.hasClients) {
        _channelScrollController.jumpTo(0.0);
      }
    });
  }

  // 修改：在导航前暂停预览，返回后恢复
  void _onChannelSubmitted(Channel channel) async {
    // 暂停预览
    _previewPaneKey.currentState?.pausePreview();

    // 导航到播放页面
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlayerPage(channel: channel)),
    );

    // 返回后恢复预览
    if (mounted) {
      _previewPaneKey.currentState?.resumePreview();
    }
  }

  // 打开设置页面
  void _openSettings() async {
    // 打开设置前也暂停预览
    _previewPaneKey.currentState?.pausePreview();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );

    // 如果设置已更改，重新加载频道列表
    if (result == true) {
      setState(() {
        _isLoading = true;
      });
      await _loadChannels();
    }

    // 恢复预览
    if (mounted) {
      _previewPaneKey.currentState?.resumePreview();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 移除生命周期监听
    _categoryPaneFocusScope.dispose();
    _channelPaneFocusScope.dispose();
    _settingsButtonFocus.dispose();
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

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _MoveToChannelsIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _MoveToCategoriesIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _MoveUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.contextMenu): const _OpenSettingsIntent(),
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
              } else if (_settingsButtonFocus.hasFocus) {
                _categoryPaneFocusScope.requestFocus();
              }
              return null;
            },
          ),
          _MoveUpIntent: CallbackAction<_MoveUpIntent>(
            onInvoke: (_) {
              // 从分类或频道面板向上导航到设置按钮
              if (_categoryPaneFocusScope.hasFocus || _channelPaneFocusScope.hasFocus) {
                _settingsButtonFocus.requestFocus();
              }
              return null;
            },
          ),
          _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
            onInvoke: (_) {
              _openSettings();
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
                Column(
                  children: [
                    // 顶部设置栏
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'IPTV 播放器',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // 可通过遥控器聚焦的设置按钮
                          Focus(
                            focusNode: _settingsButtonFocus,
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent) {
                                // 向下键返回到分类面板
                                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                  _categoryPaneFocusScope.requestFocus();
                                  return KeyEventResult.handled;
                                }
                                // 向右键跳到频道面板
                                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                  _channelPaneFocusScope.requestFocus();
                                  return KeyEventResult.handled;
                                }
                                // 确认键打开设置
                                if (event.logicalKey == LogicalKeyboardKey.select ||
                                    event.logicalKey == LogicalKeyboardKey.enter) {
                                  _openSettings();
                                  return KeyEventResult.handled;
                                }
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Builder(
                              builder: (context) {
                                final isFocused = _settingsButtonFocus.hasFocus;
                                return InkWell(
                                  onTap: _openSettings,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isFocused
                                          ? Colors.blue.withOpacity(0.8)
                                          : Colors.grey.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isFocused ? Colors.white : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.settings,
                                          color: isFocused ? Colors.white : Colors.white70,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '设置',
                                          style: TextStyle(
                                            color: isFocused ? Colors.white : Colors.white70,
                                            fontSize: 18,
                                            fontWeight: isFocused
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 主内容区域
                    Expanded(
                      child: Row(
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
                              channels: _groupedChannels[_selectedCategory] ?? [],
                              onChannelFocused: _onChannelFocused,
                              onChannelSubmitted: _onChannelSubmitted,
                            ),
                          ),
                          // --- 右栏: 预览 ---
                          Expanded(
                            flex: 5,
                            child: PreviewPane(
                              key: _previewPaneKey, // 添加 key
                              channel: _focusedChannel,
                            ),
                          ),
                        ],
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

class _MoveUpIntent extends Intent {
  const _MoveUpIntent();
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}