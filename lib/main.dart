// lib/main.dart
import 'package:flutter/material.dart';
import 'models/channel.dart';
import 'screens/player_page.dart';
import 'services/iptv_service.dart';
import 'widgets/channel_list_item.dart';
import 'widgets/channel_group_row.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter IPTV Player',
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark, // 使用深色主题更适合电视
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// 竖向排列
// class _HomePageState extends State<HomePage> {
//   late Future<List<Channel>> _channelsFuture;
//
//   @override
//   void initState() {
//     super.initState();
//     _channelsFuture = IptvService.fetchAndParseM3u();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('IPTV 频道列表'),
//         backgroundColor: Colors.black.withOpacity(0.5),
//       ),
//       body: FutureBuilder<List<Channel>>(
//         future: _channelsFuture,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return Center(child: Text('加载失败: ${snapshot.error}'));
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(child: Text('没有找到频道'));
//           }
//
//           final channels = snapshot.data!;
//
//           // --- GridView 修改部分 ---
//           return GridView.builder(
//             padding: const EdgeInsets.all(30.0), // 整体内边距
//
//             // 1. 移除了 scrollDirection: Axis.horizontal，使其恢复为默认的竖向滚动
//
//             // 2. 重新配置 gridDelegate 适应竖向滚动
//             gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
//               // 每个 item 的最大宽度。GridView 会根据屏幕宽度和这个值来决定一行放几列
//               maxCrossAxisExtent: 220,
//
//               mainAxisSpacing: 30.0,   // 主轴（竖直）方向的间距
//               crossAxisSpacing: 30.0,  // 交叉轴（水平）方向的间距
//
//               // 宽高比。根据 ChannelListItem 的尺寸 (width: 200, height: 160)
//               // 比例是 200 / 160 = 1.25。可以微调以达到最佳视觉效果。
//               childAspectRatio: 1.25,
//             ),
//
//             itemCount: channels.length,
//             itemBuilder: (context, index) {
//               final channel = channels[index];
//               // ChannelListItem 不需要修改，它已经是一个独立的卡片组件
//               return ChannelListItem(
//                 channel: channel,
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => PlayerPage(channel: channel),
//                     ),
//                   );
//                 },
//               );
//             },
//           );
//           // --- GridView 修改结束 ---
//         },
//       ),
//     );
//   }
// }

//分组排列
class _HomePageState extends State<HomePage> {
  // Future 的类型现在是 Map
  late Future<Map<String, List<Channel>>> _groupedChannelsFuture;

  @override
  void initState() {
    super.initState();
    // 调用新的服务方法
    _groupedChannelsFuture = IptvService.fetchAndGroupChannels();
  }

  void _onChannelTap(Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerPage(channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IPTV 频道'),
      ),
      body: FutureBuilder<Map<String, List<Channel>>>(
        future: _groupedChannelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('没有找到频道'));
          }

          final groupedChannels = snapshot.data!;
          final groups = groupedChannels.keys.toList();

          // 使用一个垂直的 ListView 来展示每个分组行
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final groupTitle = groups[index];
              final channelsInGroup = groupedChannels[groupTitle]!;
              return ChannelGroupRow(
                title: groupTitle,
                channels: channelsInGroup,
                onChannelTap: _onChannelTap,
              );
            },
          );
        },
      ),
    );
  }
}