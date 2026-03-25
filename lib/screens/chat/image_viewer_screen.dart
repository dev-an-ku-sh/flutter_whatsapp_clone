import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final String? senderName;
  final DateTime? timestamp;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.senderName,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: senderName != null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(senderName!, style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                if (timestamp != null)
                  Text(_formatTime(timestamp!), style: const TextStyle(
                    fontSize: 13, color: Colors.white70)),
              ])
            : null,
        actions: [
          IconButton(icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download not available on web'),
                  backgroundColor: AppTheme.whatsappGreen));
            }),
          IconButton(icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {}),
        ],
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(color: AppTheme.whatsappGreen, strokeWidth: 2)),
              errorWidget: (_, __, ___) => const Icon(
                Icons.broken_image, size: 64, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
