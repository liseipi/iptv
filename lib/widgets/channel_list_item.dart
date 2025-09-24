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
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: _isFocused ? Colors.orange.withOpacity(0.3) : Colors.transparent,
          border: Border.all(
            color: _isFocused ? Colors.orange : Colors.grey.shade800,
            width: _isFocused ? 3.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            widget.channel.logoUrl.isNotEmpty
                ? Image.network(
              widget.channel.logoUrl,
              width: 60,
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.tv, size: 40, color: Colors.white),
            )
                : const Icon(Icons.tv, size: 40, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.channel.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.channel.groupTitle.isNotEmpty)
                    Text(
                      widget.channel.groupTitle,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}