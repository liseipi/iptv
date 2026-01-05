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
      autofocus: true,
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: channels.isEmpty
            ? const Center(
          child: Text(
            '该分类暂无频道',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        )
            : ListView.builder(
          controller: scrollController,
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
            return ChannelListItem(
              channel: channel,
              channelNumber: index + 1,
              // 关键修改：第一个频道自动获得焦点
              autofocus: index == 0,
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
  final bool autofocus; // 新增参数
  final VoidCallback onFocus;
  final VoidCallback onTap;

  const ChannelListItem({
    super.key,
    required this.channel,
    required this.channelNumber,
    this.autofocus = false, // 默认为 false
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
    return Focus(
      // 关键修改：使用 Focus widget 包装，支持 autofocus
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
          if (hasFocus) {
            widget.onFocus();
            // 平滑滚动到焦点项
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      },
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _isFocused ? Colors.blue.withOpacity(0.8) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: _isFocused ? Colors.blue : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Row(
            children: [
              // 频道编号
              SizedBox(
                width: 40,
                child: Text(
                  '${widget.channelNumber}',
                  style: TextStyle(
                    fontSize: 18,
                    color: _isFocused ? Colors.white : Colors.grey,
                    fontWeight: _isFocused ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 频道 Logo
              Container(
                width: 80,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: widget.channel.logoUrl.isNotEmpty
                    ? Image.network(
                  widget.channel.logoUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey,
                      size: 20,
                    );
                  },
                )
                    : const Icon(Icons.tv, color: Colors.grey, size: 24),
              ),

              const SizedBox(width: 16),

              // 频道名称
              Expanded(
                child: Text(
                  widget.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: _isFocused ? FontWeight.bold : FontWeight.normal,
                    color: _isFocused ? Colors.white : Colors.white70,
                  ),
                ),
              ),

              // 播放图标
              if (_isFocused)
                const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}