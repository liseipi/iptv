// lib/services/iptv_service.dart (增强版 - 3次重试 + 本地缓存)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import 'proxy_manager.dart';

class IptvService {
  static const String remoteM3uUrl = 'https://assets.musicses.vip/TV-IPV4.m3u';
  static const bool useLocalTestSource = false;

  static const String localTestM3uContent = '''
#EXTM3U x-tvg-url="http://epg.51zmt.top:8000/e.xml"
#EXTINF:-1 tvg-name="CCTV1" tvg-id="256" tvg-logo="https://livecdn.zbds.org/logo/CCTV1.png" group-title="央视频道", CCTV1
https://haoyunlai.serv00.net/Smartv-1.php?id=ctinews
#EXTINF:-1 tvg-name="CCTV1" tvg-id="256" tvg-logo="https://livecdn.zbds.org/logo/CCTV1.png" group-title="央视频道", CCTV1
https://aktv.top/AKTV/live/aktv/null-8/AKTV.m3u8
#EXTINF:-1 tvg-name="CCTV1" tvg-id="256" tvg-logo="https://livecdn.zbds.org/logo/CCTV1.png" group-title="央视频道", CCTV1
https://iptv.vip-tptv.xyz/litv.php?id=4gtv-4gtv009
''';

  static const Duration requestTimeout = Duration(seconds: 30);

  // 🎯 缓存相关常量
  static const String _cacheKeyContent = 'cached_m3u_content';
  static const String _cacheKeyTimestamp = 'cached_m3u_timestamp';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // 创建支持代理的 HTTP 客户端
  static Future<http.Client> _createHttpClient() async {
    final proxyManager = await ProxyManager.getInstance();
    final proxyUrl = proxyManager.getProxyUrl();

    if (proxyUrl != null) {
      final httpClient = HttpClient();

      // 🎯 修改：使用 getProxyString 方法
      httpClient.findProxy = (uri) {
        return proxyManager.getProxyString();
      };

      httpClient.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

      return IOClient(httpClient);
    }

    return http.Client();
  }

