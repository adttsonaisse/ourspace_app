import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/kawaii.dart';

/// Playful decorations for v2.0.1: tiny non-interactive doodles,
/// sparkles and dot rows that make every tab feel like a sticker book.
/// All widgets are Semantics-excluded so screen readers skip them.
class KawaiiSparkle extends StatelessWidget {
  final double size;
  final Color color;
  final double angle;
  const KawaiiSparkle({
    super.key,
    this.size = 18,
    this.color = Kawaii.sunny,
    this.angle = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: angle,
        child: Icon(
          Icons.star_rounded,
          size: size,
          color: color,
        ),
      ),
    );
  }
}

/// Scattered sparkles + dots for card corners. Paints up to 5 tiny
/// shapes; positions are fixed so layout never shifts between builds.
class KawaiiDoodles extends StatelessWidget {
  final List<Color> colors;
  const KawaiiDoodles({
    super.key,
    this.colors = const [Kawaii.sunny, Kawaii.sky, Kawaii.bubble, Kawaii.mint],
  });

  @override
  Widget build(BuildContext context) {
    final edge = Kawaii.edgeOf(context);
    Widget dot(Color c, double s) => Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: edge, width: 1.5),
          ),
        );
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const KawaiiSparkle(size: 16),
          const SizedBox(width: 6),
          dot(colors[1 % colors.length], 10),
          const SizedBox(width: 6),
          dot(colors[2 % colors.length], 14),
          const SizedBox(width: 6),
          Transform.rotate(
            angle: 0.4,
            child: Icon(Icons.favorite_rounded,
                size: 16, color: colors[3 % colors.length]),
          ),
        ],
      ),
    );
  }
}

/// Wavy dot divider used between Home sections.
class KawaiiDotDivider extends StatelessWidget {
  final int count;
  final List<Color> colors;
  const KawaiiDotDivider({
    super.key,
    this.count = 12,
    this.colors = const [Kawaii.peach, Kawaii.sky, Kawaii.sunny, Kawaii.bubble],
  });

  @override
  Widget build(BuildContext context) {
    final edge = Kawaii.edgeOf(context);
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final c = colors[i % colors.length];
          return Container(
            width: 8,
            height: 8,
            margin: EdgeInsets.only(
              right: i == count - 1 ? 0 : 6,
              top: (i % 2 == 0) ? 0 : 4,
            ),
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: edge, width: 1.2),
            ),
          );
        }),
      ),
    );
  }
}

/// Soft polka background for heroes: pastel dots at low alpha.
/// Uses a CustomPainter so it costs one layer, no image assets.
class KawaiiPolkaBg extends StatelessWidget {
  final Widget child;
  final Color dot;
  final double gap;
  final double radius;
  const KawaiiPolkaBg({
    super.key,
    required this.child,
    this.dot = Colors.white,
    this.gap = 26,
    this.radius = 3,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PolkaPainter(dot: dot, gap: gap, radius: radius),
      child: child,
    );
  }
}

class _PolkaPainter extends CustomPainter {
  final Color dot;
  final double gap;
  final double radius;
  const _PolkaPainter(
      {required this.dot, required this.gap, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dot.withValues(alpha: 0.55);
    for (var y = gap / 2; y < size.height; y += gap) {
      for (var x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PolkaPainter old) =>
      old.dot != dot || old.gap != gap || old.radius != radius;
}

/// Floating sticker cluster for empty states and heroes.
class KawaiiStickerCluster extends StatelessWidget {
  final IconData main;
  final Color mainBg;
  const KawaiiStickerCluster({
    super.key,
    required this.main,
    required this.mainBg,
  });

  @override
  Widget build(BuildContext context) {
    final edge = Kawaii.edgeOf(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: 84,
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 8,
              top: 6,
              child: Transform.rotate(
                angle: -0.25,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: mainBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: edge, width: 2.5),
                    boxShadow: [
                      BoxShadow(color: edge, offset: const Offset(3, 3))
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(main, size: 26, color: Kawaii.onFill(mainBg)),
                ),
              ),
            ),
            Positioned(
              right: 2,
              top: -4,
              child: Transform.rotate(
                angle: 0.35,
                child: Icon(Icons.star_rounded,
                    size: 22, color: Kawaii.sunny),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Kawaii.bubble,
                  shape: BoxShape.circle,
                  border: Border.all(color: edge, width: 2),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.favorite_rounded,
                    size: 10, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deterministic pastel picker for quick-action tiles.
Color kawaiiDecoPick(int i) {
  const all = [Kawaii.peach, Kawaii.sky, Kawaii.sunny, Kawaii.mint, Kawaii.bubble];
  return all[i % all.length];
}

/// Deterministic doodle rotation so grids feel hand-placed.
double kawaiiDecoTilt(int i) =>
    [0.0, 0.12, -0.12, 0.08, -0.08][i % 5] + (math.pi / 180) * (i % 3);

/// Bold tab header row: sticker pill + trailing doodles.
/// One line, used at the top of every tab for a consistent voice.
class KawaiiTabHeaderRow extends StatelessWidget {
  final String pill;
  final IconData pillIcon;
  final Color pillColor;
  const KawaiiTabHeaderRow({
    super.key,
    required this.pill,
    required this.pillIcon,
    this.pillColor = Kawaii.sunnySubtle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: Kawaii.edgeOf(context), width: Kawaii.paperBorderW),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(pillIcon, size: 14, color: Kawaii.onFill(pillColor)),
            const SizedBox(width: 5),
            Text(pill,
                style: TextStyle(
                    fontFamily: Kawaii.displayFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Kawaii.onFill(pillColor))),
          ]),
        ),
        const Spacer(),
        const KawaiiDoodles(),
      ],
    );
  }
}

/// App mascot in a sticker frame. Falls back to a heart tile when the
/// bundled icon asset is missing (tests, old builds).
class KawaiiAppMascot extends StatelessWidget {
  final double size;
  const KawaiiAppMascot({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final edge = Kawaii.edgeOf(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: edge, width: 2.5),
          boxShadow: [BoxShadow(color: edge, offset: const Offset(3, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: Image.asset(
          'assets/images/ourspace-icon.png',
          width: size * 0.86,
          height: size * 0.86,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.favorite_rounded,
            size: 30,
            color: Kawaii.bubble,
          ),
        ),
      ),
    );
  }
}
