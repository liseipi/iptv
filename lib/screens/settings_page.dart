// lib/screens/settings_page.dart (添加代理类型选择)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/proxy_manager.dart';
import '../services/iptv_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ProxyManager _proxyManager;
  bool _isLoading = true;

  bool _proxyEnabled = false;
  ProxyType _proxyType = ProxyType.http; // 🎯 新增
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  final FocusNode _backButtonFocus = FocusNode();
  final FocusNode _enableSwitchFocus = FocusNode();
  final FocusNode _typeSelectFocus = FocusNode(); // 🎯 新增
  final FocusNode _hostFocus = FocusNode();
  final FocusNode _portFocus = FocusNode();
  final FocusNode _saveFocus = FocusNode();
  final FocusNode _cancelFocus = FocusNode();
  final FocusNode _clearCacheFocus = FocusNode();

  String? _cacheTimeInfo;

  @override
  void initState() {
    super.initState();
    _loadProxySettings();
    _loadCacheInfo();
  }

  Future<void> _loadProxySettings() async {
    _proxyManager = await ProxyManager.getInstance();

    setState(() {
      _proxyEnabled = _proxyManager.isProxyEnabled;
      _proxyType = _proxyManager.proxyType; // 🎯 加载类型
      _hostController.text = _proxyManager.proxyHost;
      _portController.text = _proxyManager.proxyPort.toString();
      _isLoading = false;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _enableSwitchFocus.requestFocus();
      }
    });
  }

  Future<void> _loadCacheInfo() async {
    final cacheTime = await IptvService.getCacheTimeInfo();
    if (mounted) {
      setState(() {
        _cacheTimeInfo = cacheTime;
      });
    }
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
      type: _proxyType, // 🎯 保存类型
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

  Future<void> _clearCache() async {
    await IptvService.clearCache();
    if (mounted) {
      setState(() {
        _cacheTimeInfo = null;
      });
      _showMessage('缓存已清除');
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
    _typeSelectFocus.dispose(); // 🎯 新增
    _hostFocus.dispose();
    _portFocus.dispose();
    _saveFocus.dispose();
    _cancelFocus.dispose();
    _clearCacheFocus.dispose();
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
          // 顶部导航栏（保持不变）
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Focus(
                  focusNode: _backButtonFocus,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.select ||
                          event.logicalKey == LogicalKeyboardKey.enter) {
                        Navigator.of(context).pop();
                        return KeyEventResult.handled;
                      }
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
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? Colors.blue.withValues(alpha: 0.8)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
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
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '返回',
                                style: TextStyle(
                                  color: isFocused ? Colors.white : Colors.white70,
                                  fontSize: 16,
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
                const SizedBox(width: 16),
                const Text(
                  '代理设置',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
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
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 代理开关（保持不变）
                      InkWell(
                        focusNode: _enableSwitchFocus,
                        autofocus: false,
                        onTap: () {
                          setState(() {
                            _proxyEnabled = !_proxyEnabled;
                          });
                        },
                        onFocusChange: (hasFocus) {
                          setState(() {});
                        },
                        child: Builder(
                          builder: (context) {
                            final isFocused = _enableSwitchFocus.hasFocus;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isFocused
                                    ? Colors.blue.withValues(alpha: 0.3)
                                    : Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isFocused ? Colors.blue : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: _proxyEnabled
                                              ? Colors.green.withValues(alpha: 0.2)
                                              : Colors.red.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _proxyEnabled
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color: _proxyEnabled
                                              ? Colors.green
                                              : Colors.red,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '启用代理',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: isFocused
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _proxyEnabled ? '代理已启用' : '代理已关闭',
                                            style: TextStyle(
                                              color: _proxyEnabled
                                                  ? Colors.green.shade300
                                                  : Colors.red.shade300,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 64,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _proxyEnabled
                                          ? Colors.green
                                          : Colors.grey.shade700,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: _proxyEnabled
                                          ? [
                                        BoxShadow(
                                          color: Colors.green.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        )
                                      ]
                                          : [],
                                    ),
                                    child: Stack(
                                      children: [
                                        AnimatedPositioned(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                          left: _proxyEnabled ? 32 : 0,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.3),
                                                  blurRadius: 3,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              _proxyEnabled ? Icons.check : Icons.close,
                                              color: _proxyEnabled ? Colors.green : Colors.red,
                                              size: 18,
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

                      const SizedBox(height: 16),

                      // 🎯 新增：代理类型选择
                      InkWell(
                        focusNode: _typeSelectFocus,
                        onTap: _proxyEnabled ? () {
                          setState(() {
                            _proxyType = _proxyType == ProxyType.http
                                ? ProxyType.socks5
                                : ProxyType.http;
                          });
                        } : null,
                        onFocusChange: (hasFocus) {
                          setState(() {});
                        },
                        child: Builder(
                          builder: (context) {
                            final isFocused = _typeSelectFocus.hasFocus;
                            return Opacity(
                              opacity: _proxyEnabled ? 1.0 : 0.5,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isFocused && _proxyEnabled
                                        ? Colors.blue
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: _proxyType == ProxyType.http
                                                ? Colors.blue.withValues(alpha: 0.2)
                                                : Colors.purple.withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _proxyType == ProxyType.http
                                                ? Icons.http
                                                : Icons.vpn_lock,
                                            color: _proxyType == ProxyType.http
                                                ? Colors.blue
                                                : Colors.purple,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '代理类型',
                                              style: TextStyle(
                                                color: _proxyEnabled
                                                    ? Colors.white
                                                    : Colors.grey,
                                                fontSize: 18,
                                                fontWeight: isFocused
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _proxyType.displayName,
                                              style: TextStyle(
                                                color: _proxyEnabled
                                                    ? (_proxyType == ProxyType.http
                                                    ? Colors.blue.shade300
                                                    : Colors.purple.shade300)
                                                    : Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    // 类型切换指示器
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _proxyEnabled
                                            ? (_proxyType == ProxyType.http
                                            ? Colors.blue.withValues(alpha: 0.3)
                                            : Colors.purple.withValues(alpha: 0.3))
                                            : Colors.grey.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _proxyType.displayName,
                                            style: TextStyle(
                                              color: _proxyEnabled
                                                  ? Colors.white
                                                  : Colors.grey,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.sync,
                                            size: 16,
                                            color: _proxyEnabled
                                                ? Colors.white70
                                                : Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 代理地址输入框（保持不变）
                      ListenableBuilder(
                        listenable: _hostFocus,
                        builder: (context, child) {
                          final isFocused = _hostFocus.hasFocus;
                          return Opacity(
                            opacity: _proxyEnabled ? 1.0 : 0.5,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isFocused && _proxyEnabled
                                      ? Colors.blue
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '代理地址',
                                    style: TextStyle(
                                      color: _proxyEnabled
                                          ? Colors.white70
                                          : Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _hostController,
                                    focusNode: _proxyEnabled ? _hostFocus : null,
                                    enabled: _proxyEnabled,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '例如: 127.0.0.1 或 192.168.1.100',
                                      hintStyle: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (value) {
                                      if (_proxyEnabled) {
                                        _portFocus.requestFocus();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 14),

                      // 代理端口输入框（保持不变）
                      ListenableBuilder(
                        listenable: _portFocus,
                        builder: (context, child) {
                          final isFocused = _portFocus.hasFocus;
                          return Opacity(
                            opacity: _proxyEnabled ? 1.0 : 0.5,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isFocused && _proxyEnabled
                                      ? Colors.blue
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '代理端口',
                                    style: TextStyle(
                                      color: _proxyEnabled
                                          ? Colors.white70
                                          : Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _portController,
                                    focusNode: _proxyEnabled ? _portFocus : null,
                                    enabled: _proxyEnabled,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '例如: 1080 或 8080',
                                      hintStyle: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (value) {
                                      if (_proxyEnabled) {
                                        _saveFocus.requestFocus();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // 按钮行（保持不变）
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              focusNode: _saveFocus,
                              onTap: _saveProxySettings,
                              onFocusChange: (hasFocus) {
                                setState(() {});
                              },
                              child: Builder(
                                builder: (context) {
                                  final isFocused = _saveFocus.hasFocus;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isFocused
                                          ? Colors.blue
                                          : Colors.blue.shade700,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isFocused
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                      boxShadow: isFocused
                                          ? [
                                        BoxShadow(
                                          color: Colors.blue.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        )
                                      ]
                                          : [],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '保存设置',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: isFocused
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              focusNode: _cancelFocus,
                              onTap: () => Navigator.of(context).pop(),
                              onFocusChange: (hasFocus) {
                                setState(() {});
                              },
                              child: Builder(
                                builder: (context) {
                                  final isFocused = _cancelFocus.hasFocus;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isFocused
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade800,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isFocused
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '取消',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: isFocused
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // 清除缓存按钮（保持不变）
                      InkWell(
                        focusNode: _clearCacheFocus,
                        onTap: _clearCache,
                        onFocusChange: (hasFocus) {
                          setState(() {});
                        },
                        child: Builder(
                          builder: (context) {
                            final isFocused = _clearCacheFocus.hasFocus;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isFocused
                                    ? Colors.orange.shade700
                                    : Colors.orange.shade800,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isFocused
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.delete_sweep,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _cacheTimeInfo != null
                                        ? '清除缓存 (更新于 $_cacheTimeInfo)'
                                        : '清除缓存',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: isFocused
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 🎯 提示信息（更新内容）
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade900.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.orange.shade700,
                            width: 1.5,
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
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '温馨提示',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• 支持 HTTP 和 SOCKS5 两种代理类型\n'
                                  '• HTTP: 适用于大多数场景，端口通常为 1080/8080\n'
                                  '• SOCKS5: 更安全的代理协议，端口通常为 1080\n'
                                  '• 修改设置后需要重新加载频道列表\n'
                                  '• 频道源会自动缓存，网络失败时使用缓存\n'
                                  '• 使用遥控器上下键在各项间切换',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
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