// lib/services/iptv_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class IptvService {
  // static const String m3uUrl = 'https://iptv-org.github.io/iptv/index.m3u';
  static const String m3uUrl = 'https://raw.githubusercontent.com/hujingguang/ChinaIPTV/main/cnTV_AutoUpdate.m3u8';

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