// lib/services/iptv_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class IptvService {
  // https://iptv.tsinghua.edu.cn/hls/  #清华大学 IPTV 源
  // http://iptv.huuc.edu.cn/hls/       #河南城建学院 IPTV
  static const String remoteM3uUrl = 'https://assets.musicses.vip/TV-IPV4.m3u';

  // 是否使用代码中硬编码的本地测试源（开发调试时设为 true，发布时改为 false）
  static const bool useLocalTestSource = false;

  // 本地测试用的 M3U 内容，直接定义为字符串变量
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

  /// 主入口：根据配置选择本地测试源还是远程源
  static Future<List<Channel>> fetchAndParseM3u() async {
    try {
      String m3uContent;

      if (useLocalTestSource) {
        // 直接使用代码中定义的字符串
        m3uContent = localTestM3uContent;
      } else {
        // 从网络加载远程源
        final response = await http.get(Uri.parse(remoteM3uUrl)).timeout(
          requestTimeout,
          onTimeout: () {
            throw TimeoutException('请求超时，请检查网络连接');
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
      throw Exception('网络连接失败，请检查网络设置');
    } on TimeoutException catch (e) {
      throw Exception(e.message ?? '请求超时');
    } on HttpException catch (e) {
      throw Exception(e.message);
    } catch (e) {
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

            // 取逗号后的显示名称作为备选
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

  /// 提取属性值（如 tvg-name、tvg-logo、group-title）
  static String _extractValue(String line, String key) {
    final regex = RegExp('$key="(.*?)"');
    final match = regex.firstMatch(line);
    return match?.group(1) ?? '';
  }
}