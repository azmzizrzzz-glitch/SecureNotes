import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/note.dart';

class MessageBubble extends StatelessWidget {
  final Note note;
  final VoidCallback onDelete;

  const MessageBubble({
    super.key,
    required this.note,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 40),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D44),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildContent(context),
            const SizedBox(height: 6),
            Text(
              DateFormat('h:mm a').format(note.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (note.type) {
      case NoteType.text:
        return SelectableText(
          note.content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.4,
          ),
        );
      
      case NoteType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(note.content),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_rounded,
              color: Colors.white38,
              size: 60,
            ),
          ),
        );
      
      case NoteType.location:
        final coords = note.content.split(',');
        return InkWell(
          onTap: () => _openMap(coords[0], coords[1]),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF6C63FF),
                ),
                const SizedBox(width: 8),
                const Text(
                  'View Location',
                  style: TextStyle(color: Color(0xFF6C63FF)),
                ),
              ],
            ),
          ),
        );
      
      case NoteType.file:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insert_drive_file_rounded,
                color: Color(0xFF6C63FF),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  note.metadata?['fileName'] ?? 'File',
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      
      case NoteType.audio:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_rounded, color: Color(0xFF6C63FF)),
              SizedBox(width: 8),
              Text('Voice Message', style: TextStyle(color: Colors.white)),
            ],
          ),
        );
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            if (note.type == NoteType.text)
              _buildOption(
                ctx,
                Icons.copy_rounded,
                'Copy',
                () {
                  Clipboard.setData(ClipboardData(text: note.content));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            _buildOption(
              ctx,
              Icons.share_rounded,
              'Share',
              () async {
                Navigator.pop(ctx);
                if (note.type == NoteType.text) {
                  Share.share(note.content);
                } else if (note.type == NoteType.image) {
                  final dir = await getTemporaryDirectory();
                  final file = File('${dir.path}/shared_image.jpg');
                  await file.writeAsBytes(base64Decode(note.content));
                  Share.shareXFiles([XFile(file.path)]);
                }
              },
            ),
            _buildOption(
              ctx,
              Icons.delete_rounded,
              'Delete',
              () {
                Navigator.pop(ctx);
                _confirmDelete(context);
              },
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? const Color(0xFFFF6B6B) : Colors.white,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? const Color(0xFFFF6B6B) : Colors.white,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _openMap(String lat, String lng) async {
    final url = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
