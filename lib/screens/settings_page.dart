// lib/screens/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/proxy_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ProxyManager _proxyManager;
  bool _isLoading = true;

  bool _proxyEnabled = false;
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  final FocusNode _backButtonFocus = FocusNode();
  final FocusNode _enableSwitchFocus = FocusNode();
  final FocusNode _hostFocus = FocusNode();
  final FocusNode _portFocus = FocusNode();
  final FocusNode _saveFocus = FocusNode();
  final FocusNode _cancelFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadProxySettings();
  }

  Future<void> _loadProxySettings() async {
    _proxyManager = await ProxyManager.getInstance();

    setState(() {
      _proxyEnabled = _proxyManager.isProxyEnabled;
      _hostController.text = _proxyManager.proxyHost;
      _portController.text = _proxyManager.proxyPort.toString();
      _isLoading = false;
    });

    // 延迟聚焦，确保界面已渲染
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _enableSwitchFocus.requestFocus();
      }
    });
  }

  Future<void> _saveProxySettings() async {
    final port = int.tryParse(_portController.text) ?? 1080;

    if (_hostController.text.isEmpty) {
      _showMessage('请输入代理地址', isError: true);
      return;
    }

    await _proxyManager.saveProxyConfig(
      enabled: _proxyEnabled,
      host: _hostController.text,
      port: port,
    );

    if (mounted) {
      _showMessage('代理设置已保存');
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _backButtonFocus.dispose();
    _enableSwitchFocus.dispose();
    _hostFocus.dispose();
    _portFocus.dispose();
    _saveFocus.dispose();
    _cancelFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 顶部导航栏
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // 返回按钮
                Focus(
                  focusNode: _backButtonFocus,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.select ||
                          event.logicalKey == LogicalKeyboardKey.enter) {
                        Navigator.of(context).pop();
                        return KeyEventResult.handled;
                      }
                      // 向下导航到开关
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        _enableSwitchFocus.requestFocus();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Builder(
                    builder: (context) {
                      final isFocused = _backButtonFocus.hasFocus;
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? Colors.blue.withOpacity(0.8)
                                : Colors.transparent,
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
                                Icons.arrow_back,
                                color: isFocused ? Colors.white : Colors.white70,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '返回',
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
                const SizedBox(width: 20),
                const Text(
                  '代理设置',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 主内容区域
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 700),
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 代理开关
                      // 代理开关
                      Focus(
                        focusNode: _enableSwitchFocus,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            // 切换开关
                            if (event.logicalKey == LogicalKeyboardKey.select ||
                                event.logicalKey == LogicalKeyboardKey.enter ||
                                event.logicalKey == LogicalKeyboardKey.arrowRight ||
                                event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                              setState(() {
                                _proxyEnabled = !_proxyEnabled;
                              });
                              return KeyEventResult.handled;
                            }
                            // 向下导航到地址输入
                            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                              if (_proxyEnabled) {
                                _hostFocus.requestFocus();
                              } else {
                                _saveFocus.requestFocus();
                              }
                              return KeyEventResult.handled;
                            }
                            // 向上导航到返回按钮
                            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                              _backButtonFocus.requestFocus();
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Builder(
                          builder: (context) {
                            final isFocused = _enableSwitchFocus.hasFocus;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isFocused
                                    ? Colors.blue.withOpacity(0.3)
                                    : Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isFocused ? Colors.blue : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      // 改进：使用不同图标和颜色清晰显示开/关状态
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _proxyEnabled
                                              ? Colors.green.withOpacity(0.2)
                                              : Colors.red.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _proxyEnabled
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color: _proxyEnabled
                                              ? Colors.green
                                              : Colors.red,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '启用代理',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: isFocused
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _proxyEnabled ? '代理已启用' : '代理已关闭',
                                            style: TextStyle(
                                              color: _proxyEnabled
                                                  ? Colors.green.shade300
                                                  : Colors.red.shade300,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // 改进：使用类似开关的视觉效果
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 80,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _proxyEnabled
                                          ? Colors.green
                                          : Colors.grey.shade700,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: _proxyEnabled
                                          ? [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ]
                                          : [],
                                    ),
                                    child: Stack(
                                      children: [
                                        // 开关滑块
                                        AnimatedPositioned(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                          left: _proxyEnabled ? 40 : 0,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              _proxyEnabled ? Icons.check : Icons.close,
                                              color: _proxyEnabled ? Colors.green : Colors.red,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                        // 文字标签（可选）
                                        Positioned(
                                          left: _proxyEnabled ? 8 : null,
                                          right: _proxyEnabled ? null : 8,
                                          top: 0,
                                          bottom: 0,
                                          child: Center(
                                            child: Text(
                                              _proxyEnabled ? 'ON' : 'OFF',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.8),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 代理地址输入
                      Focus(
                        focusNode: _hostFocus,
                        canRequestFocus: _proxyEnabled,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            // 向下导航到端口输入
                            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                              _portFocus.requestFocus();
                              return KeyEventResult.handled;
                            }
                            // 向上导航到开关
                            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                              _enableSwitchFocus.requestFocus();
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Builder(
                          builder: (context) {
                            final isFocused = _hostFocus.hasFocus;
                            return Opacity(
                              opacity: _proxyEnabled ? 1.0 : 0.5,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isFocused && _proxyEnabled
                                        ? Colors.blue
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: TextField(
                                  controller: _hostController,
                                  enabled: _proxyEnabled,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: '代理地址',
                                    hintText: '例如: 127.0.0.1 或 192.168.1.100',
                                    labelStyle: TextStyle(
                                      color: _proxyEnabled
                                          ? Colors.white70
                                          : Colors.grey,
                                      fontSize: 18,
                                    ),
                                    hintStyle: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade900,
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide.none,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 20,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 代理端口输入
                      Focus(
                        focusNode: _portFocus,
                        canRequestFocus: _proxyEnabled,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            // 向下导航到保存按钮
                            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                              _saveFocus.requestFocus();
                              return KeyEventResult.handled;
                            }
                            // 向上导航到地址输入
                            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                              _hostFocus.requestFocus();
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Builder(
                          builder: (context) {
                            final isFocused = _portFocus.hasFocus;
                            return Opacity(
                              opacity: _proxyEnabled ? 1.0 : 0.5,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isFocused && _proxyEnabled
                                        ? Colors.blue
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: TextField(
                                  controller: _portController,
                                  enabled: _proxyEnabled,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: '代理端口',
                                    hintText: '例如: 1080 或 8080',
                                    labelStyle: TextStyle(
                                      color: _proxyEnabled
                                          ? Colors.white70
                                          : Colors.grey,
                                      fontSize: 18,
                                    ),
                                    hintStyle: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade900,
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide.none,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 20,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 按钮行
                      Row(
                        children: [
                          // 保存按钮
                          Expanded(
                            child: Focus(
                              focusNode: _saveFocus,
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent) {
                                  if (event.logicalKey == LogicalKeyboardKey.select ||
                                      event.logicalKey == LogicalKeyboardKey.enter) {
                                    _saveProxySettings();
                                    return KeyEventResult.handled;
                                  }
                                  // 向上导航
                                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                    if (_proxyEnabled) {
                                      _portFocus.requestFocus();
                                    } else {
                                      _enableSwitchFocus.requestFocus();
                                    }
                                    return KeyEventResult.handled;
                                  }
                                  // 向右导航到取消按钮
                                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                    _cancelFocus.requestFocus();
                                    return KeyEventResult.handled;
                                  }
                                }
                                return KeyEventResult.ignored;
                              },
                              child: Builder(
                                builder: (context) {
                                  final isFocused = _saveFocus.hasFocus;
                                  return InkWell(
                                    onTap: _saveProxySettings,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      decoration: BoxDecoration(
                                        color: isFocused
                                            ? Colors.blue
                                            : Colors.blue.shade700,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isFocused
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                        boxShadow: isFocused
                                            ? [
                                          BoxShadow(
                                            color: Colors.blue
                                                .withOpacity(0.5),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          )
                                        ]
                                            : [],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '保存设置',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
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
                          ),

                          const SizedBox(width: 16),

                          // 取消按钮
                          Expanded(
                            child: Focus(
                              focusNode: _cancelFocus,
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent) {
                                  if (event.logicalKey == LogicalKeyboardKey.select ||
                                      event.logicalKey == LogicalKeyboardKey.enter) {
                                    Navigator.of(context).pop();
                                    return KeyEventResult.handled;
                                  }
                                  // 向左导航到保存按钮
                                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                    _saveFocus.requestFocus();
                                    return KeyEventResult.handled;
                                  }
                                  // 向上导航
                                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                    if (_proxyEnabled) {
                                      _portFocus.requestFocus();
                                    } else {
                                      _enableSwitchFocus.requestFocus();
                                    }
                                    return KeyEventResult.handled;
                                  }
                                }
                                return KeyEventResult.ignored;
                              },
                              child: Builder(
                                builder: (context) {
                                  final isFocused = _cancelFocus.hasFocus;
                                  return InkWell(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      decoration: BoxDecoration(
                                        color: isFocused
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade800,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isFocused
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '取消',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
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
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 提示信息
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade900.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.shade700,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange.shade300,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  '温馨提示',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• 修改代理设置后需要重新加载频道列表\n'
                                  '• 如遇到加载失败，请检查代理设置是否正确\n'
                                  '• 常见代理端口: HTTP 1080, SOCKS5 1080\n'
                                  '• 使用遥控器方向键可在各项间切换',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}