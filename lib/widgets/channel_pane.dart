// lib/widgets/channel_pane.dart
import 'package:flutter/material.dart';
import '../models/channel.dart';

class ChannelPane extends StatelessWidget {
  final FocusScopeNode focusScopeNode;
  final ScrollController scrollController;
  final List<Channel> channels;
  final ValueChanged<Channel> onChannelFocused;
  final ValueChanged<Channel> onChannelSubmitted;

  const ChannelPane({
    super.key,
    required this.focusScopeNode,
    required this.scrollController,
    required this.channels,
    required this.onChannelFocused,
    required this.onChannelSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: focusScopeNode,
      autofocus: true, // 默认让中栏获取焦点
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: ListView.builder(
          controller: scrollController,
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
            return ChannelListItem(
              channel: channel,
              channelNumber: index + 1,
              onFocus: () => onChannelFocused(channel),
              onTap: () => onChannelSubmitted(channel),
            );
          },
        ),
      ),
    );
  }
}

class ChannelListItem extends StatefulWidget {
  final Channel channel;
  final int channelNumber;
  final VoidCallback onFocus;
  final VoidCallback onTap;

  const ChannelListItem({
    super.key,
    required this.channel,
    required this.channelNumber,
    required this.onFocus,
    required this.onTap,
  });

  @override
  State<ChannelListItem> createState() => _ChannelListItemState();
}

class _ChannelListItemState extends State<ChannelListItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
          if (hasFocus) {
            widget.onFocus();
            Scrollable.ensureVisible(
              context,
              alignment: 0.5, // 0.5 表示滚动到中心
              duration: const Duration(milliseconds: 300), // 平滑滚动的动画时长
              curve: Curves.easeInOut, // 动画曲线
            );
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        color: _isFocused ? Colors.blue.withOpacity(0.8) : Colors.transparent,
        child: Row(
          children: [
            Text(
              '${widget.channelNumber}',
              style: TextStyle(fontSize: 18, color: _isFocused ? Colors.white : Colors.grey),
            ),
            const SizedBox(width: 20),

            // --- 这是修改过的部分 ---
            Container(
              width: 80,
              height: 40,
              alignment: Alignment.center,
              child: widget.channel.logoUrl.isNotEmpty
                  ? Image.network(
                widget.channel.logoUrl,
                fit: BoxFit.contain,
                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                  return const Icon(Icons.image_not_supported_outlined, color: Colors.grey);
                },
              )
                  : const Icon(Icons.tv, color: Colors.grey),
            ),
            // --- 修改结束 ---

            const SizedBox(width: 20),
            Expanded(
              child: Text(
                widget.channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _isFocused ? Colors.white : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}