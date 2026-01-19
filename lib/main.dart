// lib/main.dart (优化版 - 支持播放页面切换频道)
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

  // 🎯 新增：是否是首次加载（无缓存）
  bool _isFirstLoad = true;

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

  Future<void> _loadChannels({bool forceUpdate = false}) async {
    // 🎯 改进：只在首次加载或强制更新时显示加载状态
    if (_isFirstLoad || forceUpdate || _categories.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await IptvService.fetchAndGroupChannels(forceUpdate: forceUpdate);
      if (!mounted) return;

      setState(() {
        _groupedChannels = data;
        _categories = data.keys.toList();
        if (_categories.isNotEmpty && _selectedCategory == null) {
          _selectedCategory = _categories.first;
          _focusedChannel = _groupedChannels[_selectedCategory]?.first;
        }
        _isLoading = false;
        _errorMessage = null;
        _isFirstLoad = false;
      });

      // 🎯 改进：只在强制更新或首次成功加载时显示提示
      if (forceUpdate && mounted) {
        _showToast('频道列表已更新', isError: false, duration: 2);
      } else if (!_isFirstLoad && mounted) {
        // 后台更新成功，显示简短提示
        final cacheTime = await IptvService.getCacheTimeInfo();
        if (cacheTime != null) {
          _showToast('频道列表更新于 $cacheTime', isError: false, duration: 2);
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
        _isFirstLoad = false;
      });

      // 🎯 改进：只在首次加载失败或强制更新失败时显示错误
      if (forceUpdate || _categories.isEmpty) {
        _showToast('加载失败: $e', isError: true, duration: 3);
      }
    }
  }

  /// 🎯 新增：显示短暂的Toast提示，不会一直显示
  void _showToast(String message, {required bool isError, int duration = 2}) {
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars(); // 清除之前的提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: duration),
          backgroundColor: isError ? Colors.red.shade700 : Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20),
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

  void _onCategorySelected(String category, {bool shouldResetChannel = true}) {
    if (_selectedCategory == category && !shouldResetChannel) {
      return;
    }

    setState(() {
      _selectedCategory = category;

      if (shouldResetChannel) {
        final channels = _groupedChannels[category];
        _focusedChannel = channels?.isNotEmpty == true ? channels!.first : null;
      }
    });

    if (shouldResetChannel) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          if (_channelScrollController.hasClients) {
            _channelScrollController.jumpTo(0.0);
          }

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

    // 🎯 获取当前分类的频道列表和索引
    final channels = _groupedChannels[_selectedCategory] ?? [];
    final currentIndex = channels.indexWhere((ch) => ch.url == channel.url);

    debugPrint("📺 主页面: 准备播放 ${channel.name}, 索引: $currentIndex, 总频道数: ${channels.length}");

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          channel: channel,
          channels: channels, // 🎯 传递频道列表
          initialIndex: currentIndex >= 0 ? currentIndex : 0, // 🎯 传递初始索引
          previewController: previewController,
        ),
      ),
    );

    if (mounted) {
      debugPrint("主页面:从播放页面返回");

      // 🎯 result 现在是一个 Map，包含 controller 和 lastPlayedChannel
      if (result is Map<String, dynamic>) {
        final returnedController = result['controller'] as VideoPlayerController?;
        final lastPlayedChannel = result['lastChannel'] as Channel?;

        // 🎯 更新焦点频道为最后播放的频道
        if (lastPlayedChannel != null && lastPlayedChannel.url != _focusedChannel?.url) {
          debugPrint("🔄 主页面: 更新焦点频道为 ${lastPlayedChannel.name}");
          setState(() {
            _focusedChannel = lastPlayedChannel;
          });

          // 🎯 滚动到对应频道位置
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) {
              final currentChannels = _groupedChannels[_selectedCategory] ?? [];
              final targetIndex = currentChannels.indexWhere((ch) => ch.url == lastPlayedChannel.url);

              if (targetIndex >= 0 && _channelScrollController.hasClients) {
                debugPrint("📍 主页面: 滚动到频道索引 $targetIndex");
                // 计算滚动位置（每个频道项约 64 像素高度）
                final scrollPosition = targetIndex * 64.0;
                _channelScrollController.animateTo(
                  scrollPosition,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            }
          });
        }

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
      } else {
        // 兼容旧版本返回值
        final returnedController = result as VideoPlayerController?;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _previewPaneKey.currentState?.receiveControllerFromPlayback(returnedController);
          }
        });
      }
    }
  }

  void _openSettings() async {
    _previewPaneKey.currentState?.pausePreview();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );

    // 🎯 改进：设置返回后强制更新
    if (result == true) {
      await _loadChannels(forceUpdate: true);
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
    // 🎯 改进：只在首次加载且无缓存时显示加载界面
    if (_isLoading && _categories.isEmpty) {
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

    // 🎯 改进：只在首次加载失败且无缓存时显示错误界面
    if (_categories.isEmpty && !_isLoading) {
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
                onPressed: () => _loadChannels(forceUpdate: true),
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
              if (_channelPaneFocusScope.hasFocus || _settingsButtonFocus.hasFocus) {
                _categoryPaneFocusScope.requestFocus();
              }
              return null;
            },
          ),
          _MoveUpIntent: CallbackAction<_MoveUpIntent>(
            onInvoke: (_) {
              final currentFocus = FocusManager.instance.primaryFocus;

              if (_channelPaneFocusScope.hasFocus) {
                bool canMoveUp = currentFocus?.focusInDirection(TraversalDirection.up) ?? false;
                return null;
              }

              if (_categoryPaneFocusScope.hasFocus) {
                bool canMoveUp = currentFocus?.focusInDirection(TraversalDirection.up) ?? false;

                if (!canMoveUp) {
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
                            onFocusChange: (hasFocus) {
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
                              focusedChannel: _focusedChannel, // 🎯 传递焦点频道
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