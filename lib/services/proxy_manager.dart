// lib/services/proxy_manager.dart
import 'package:shared_preferences/shared_preferences.dart';

class ProxyManager {
  static const String _keyProxyEnabled = 'proxy_enabled';
  static const String _keyProxyHost = 'proxy_host';
  static const String _keyProxyPort = 'proxy_port';

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

  Future<void> saveProxyConfig({
    required bool enabled,
    required String host,
    required int port,
  }) async {
    await setProxyEnabled(enabled);
    await setProxyHost(host);
    await setProxyPort(port);
  }

  // 获取代理URL（用于HTTP客户端）
  String? getProxyUrl() {
    if (!isProxyEnabled) return null;
    return 'http://$proxyHost:$proxyPort';
  }
}