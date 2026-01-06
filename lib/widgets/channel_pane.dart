// lib/widgets/channel_pane.dart
import 'dart:async'; // 添加这个导入
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
      autofocus: false,
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
              autofocus: false,
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
  final bool autofocus;
  final VoidCallback onFocus;
  final VoidCallback onTap;

  const ChannelListItem({
    super.key,
    required this.channel,
    required this.channelNumber,
    this.autofocus = false,
    required this.onFocus,
    required this.onTap,
  });

  @override
  State<ChannelListItem> createState() => _ChannelListItemState();
}

class _ChannelListItemState extends State<ChannelListItem> {
  bool _isFocused = false;
  Timer? _throttleTimer; // 节流计时器
  bool _canTriggerFocus = true; // 是否可以触发焦点回调

  // 节流时间间隔（毫秒）
  static const int _throttleDuration = 300;

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    setState(() {
      _isFocused = hasFocus;
    });

    if (hasFocus) {
      // 立即滚动到可见位置（不节流）
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // 使用节流处理焦点回调
      if (_canTriggerFocus) {
        // 立即触发一次
        widget.onFocus();

        // 设置节流标志
        _canTriggerFocus = false;

        // 启动节流计时器
        _throttleTimer?.cancel();
        _throttleTimer = Timer(
          const Duration(milliseconds: _throttleDuration),
              () {
            if (mounted) {
              _canTriggerFocus = true;
              // 如果当前仍然有焦点，再次触发（确保最后一次切换生效）
              if (_isFocused) {
                widget.onFocus();
              }
            }
          },
        );
      } else {
        // 在节流期间，记录需要在计时器结束后触发
        _throttleTimer?.cancel();
        _throttleTimer = Timer(
          const Duration(milliseconds: _throttleDuration),
              () {
            if (mounted) {
              _canTriggerFocus = true;
              // 如果当前仍然有焦点，触发回调
              if (_isFocused) {
                widget.onFocus();
              }
            }
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
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