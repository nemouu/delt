import 'package:flutter/material.dart';
import '../models/member.dart';
import '../utils/color_utils.dart';

/// Reusable member chip widget with color indicator
class MemberChip extends StatelessWidget {
  final Member member;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  const MemberChip({
    super.key,
    required this.member,
    this.selected = false,
    this.onTap,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.parseHexColor(member.colorHex);

    if (onTap != null) {
      return FilterChip(
        selected: selected,
        label: Text(member.name),
        avatar: CircleAvatar(
          backgroundColor: ColorUtils.withOpacity(color, 0.3),
          radius: 12,
          child: Text(
            member.name[0].toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onSelected: (_) => onTap?.call(),
        deleteIcon: onDeleted != null ? const Icon(Icons.close, size: 18) : null,
        onDeleted: onDeleted,
      );
    }

    return Chip(
      label: Text(member.name),
      avatar: CircleAvatar(
        backgroundColor: ColorUtils.withOpacity(color, 0.3),
        radius: 12,
        child: Text(
          member.name[0].toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      deleteIcon: onDeleted != null ? const Icon(Icons.close, size: 18) : null,
      onDeleted: onDeleted,
    );
  }
}

/// Simple member avatar widget
class MemberAvatar extends StatelessWidget {
  final Member member;
  final double size;

  const MemberAvatar({
    super.key,
    required this.member,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.parseHexColor(member.colorHex);

    return CircleAvatar(
      backgroundColor: ColorUtils.withOpacity(color, 0.2),
      radius: size / 2,
      child: Text(
        member.name[0].toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: size / 2.5,
        ),
      ),
    );
  }
}
