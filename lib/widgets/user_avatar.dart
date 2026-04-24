import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;
  final bool showBorder;

  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 24,
    this.showBorder = true,
  });

  String _getInitials(String fullName) {
    if (fullName.isEmpty) return 'ZD';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Color _generateColor(String name) {
    final hash = name.hashCode;
    final colors = [
      const Color(0xFF041F62), // Zee Navy
      const Color(0xFF011B61), // Deep Blue
      const Color(0xFF021241), // Midnight
      const Color(0xFF071448), // Dark Royal
      const Color(0xFF0F172A), // Slate Dark
      const Color(0xFF1E293B), // Slate
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder ? Border.all(color: Colors.white, width: 2) : null,
        boxShadow: [
          if (showBorder)
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: _generateColor(name),
        backgroundImage: hasImage
            ? CachedNetworkImageProvider('${AppConstants.baseUrl}/storage/$imageUrl')
            : null,
        child: !hasImage
            ? Text(
                _getInitials(name),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: radius * 0.8,
                  letterSpacing: 1,
                ),
              )
            : null,
      ),
    );
  }
}
