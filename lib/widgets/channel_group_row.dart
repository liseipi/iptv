// lib/widgets/channel_group_row.dart
import 'package:flutter/material.dart';
import '../models/channel.dart';
import 'channel_list_item.dart';

class ChannelGroupRow extends StatelessWidget {
  final String title;
  final List<Channel> channels;
  final Function(Channel) onChannelTap;

  const ChannelGroupRow({
    super.key,
    required this.title,
    required this.channels,
    required this.onChannelTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // 横向滚动的频道列表
        SizedBox(
          height: 200, // 给横向列表一个固定的高度, 包含卡片和间距
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return ChannelListItem(
                channel: channel,
                onTap: () => onChannelTap(channel),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 20),
          ),
        ),
      ],
    );
  }
}