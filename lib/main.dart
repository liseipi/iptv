// lib/main.dart (优化版 - 改进遥控器导航逻辑)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
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
  // --- 状态管理 ---
  Map<String, List<Channel>> _groupedChannels = {};
  List<String> _categories = [];
  String? _selectedCategory;
  Channel? _focusedChannel;
  bool _isLoading = true;
  String? _errorMessage;

  // --- 焦点管理 ---
  final FocusScopeNode _categoryPaneFocusScope = FocusScopeNode();
  final FocusScopeNode _channelPaneFocusScope = FocusScopeNode();
  final FocusNode _settingsButtonFocus = FocusNode();

  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _channelScrollController = ScrollController();

  final GlobalKey<PreviewPaneState> _previewPaneKey = GlobalKey<PreviewPaneState>();

  // 防抖计时器
  Timer? _previewDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadChannels();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _previewPaneKey.currentState?.resumePreview();
    } else if (state == AppLifecycleState.paused) {
      _previewPaneKey.currentState?.pausePreview();
    }
  }

  Future<void> _loadChannels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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

      // 🎯 新增：检查是否使用了缓存，并显示提示
      final cacheTime = await IptvService.getCacheTimeInfo();
      if (cacheTime != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('频道列表更新于: $cacheTime'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.blue.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      _showError('加载频道失败: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(label: '重试', onPressed: _loadChannels),
        ),
      );
    }
  }

  void _onChannelFocused(Channel channel) {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted && _focusedChannel != channel) {
        setState(() {
          _focusedChannel = channel;
        });
      }
    });
  }

  // 🎯 改进1: 分类选中时自动选择第一个频道
  // 🎯 新增参数: shouldResetChannel - 是否重置到第一个频道
  void _onCategorySelected(String category, {bool shouldResetChannel = true}) {
    // 如果分类没有变化，不做任何操作
    if (_selectedCategory == category && !shouldResetChannel) {
      return;
    }

    setState(() {
      _selectedCategory = category;

      // 🎯 关键修复: 只有在需要重置时才跳到第一个频道
      if (shouldResetChannel) {
        final channels = _groupedChannels[category];
        _focusedChannel = channels?.isNotEmpty == true ? channels!.first : null;
      }
      // 如果不重置，保持当前焦点的频道
    });

    // 🎯 只有在重置频道时才滚动到顶部
    if (shouldResetChannel) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          // 滚动到顶部
          if (_channelScrollController.hasClients) {
            _channelScrollController.jumpTo(0.0);
          }

          // 如果当前频道面板有焦点，重新聚焦到第一个频道
          if (_channelPaneFocusScope.hasFocus) {
            _channelPaneFocusScope.requestFocus();
          }
        }
      });
    }
  }

  void _onChannelSubmitted(Channel channel) async {
    final previewController = _previewPaneKey.currentState?.prepareControllerForPlayback();

    if (previewController != null) {
      debugPrint("✅ 主页面:获取到预览控制器,准备无缝切换");
    } else {
      debugPrint("⚠️ 主页面:预览控制器不可用,将重新加载");
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          channel: channel,
          previewController: previewController,
        ),
      ),
    );

    if (mounted) {
      debugPrint("主页面:从播放页面返回");
      final returnedController = result as VideoPlayerController?;

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _previewPaneKey.currentState?.receiveControllerFromPlayback(returnedController);

          if (returnedController != null) {
            debugPrint("✅ 主页面:成功接收并传递控制器,实现双向无缝切换");
          } else {
            debugPrint("⚠️ 主页面:未接收到控制器,预览将重新加载");
          }
        }
      });
    }
  }

  void _openSettings() async {
    _previewPaneKey.currentState?.pausePreview();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      await _loadChannels();
    }

    if (mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _previewPaneKey.currentState?.resumePreview();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _previewDebounce?.cancel();
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
              // 🎯 改进2: 只有从频道面板或设置按钮才能左移到分类面板
              if (_channelPaneFocusScope.hasFocus || _settingsButtonFocus.hasFocus) {
                _categoryPaneFocusScope.requestFocus();
              }
              return null;
            },
          ),
          _MoveUpIntent: CallbackAction<_MoveUpIntent>(
            onInvoke: (_) {
              final currentFocus = FocusManager.instance.primaryFocus;

              // 🎯 改进3: 二级分类(频道面板)限制上移
              if (_channelPaneFocusScope.hasFocus) {
                // 尝试在频道列表内部上移
                bool canMoveUp = currentFocus?.focusInDirection(TraversalDirection.up) ?? false;
                // 如果已经在频道列表顶部,不做任何操作(不移动到设置)
                return null;
              }

              // 🎯 改进4: 一级分类(分类面板)可以上移到设置
              if (_categoryPaneFocusScope.hasFocus) {
                // 先尝试在分类面板内部上移
                bool canMoveUp = currentFocus?.focusInDirection(TraversalDirection.up) ?? false;

                // 🎯 关键修复: 如果无法在面板内上移(已经在顶部)，则跳转到设置按钮
                if (!canMoveUp) {
                  // 延迟一帧确保焦点系统处理完成
                  Future.delayed(const Duration(milliseconds: 50), () {
                    if (mounted) {
                      _settingsButtonFocus.requestFocus();
                    }
                  });
                }
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
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
                  ),
                ),

                Column(
                  children: [
                    // 顶部设置栏
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
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
                          Focus(
                            focusNode: _settingsButtonFocus,
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent) {
                                // 🎯 改进5: 设置按钮下移时,优先回到分类面板
                                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                  _categoryPaneFocusScope.requestFocus();
                                  return KeyEventResult.handled;
                                }
                                if (event.logicalKey == LogicalKeyboardKey.select ||
                                    event.logicalKey == LogicalKeyboardKey.enter) {
                                  _openSettings();
                                  return KeyEventResult.handled;
                                }
                              }
                              return KeyEventResult.ignored;
                            },
                            // 🎯 关键修复: 添加 onFocusChange 回调确保焦点变化立即响应
                            onFocusChange: (hasFocus) {
                              // 触发重建以更新按钮样式
                              if (mounted) {
                                setState(() {});
                              }
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
                                          ? Colors.blue
                                          : Colors.grey.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isFocused
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.settings,
                                          color: isFocused
                                              ? Colors.white
                                              : Colors.white70,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          '设置',
                                          style: TextStyle(color: Colors.white),
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

                    // 内容区
                    Expanded(
                      child: Row(
                        children: [
                          // 分类面板
                          Expanded(
                            flex: 2,
                            child: CategoryPane(
                              scrollController: _categoryScrollController,
                              focusScopeNode: _categoryPaneFocusScope,
                              categories: _categories,
                              selectedCategory: _selectedCategory ?? '',
                              onCategorySelected: _onCategorySelected,
                            ),
                          ),

                          // 频道面板
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

                          // 预览面板
                          Expanded(
                            flex: 5,
                            child: PreviewPane(
                              key: _previewPaneKey,
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

// Intent 定义
class _MoveToChannelsIntent extends Intent { const _MoveToChannelsIntent(); }
class _MoveToCategoriesIntent extends Intent { const _MoveToCategoriesIntent(); }
class _MoveUpIntent extends Intent { const _MoveUpIntent(); }
class _OpenSettingsIntent extends Intent { const _OpenSettingsIntent(); }