// lib/services/iptv_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
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

  // 创建支持代理的 HTTP 客户端
  static Future<http.Client> _createHttpClient() async {
    final proxyManager = await ProxyManager.getInstance();
    final proxyUrl = proxyManager.getProxyUrl();

    if (proxyUrl != null) {
      final httpClient = HttpClient();
      httpClient.findProxy = (uri) {
        return 'PROXY ${proxyManager.proxyHost}:${proxyManager.proxyPort}';
      };
      httpClient.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

      return IOClient(httpClient);
    }

    return http.Client();
  }

  /// 主入口：根据配置选择本地测试源还是远程源
  static Future<List<Channel>> fetchAndParseM3u() async {
    http.Client? client;

    try {
      String m3uContent;

      if (useLocalTestSource) {
        m3uContent = localTestM3uContent;
      } else {
        client = await _createHttpClient();

        final response = await client.get(Uri.parse(remoteM3uUrl)).timeout(
          requestTimeout,
          onTimeout: () {
            throw TimeoutException('请求超时，请检查网络连接或代理设置');
          },
        );

        if (response.statusCode == 200) {
          m3uContent = utf8.decode(response.bodyBytes);
        } else {
          throw HttpException('HTTP ${response.statusCode}: 无法加载频道列表');
        }
      }

      return _parseM3u(m3uContent);
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置或代理配置');
    } on TimeoutException catch (e) {
      throw Exception(e.message ?? '请求超时');
    } on HttpException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('加载频道列表失败: $e');
    } finally {
      client?.close();
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
    return channels;
  }

  /// 提取属性值
  static String _extractValue(String line, String key) {
    final regex = RegExp('$key="(.*?)"');
    final match = regex.firstMatch(line);
    return match?.group(1) ?? '';
  }
}