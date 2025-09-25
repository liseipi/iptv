// lib/services/iptv_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class IptvService {
  // static const String m3uUrl = 'https://iptv-org.github.io/iptv/index.m3u';
  // static const String m3uUrl = 'https://raw.githubusercontent.com/hujingguang/ChinaIPTV/main/cnTV_AutoUpdate.m3u8';
  // static const String m3uUrl = 'https://liseipi.github.io/cdn/TV-IPV4.m3u';
  static const String m3uUrl = 'https://gh-proxy.com/raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u';

  static Future<List<Channel>> fetchAndParseM3u() async {
    try {
      final response = await http.get(Uri.parse(m3uUrl));

      if (response.statusCode == 200) {
        // 使用 utf8.decode 以防止解析中文字符时出现乱码
        final m3uContent = utf8.decode(response.bodyBytes);
        return _parseM3u(m3uContent);
      } else {
        throw Exception('Failed to load M3U file');
      }
    } catch (e) {
      throw Exception('Error fetching M3U: $e');
    }
  }

  // 返回分组后的 Map
  static Future<Map<String, List<Channel>>> fetchAndGroupChannels() async {
    final channels = await fetchAndParseM3u(); // 调用我们之前的方法
    final Map<String, List<Channel>> groupedChannels = {};

    for (var channel in channels) {
      // 如果 groupTitle 为空，则放入 "未分类" 组
      final group = channel.groupTitle.isNotEmpty ? channel.groupTitle : '未分类';
      if (groupedChannels.containsKey(group)) {
        groupedChannels[group]!.add(channel);
      } else {
        groupedChannels[group] = [channel];
      }
    }
    return groupedChannels;
  }

  static List<Channel> _parseM3u(String content) {
    final List<Channel> channels = [];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXTINF:')) {
        // 确保下一行存在并且是 URL
        if (i + 1 < lines.length && (lines[i + 1].trim().startsWith('http'))) {
          final url = lines[i + 1].trim();

          // 使用正则表达式从 #EXTINF 行中提取信息
          final name = _extractValue(line, 'tvg-name');
          final logo = _extractValue(line, 'tvg-logo');
          final group = _extractValue(line, 'group-title');
          final displayName = line.split(',').last.trim();

          channels.add(Channel(
            name: name.isNotEmpty ? name : displayName, // 如果tvg-name为空，则使用末尾的名称
            logoUrl: logo,
            groupTitle: group,
            url: url,
          ));
        }
      }
    }
    return channels;
  }

  // 正则表达式辅助函数，用于提取属性值
  static String _extractValue(String line, String key) {
    final regex = RegExp('$key="(.*?)"');
    final match = regex.firstMatch(line);
    return match?.group(1) ?? '';
  }
}