  /// 🎯 新增：保存 M3U 内容到本地缓存
  static Future<void> _saveCachedM3u(String content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyContent, content);
      await prefs.setInt(_cacheKeyTimestamp, DateTime.now().millisecondsSinceEpoch);
      print('✅ IptvService: M3U 内容已缓存 (${content.length} 字节)');
    } catch (e) {
      print('⚠️ IptvService: 保存缓存失败: $e');
    }
  }

  /// 🎯 新增：从本地缓存读取 M3U 内容
  static Future<String?> _loadCachedM3u() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString(_cacheKeyContent);
      final timestamp = prefs.getInt(_cacheKeyTimestamp);

      if (content != null && timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final cacheAge = DateTime.now().difference(cacheTime);
        print('✅ IptvService: 读取到缓存的 M3U (${content.length} 字节, 缓存时间: ${cacheAge.inHours} 小时前)');
        return content;
      }

      print('⚠️ IptvService: 没有找到缓存的 M3U 内容');
      return null;
    } catch (e) {
      print('⚠️ IptvService: 读取缓存失败: $e');
      return null;
    }
  }

  /// 🎯 新增：获取缓存时间信息（用于UI显示）
  static Future<String?> getCacheTimeInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheKeyTimestamp);

      if (timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final cacheAge = DateTime.now().difference(cacheTime);

        if (cacheAge.inDays > 0) {
          return '${cacheAge.inDays} 天前';
        } else if (cacheAge.inHours > 0) {
          return '${cacheAge.inHours} 小时前';
        } else if (cacheAge.inMinutes > 0) {
          return '${cacheAge.inMinutes} 分钟前';
        } else {
          return '刚刚';
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🎯 改进：带重试机制的远程请求
  static Future<String?> _fetchRemoteM3uWithRetry() async {
    http.Client? client;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        print('🔄 IptvService: 第 $attempt/$_maxRetries 次请求远程 M3U');

        client = await _createHttpClient();

        final response = await client.get(Uri.parse(remoteM3uUrl)).timeout(
          requestTimeout,
          onTimeout: () {
            throw TimeoutException('请求超时 (第 $attempt/$_maxRetries 次)');
          },
        );

        if (response.statusCode == 200) {
          final content = utf8.decode(response.bodyBytes);
          print('✅ IptvService: 第 $attempt 次请求成功 (${content.length} 字节)');

          // 🎯 请求成功，保存到缓存
          await _saveCachedM3u(content);

          return content;
        } else {
          throw HttpException('HTTP ${response.statusCode}');
        }

      } on SocketException catch (e) {
        print('❌ IptvService: 第 $attempt 次请求失败 - 网络连接错误: $e');
        if (attempt < _maxRetries) {
          print('⏳ IptvService: 等待 ${_retryDelay.inSeconds} 秒后重试...');
          await Future.delayed(_retryDelay);
        }
      } on TimeoutException catch (e) {
        print('❌ IptvService: 第 $attempt 次请求失败 - 超时: ${e.message}');
        if (attempt < _maxRetries) {
          print('⏳ IptvService: 等待 ${_retryDelay.inSeconds} 秒后重试...');
          await Future.delayed(_retryDelay);
        }
      } on HttpException catch (e) {
        print('❌ IptvService: 第 $attempt 次请求失败 - HTTP错误: ${e.message}');
        if (attempt < _maxRetries) {
          print('⏳ IptvService: 等待 ${_retryDelay.inSeconds} 秒后重试...');
          await Future.delayed(_retryDelay);
        }
      } catch (e) {
        print('❌ IptvService: 第 $attempt 次请求失败 - 未知错误: $e');
        if (attempt < _maxRetries) {
          print('⏳ IptvService: 等待 ${_retryDelay.inSeconds} 秒后重试...');
          await Future.delayed(_retryDelay);
        }
      } finally {
        client?.close();
      }
    }

    print('❌ IptvService: 所有 $_maxRetries 次请求均失败');
    return null;
  }

  /// 主入口：根据配置选择本地测试源还是远程源
  static Future<List<Channel>> fetchAndParseM3u() async {
    try {
      String m3uContent;

      if (useLocalTestSource) {
        print('📝 IptvService: 使用本地测试源');
        m3uContent = localTestM3uContent;
      } else {
        // 🎯 尝试远程请求（带重试）
        final remoteContent = await _fetchRemoteM3uWithRetry();

        if (remoteContent != null) {
          // 远程请求成功
          m3uContent = remoteContent;
        } else {
          // 🎯 所有远程请求都失败，尝试使用缓存
          print('⚠️ IptvService: 远程请求失败，尝试使用缓存...');

          final cachedContent = await _loadCachedM3u();

          if (cachedContent != null && cachedContent.isNotEmpty) {
            print('✅ IptvService: 使用缓存的 M3U 内容');
            m3uContent = cachedContent;

            // 🎯 提示用户正在使用缓存
            // 这里可以通过回调或全局状态通知UI显示提示
          } else {
            print('❌ IptvService: 没有可用的缓存，无法加载频道列表');
            throw Exception(
                '网络连接失败且无缓存数据\n'
                    '已重试 $_maxRetries 次，请检查：\n'
                    '1. 网络连接是否正常\n'
                    '2. 代理设置是否正确\n'
                    '3. 远程服务器是否可访问'
            );
          }
        }
      }

      return _parseM3u(m3uContent);

    } catch (e) {
      if (e.toString().contains('网络连接失败且无缓存数据')) {
        rethrow;
      }
      throw Exception('加载频道列表失败: $e');
    }
  }

  /// 返回分组后的频道 Map
  static Future<Map<String, List<Channel>>> fetchAndGroupChannels() async {
    final channels = await fetchAndParseM3u();

    final Map<String, List<Channel>> groupedChannels = {};

    for (var channel in channels) {
      final group = channel.groupTitle.isNotEmpty ? channel.groupTitle : '未分类';
      groupedChannels.putIfAbsent(group, () => []).add(channel);
    }

    return groupedChannels;
  }

  /// 解析 M3U 内容
  static List<Channel> _parseM3u(String content) {
    final List<Channel> channels = [];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXTINF:')) {
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (nextLine.startsWith('http') || nextLine.startsWith('rtmp')) {
            final url = nextLine;

            final name = _extractValue(line, 'tvg-name');
            final logo = _extractValue(line, 'tvg-logo');
            final group = _extractValue(line, 'group-title');

            final displayName = line.contains(',')
                ? line.split(',').last.trim()
                : '未知频道';

            channels.add(Channel(
              name: name.isNotEmpty ? name : displayName,
              logoUrl: logo,
              groupTitle: group,
              url: url,
            ));
          }
        }
      }
    }

    print('✅ IptvService: 解析完成，共 ${channels.length} 个频道');
    return channels;
  }

  /// 提取属性值
  static String _extractValue(String line, String key) {
    final regex = RegExp('$key="(.*?)"');
    final match = regex.firstMatch(line);
    return match?.group(1) ?? '';
  }

  /// 🎯 新增：清除缓存（供设置页面调用）
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKeyContent);
      await prefs.remove(_cacheKeyTimestamp);
      print('✅ IptvService: 缓存已清除');
    } catch (e) {
      print('⚠️ IptvService: 清除缓存失败: $e');
    }
  }
}