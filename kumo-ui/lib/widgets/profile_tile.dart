import 'package:flutter/widgets.dart';

import '../data/profiles_source.dart';
import '../theme/kumo_theme.dart';

/// A workspace's colored tile with its initial.
class ProfileTile extends StatelessWidget {
  const ProfileTile({super.key, required this.profile, this.size = 24});
  final AppProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: profile.color, borderRadius: BorderRadius.circular(size * 0.3)),
        child: Text(profile.initial, style: sans(size * 0.46, weight: FontWeight.w700, color: const Color(0xFF0B0D18), height: 1)),
      );
}
