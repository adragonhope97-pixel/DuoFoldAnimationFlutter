import 'package:flutter/material.dart';

/// The interface the fold effect looks at. Pure Flutter only: platform views
/// are not captured by AnimatedSampler (context.md → gotchas).
///
/// Deliberately busy so later phases are checkable by eye: a 2 px white frame
/// makes the edges unmistakable (002: black outside), thin grid lines and
/// small text show blur (003), saturated tiles show dimming (003).
class DemoContent extends StatelessWidget {
  const DemoContent({super.key});

  static const List<({String label, IconData icon, Color color})> _tiles = [
    (
      label: 'Messages',
      icon: Icons.chat_bubble_outline,
      color: Color(0xFF34C759),
    ),
    (label: 'Photos', icon: Icons.photo_outlined, color: Color(0xFFFF9F0A)),
    (label: 'Maps', icon: Icons.map_outlined, color: Color(0xFF0A84FF)),
    (label: 'Music', icon: Icons.music_note_outlined, color: Color(0xFFFF375F)),
    (
      label: 'Notes',
      icon: Icons.sticky_note_2_outlined,
      color: Color(0xFFFFD60A),
    ),
    (label: 'Weather', icon: Icons.cloud_outlined, color: Color(0xFF64D2FF)),
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF1C1C3A), Color(0xFF0B0B14)],
        ),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: GridPaper(
        color: Colors.white.withValues(alpha: 0.10),
        interval: 80,
        divisions: 1,
        subdivisions: 4,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _StatusRow(),
                const SizedBox(height: 20),
                Text(
                  'Frosted glass',
                  style: text.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tilt the phone. The interface stays where it is; '
                  'the glass moves.',
                  style: text.bodySmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.extent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    children: <Widget>[
                      for (final tile in _tiles)
                        _Tile(
                          label: tile.label,
                          icon: tile.icon,
                          color: tile.color,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        Text(
          '9:41',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        Spacer(),
        Icon(Icons.signal_cellular_alt, color: Colors.white, size: 16),
        SizedBox(width: 6),
        Icon(Icons.wifi, color: Colors.white, size: 16),
        SizedBox(width: 6),
        Icon(Icons.battery_full, color: Colors.white, size: 16),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Icon(icon, color: Colors.black87, size: 26),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
