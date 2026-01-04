// lib/services/iptv_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class IptvService {
  static const String m3uUrl = 'https://assets.musicses.vip/TV-IPV4.m3u';
  static const Duration requestTimeout = Duration(seconds: 30);

  static Future<List<Channel>> fetchAndParseM3u() async {
    try {
      final response = await http
          .get(Uri.parse(m3uUrl))
          .timeout(
        requestTimeout,
        onTimeout: () {
          throw TimeoutException('请求超时，请检查网络连接');
        },
      );

      if (response.statusCode == 200) {
        // 使用 utf8.decode 以防止解析中文字符时出现乱码
        final m3uContent = utf8.decode(response.bodyBytes);
        return _parseM3u(m3uContent);
      } else {
        throw HttpException('HTTP ${response.statusCode}: 无法加载频道列表');
      }
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } on TimeoutException catch (e) {
      throw Exception(e.message);
    } on HttpException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('加载频道列表失败: $e');
    }
  }

  // 返回分组后的 Map
  static Future<Map<String, List<Channel>>> fetchAndGroupChannels() async {
    final channels = await fetchAndParseM3u();
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
            name: name.isNotEmpty ? name : displayName,
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