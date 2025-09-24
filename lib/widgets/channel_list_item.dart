// lib/widgets/channel_list_item.dart
import 'package:flutter/material.dart';
import '../models/channel.dart';

class ChannelListItem extends StatefulWidget {
  final Channel channel;
  final VoidCallback onTap;

  const ChannelListItem({
    super.key,
    required this.channel,
    required this.onTap,
  });

  @override
  State<ChannelListItem> createState() => _ChannelListItemState();
}

class _ChannelListItemState extends State<ChannelListItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    // 增加一个 AnimatedContainer 实现焦点变化的平滑缩放效果
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.identity()..scale(_isFocused ? 1.1 : 1.0),
      transformAlignment: Alignment.center,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (hasFocus) {
          setState(() {
            _isFocused = hasFocus;
          });
        },
        child: Container(
          width: 200, // 给卡片一个固定的宽度
          height: 160, // 给卡片一个固定的高度
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            border: Border.all(
              color: _isFocused ? Colors.orange : Colors.transparent,
              width: 4.0,
            ),
            borderRadius: BorderRadius.circular(8.0),
            boxShadow: _isFocused
                ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 频道 Logo 作为卡片顶部图片
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4.0),
                      topRight: Radius.circular(4.0),
                    ),
                    color: Colors.black.withOpacity(0.3),
                  ),
                  child: widget.channel.logoUrl.isNotEmpty
                      ? Image.network(
                    widget.channel.logoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.tv, size: 40, color: Colors.white70),
                  )
                      : const Icon(Icons.tv, size: 40, color: Colors.white70),
                ),
              ),
              // 频道名称放在卡片底部
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  alignment: Alignment.center,
                  child: Text(
                    widget.channel.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}