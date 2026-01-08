// lib/services/proxy_manager.dart (增加代理类型选择)
import 'package:shared_preferences/shared_preferences.dart';

enum ProxyType {
  http,
  socks5;

  String get displayName {
    switch (this) {
      case ProxyType.http:
        return 'HTTP';
      case ProxyType.socks5:
        return 'SOCKS5';
    }
  }
}

class ProxyManager {
  static const String _keyProxyEnabled = 'proxy_enabled';
  static const String _keyProxyHost = 'proxy_host';
  static const String _keyProxyPort = 'proxy_port';
  static const String _keyProxyType = 'proxy_type'; // 🎯 新增

  static ProxyManager? _instance;
  late SharedPreferences _prefs;

  ProxyManager._();

  static Future<ProxyManager> getInstance() async {
    if (_instance == null) {
      _instance = ProxyManager._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // 获取代理配置
  bool get isProxyEnabled => _prefs.getBool(_keyProxyEnabled) ?? false;
  String get proxyHost => _prefs.getString(_keyProxyHost) ?? '192.168.3.1';
  int get proxyPort => _prefs.getInt(_keyProxyPort) ?? 1080;

  // 🎯 新增：获取代理类型
  ProxyType get proxyType {
    final typeString = _prefs.getString(_keyProxyType);
    if (typeString == 'socks5') {
      return ProxyType.socks5;
    }
    return ProxyType.http; // 默认 HTTP
  }

  // 保存代理配置
  Future<void> setProxyEnabled(bool enabled) async {
    await _prefs.setBool(_keyProxyEnabled, enabled);
  }

  Future<void> setProxyHost(String host) async {
    await _prefs.setString(_keyProxyHost, host);
  }

  Future<void> setProxyPort(int port) async {
    await _prefs.setInt(_keyProxyPort, port);
  }

  // 🎯 新增：保存代理类型
  Future<void> setProxyType(ProxyType type) async {
    await _prefs.setString(_keyProxyType, type.name);
  }

  // 🎯 修改：支持代理类型
  Future<void> saveProxyConfig({
    required bool enabled,
    required String host,
    required int port,
    required ProxyType type, // 🎯 新增参数
  }) async {
    await setProxyEnabled(enabled);
    await setProxyHost(host);
    await setProxyPort(port);
    await setProxyType(type); // 🎯 保存类型
  }

  // 🎯 修改：根据类型返回不同的代理URL
  String? getProxyUrl() {
    if (!isProxyEnabled) return null;

    switch (proxyType) {
      case ProxyType.http:
        return 'http://$proxyHost:$proxyPort';
      case ProxyType.socks5:
        return 'socks5://$proxyHost:$proxyPort';
    }
  }

  // 🎯 新增：获取findProxy字符串（用于HttpClient）
  String getProxyString() {
    if (!isProxyEnabled) return 'DIRECT';

    switch (proxyType) {
      case ProxyType.http:
        return 'PROXY $proxyHost:$proxyPort';
      case ProxyType.socks5:
        return 'SOCKS5 $proxyHost:$proxyPort';
    }
  }
}