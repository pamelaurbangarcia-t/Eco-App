import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

// ==========================================
// DATOS GUARDADOS (progreso y configuración)
// ==========================================
enum ControlMode { tilt, arrows }

class EcoStore {
  static int unlocked = 1; // niveles desbloqueados (1 a 5)
  static bool sound = true;
  static ControlMode control = ControlMode.tilt;
  static int best = 0;
  static SharedPreferences? _p;

  static Future<void> load() async {
    try {
      _p = await SharedPreferences.getInstance();
      unlocked = (_p!.getInt('unlocked') ?? 1).clamp(1, 5);
      sound = _p!.getBool('sound') ?? true;
      control = (_p!.getString('control') ?? 'tilt') == 'arrows'
          ? ControlMode.arrows
          : ControlMode.tilt;
      best = _p!.getInt('best') ?? 0;
    } catch (_) {}
  }

  static void save() {
    _p?.setInt('unlocked', unlocked);
    _p?.setBool('sound', sound);
    _p?.setString('control', control == ControlMode.arrows ? 'arrows' : 'tilt');
    _p?.setInt('best', best);
  }
}

void _sfx() {
  if (EcoStore.sound) SystemSound.play(SystemSoundType.click);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EcoStore.load();
  runApp(const EcoApp());
}

class EcoApp extends StatelessWidget {
  const EcoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eco',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.amberAccent,
        ),
      ),
      // En tablet o computadora la app queda centrada con un ancho máximo
      builder: (context, child) {
        final size = MediaQuery.of(context).size;
        final phoneLandscape = size.width > size.height && size.height < 600;
        return ColoredBox(
          color: const Color(0xFF0B1220),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: phoneLandscape ? double.infinity : 640),
              child: child ?? const SizedBox(),
            ),
          ),
        );
      },
      home: const MenuScreen(),
    );
  }
}

PageRoute<T> _fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  );
}

double _r(double n) {
  final x = math.sin(n * 12.9898) * 43758.5453;
  return x - x.floor();
}

// ==========================================
// NIVELES Y TEMAS (5 niveles, 5 personajes)
// Puntos = centro del pasillo (0 a 1), de INICIO (abajo) a FIN.
// ==========================================
class LevelData {
  final List<Offset> points;
  final double halfWidth;
  final int memorySeconds;
  const LevelData(this.points, this.halfWidth, this.memorySeconds);
}

const List<LevelData> kLevels = [
  LevelData([
    Offset(.12, .92), Offset(.12, .16), Offset(.48, .16),
    Offset(.48, .60), Offset(.86, .60), Offset(.86, .10),
  ], .075, 10),
  LevelData([
    Offset(.12, .92), Offset(.12, .55), Offset(.45, .55), Offset(.45, .88),
    Offset(.75, .88), Offset(.75, .30), Offset(.45, .30), Offset(.45, .10),
    Offset(.88, .10),
  ], .07, 10),
  LevelData([
    Offset(.12, .92), Offset(.12, .78), Offset(.86, .78), Offset(.86, .62),
    Offset(.14, .62), Offset(.14, .46), Offset(.86, .46), Offset(.86, .30),
    Offset(.14, .30), Offset(.14, .12), Offset(.86, .12),
  ], .065, 9),
  LevelData([
    Offset(.10, .94), Offset(.10, .06), Offset(.90, .06), Offset(.90, .94),
    Offset(.30, .94), Offset(.30, .26), Offset(.70, .26), Offset(.70, .72),
    Offset(.50, .72), Offset(.50, .46),
  ], .06, 8),
  LevelData([
    Offset(.10, .94), Offset(.10, .22), Offset(.30, .22), Offset(.30, .78),
    Offset(.50, .78), Offset(.50, .12), Offset(.70, .12), Offset(.70, .60),
    Offset(.90, .60), Offset(.90, .10),
  ], .055, 7),
];

class LevelTheme {
  final String name, hero;
  final int kind; // 0 murciélago, 1 pez, 2 zorro, 3 robot, 4 astronauta
  final Color bg, rim, wall, floor, accent;
  const LevelTheme(this.name, this.hero, this.kind, this.bg, this.rim,
      this.wall, this.floor, this.accent);
}

const List<LevelTheme> kThemes = [
  LevelTheme('La cueva', 'Eco, el murciélago', 0, Color(0xFF17101F),
      Color(0xFF8B7AA6), Color(0xFF4C3D63), Color(0xFF2B2140), Color(0xFF22D3EE)),
  LevelTheme('El océano', 'Burbuja, el pez', 1, Color(0xFF06243A),
      Color(0xFF59C2E6), Color(0xFF1E6A8C), Color(0xFF0A3A5A), Color(0xFF67E8F9)),
  LevelTheme('El bosque', 'Rufo, el zorro', 2, Color(0xFF14231A),
      Color(0xFF7DBB4B), Color(0xFF3F6B2F), Color(0xFF4A3B27), Color(0xFFFBBF24)),
  LevelTheme('Ciudad neón', 'Byte, el robot', 3, Color(0xFF0B0F1F),
      Color(0xFFFF2BD6), Color(0xFF7A1FA2), Color(0xFF12162B), Color(0xFF22D3EE)),
  LevelTheme('El espacio', 'Orbi, el astronauta', 4, Color(0xFF050510),
      Color(0xFF9CA3AF), Color(0xFF4B5563), Color(0xFF0B1026), Color(0xFFA78BFA)),
];

// ==========================================
// GEOMETRÍA DEL CAMINO
// ==========================================
class PathGeom {
  final List<Offset> pts;
  final List<double> starts = [];
  final List<double> lens = [];
  double total = 0;

  PathGeom(this.pts) {
    for (var i = 0; i < pts.length - 1; i++) {
      final l = (pts[i + 1] - pts[i]).distance;
      starts.add(total);
      lens.add(l);
      total += l;
    }
  }

  Offset at(double s, [double d = 0]) {
    s = s.clamp(0.0, total);
    var i = 0;
    while (i < lens.length - 1 && s > starts[i] + lens[i]) {
      i++;
    }
    final dir = (pts[i + 1] - pts[i]) / lens[i];
    final p = pts[i] + dir * (s - starts[i]);
    return Offset(p.dx - dir.dy * d, p.dy + dir.dx * d);
  }
}

Path _dashed(Path src, double dash, double gap) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, math.min(d + dash, m.length)), Offset.zero);
      d += dash + gap;
    }
  }
  return out;
}

// Dibuja el laberinto con el estilo del nivel
void paintMaze(Canvas canvas, Size size, LevelData data, LevelTheme th,
    double progress) {
  final pts = data.points
      .map((p) => Offset(p.dx * size.width, p.dy * size.height))
      .toList();
  final geom = PathGeom(pts);
  final half = data.halfWidth * size.width;
  final target = geom.total * progress.clamp(0.0, 1.0);

  final path = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (var i = 1; i < pts.length; i++) {
    if (geom.starts[i - 1] + geom.lens[i - 1] <= target) {
      path.lineTo(pts[i].dx, pts[i].dy);
    } else {
      break;
    }
  }
  final e = geom.at(target);
  path.lineTo(e.dx, e.dy);

  Paint stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  canvas.drawPath(_dashed(path, 7, 3),
      stroke(th.rim, half * 2 + 12)..strokeCap = StrokeCap.butt);
  canvas.drawPath(path, stroke(th.wall, half * 2 + 7));
  canvas.drawPath(path, stroke(th.floor, half * 2));
  canvas.drawPath(_dashed(path, 2, 14),
      stroke(Colors.white.withOpacity(0.07), half * 1.2)..strokeCap = StrokeCap.butt);
  _decor(canvas, geom, half, th, target);
}

void _crystal(Canvas c, Offset o, double s, Color col) {
  c.drawCircle(
      o,
      8 * s,
      Paint()
        ..color = col.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  final p = Path()
    ..moveTo(o.dx, o.dy - 7 * s)
    ..lineTo(o.dx + 3.5 * s, o.dy)
    ..lineTo(o.dx, o.dy + 5 * s)
    ..lineTo(o.dx - 3.5 * s, o.dy)
    ..close();
  c.drawPath(p, Paint()..color = col.withOpacity(0.9));
  c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white70);
}

void _mushroom(Canvas c, Offset o, double s) {
  c.drawRect(
      Rect.fromCenter(center: o + Offset(0, 2 * s), width: 3 * s, height: 5 * s),
      Paint()..color = const Color(0xFFFEF3C7));
  c.drawArc(Rect.fromCenter(center: o, width: 10 * s, height: 8 * s), math.pi,
      math.pi, true, Paint()..color = const Color(0xFFDC2626));
  c.drawCircle(o + Offset(-2 * s, -2 * s), 1 * s, Paint()..color = Colors.white);
  c.drawCircle(o + Offset(2 * s, -1.5 * s), 0.9 * s, Paint()..color = Colors.white);
}

void _decor(Canvas c, PathGeom g, double half, LevelTheme th, double target) {
  switch (th.kind) {
    case 0: // cueva: musgo y cristales
      for (var s = 14.0; s < target; s += 26) {
        final side = (s / 26).floor().isEven ? -1.0 : 1.0;
        c.drawCircle(
            g.at(s, side * (half + 3)),
            2 + _r(s) * 1.8,
            Paint()
              ..color = const Color(0xFF4ADE80).withOpacity(0.35 + _r(s + 3) * 0.3));
      }
      var i = 0;
      for (final f in [0.1, 0.27, 0.5, 0.72, 0.9]) {
        if (f * g.total < target) {
          _crystal(c, g.at(f * g.total, (i.isEven ? -1.0 : 1.0) * (half + 2)),
              1.1, th.accent);
        }
        i++;
      }
      break;
    case 1: // océano: corales
      for (var s = 10.0; s < target; s += 22) {
        final n = (s / 22).floor();
        final side = n.isEven ? -1.0 : 1.0;
        final col = n % 3 == 0
            ? const Color(0xFFFB7185)
            : (n % 3 == 1 ? const Color(0xFFFDBA74) : const Color(0xFFF0ABFC));
        c.drawCircle(g.at(s, side * (half + 3)), 2.5 + _r(s) * 2.5,
            Paint()..color = col.withOpacity(0.85));
      }
      break;
    case 2: // bosque: arbustos y hongos
      for (var s = 8.0; s < target; s += 20) {
        final side = (s / 20).floor().isEven ? -1.0 : 1.0;
        c.drawCircle(g.at(s, side * (half + 3)), 3 + _r(s) * 2.5,
            Paint()..color = const Color(0xFF166534).withOpacity(0.9));
      }
      for (final f in [0.15, 0.4, 0.62, 0.85]) {
        if (f * g.total < target) {
          _mushroom(c, g.at(f * g.total, -(half + 8)), 1.1);
        }
      }
      break;
    case 3: // neón: chips brillantes
      for (var s = 12.0; s < target; s += 34) {
        final n = (s / 34).floor();
        final o = g.at(s, (n.isEven ? -1.0 : 1.0) * (half + 3));
        final col = n.isEven ? th.accent : th.rim;
        c.drawRect(
            Rect.fromCenter(center: o, width: 6, height: 3),
            Paint()
              ..color = col.withOpacity(0.35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        c.drawRect(Rect.fromCenter(center: o, width: 5, height: 2),
            Paint()..color = col);
      }
      break;
    default: // espacio: cráteres
      for (var s = 10.0; s < target; s += 30) {
        final o = g.at(s, ((s / 30).floor().isEven ? -1.0 : 1.0) * (half + 3));
        final r = 2.5 + _r(s) * 3;
        c.drawCircle(o, r, Paint()..color = const Color(0xFF374151));
        c.drawCircle(
            o,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8
              ..color = const Color(0xFF9CA3AF));
      }
  }
}

// ==========================================
// PERSONAJES (dibujados con código)
// ==========================================
void _eyes(Canvas c, double dx, double y, double r, bool danger) {
  for (final s in [-1.0, 1.0]) {
    c.drawCircle(Offset(s * dx, y), r, Paint()..color = Colors.white);
    c.drawCircle(
        Offset(s * dx, y),
        r * (danger ? 0.65 : 0.5),
        Paint()
          ..color = danger ? const Color(0xFFFF1744) : const Color(0xFF111827));
  }
}

void paintCharacter(Canvas c, int kind, Offset pos, double scale, double t,
    {bool danger = false, bool fast = false, double facing = 1}) {
  const glows = [
    Color(0xFF8B5CF6), Color(0xFFFB923C), Color(0xFFF97316),
    Color(0xFF22D3EE), Color(0xFFA78BFA),
  ];
  c.save();
  c.translate(pos.dx, pos.dy + math.sin(t * 6) * 1.6 * scale);
  c.scale(scale, scale);
  c.drawCircle(
      Offset.zero,
      18,
      Paint()
        ..color = (danger ? const Color(0xFFFF5252) : glows[kind]).withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
  switch (kind) {
    case 0:
      _bat(c, t, danger, fast);
      break;
    case 1:
      c.scale(facing, 1);
      _fish(c, t, danger, fast);
      break;
    case 2:
      _fox(c, t, danger, fast);
      break;
    case 3:
      _robot(c, t, danger, fast);
      break;
    default:
      _astronaut(c, t, danger, fast);
  }
  c.restore();
}

void _bat(Canvas c, double t, bool danger, bool fast) {
  final flap = math.sin(t * (fast ? 22 : 13));
  for (final sd in [-1.0, 1.0]) {
    c.save();
    c.scale(sd, 1);
    c.rotate(-flap * 0.45);
    final wing = Path()
      ..moveTo(4, -3)
      ..quadraticBezierTo(14, -20 - flap * 6, 30, -8 - flap * 9)
      ..quadraticBezierTo(25, -4, 26, 3)
      ..quadraticBezierTo(20, 0, 18, 7)
      ..quadraticBezierTo(13, 3, 9, 9)
      ..quadraticBezierTo(6, 4, 4, 6)
      ..close();
    c.drawPath(wing, Paint()..color = const Color(0xFF5B21B6));
    c.drawPath(
        wing,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF2E1065));
    c.restore();
  }
  c.drawOval(Rect.fromCenter(center: const Offset(0, 2), width: 14, height: 19),
      Paint()..color = const Color(0xFF7C3AED));
  c.drawOval(Rect.fromCenter(center: const Offset(0, 4), width: 8, height: 12),
      Paint()..color = const Color(0xFFDDD6FE));
  for (final s in [-1.0, 1.0]) {
    c.drawPath(
        Path()
          ..moveTo(s * 3, -12)
          ..lineTo(s * 8.5, -22 + flap * 1.2)
          ..lineTo(s * 7.5, -11)
          ..close(),
        Paint()..color = const Color(0xFF6D28D9));
  }
  c.drawCircle(const Offset(0, -8), 6.6, Paint()..color = const Color(0xFF8B5CF6));
  _eyes(c, 2.8, -8.5, 2.4, danger);
  final fang = Paint()..color = Colors.white;
  c.drawPath(Path()..moveTo(-1.8, -4.4)..lineTo(-0.8, -2)..lineTo(0, -4.4)..close(), fang);
  c.drawPath(Path()..moveTo(0, -4.4)..lineTo(0.8, -2)..lineTo(1.8, -4.4)..close(), fang);
}

void _fish(Canvas c, double t, bool danger, bool fast) {
  final wag = math.sin(t * (fast ? 22 : 12)) * 0.45;
  final fin = Paint()..color = const Color(0xFFF97316);
  c.save();
  c.translate(-12, 0);
  c.rotate(wag);
  c.drawPath(
      Path()
        ..moveTo(2, 0)
        ..lineTo(-12, -9)
        ..lineTo(-9, 0)
        ..lineTo(-12, 9)
        ..close(),
      fin);
  c.restore();
  c.drawPath(
      Path()
        ..moveTo(-4, -8)
        ..quadraticBezierTo(0, -17, 7, -8)
        ..close(),
      fin);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: 32, height: 22),
      Paint()..color = const Color(0xFFFB923C));
  final stripe = Paint()..color = Colors.white.withOpacity(0.85);
  c.drawOval(Rect.fromCenter(center: const Offset(-3, 0), width: 4, height: 17), stripe);
  c.drawOval(Rect.fromCenter(center: const Offset(4, 0), width: 3, height: 14), stripe);
  c.save();
  c.translate(0, 4);
  c.rotate(wag * 0.8);
  c.drawOval(Rect.fromCenter(center: const Offset(-2, 3), width: 9, height: 5), fin);
  c.restore();
  c.drawCircle(const Offset(9, -2), 3.2, Paint()..color = Colors.white);
  c.drawCircle(const Offset(9.8, -2), danger ? 2.0 : 1.5,
      Paint()..color = danger ? const Color(0xFFFF1744) : const Color(0xFF111827));
  c.drawArc(
      Rect.fromCenter(center: const Offset(14, 3), width: 6, height: 5),
      0,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF7C2D12));
}

void _fox(Canvas c, double t, bool danger, bool fast) {
  final wag = math.sin(t * (fast ? 20 : 9));
  final orange = Paint()..color = const Color(0xFFF97316);
  final white = Paint()..color = const Color(0xFFFFF7ED);
  c.save();
  c.translate(8, 8);
  c.rotate(0.6 + wag * 0.35);
  c.drawOval(Rect.fromCenter(center: const Offset(8, 0), width: 22, height: 10), orange);
  c.drawOval(Rect.fromCenter(center: const Offset(16, 0), width: 8, height: 8), white);
  c.restore();
  c.drawOval(Rect.fromCenter(center: const Offset(0, 8), width: 16, height: 17), orange);
  c.drawOval(Rect.fromCenter(center: const Offset(0, 9), width: 8, height: 12), white);
  for (final s in [-1.0, 1.0]) {
    c.drawPath(
        Path()
          ..moveTo(s * 3, -9)
          ..lineTo(s * 10, -21 + wag * 0.8)
          ..lineTo(s * 9, -7)
          ..close(),
        orange);
    c.drawPath(
        Path()
          ..moveTo(s * 5, -10)
          ..lineTo(s * 9.5, -18)
          ..lineTo(s * 8.5, -9)
          ..close(),
        Paint()..color = const Color(0xFF431407));
  }
  c.drawCircle(const Offset(0, -4), 9, orange);
  c.drawPath(
      Path()
        ..moveTo(-9, -2)
        ..lineTo(0, 7)
        ..lineTo(9, -2)
        ..quadraticBezierTo(0, 2, -9, -2)
        ..close(),
      white);
  _eyes(c, 3.6, -5, 2.2, danger);
  c.drawCircle(const Offset(0, 3), 1.8, Paint()..color = const Color(0xFF111827));
}

void _robot(Canvas c, double t, bool danger, bool fast) {
  final blink = (t * 4).floor().isEven;
  final fl = 4 + math.sin(t * 30).abs() * 4;
  c.drawPath(
      Path()
        ..moveTo(-4, 16)
        ..lineTo(0, 16 + fl)
        ..lineTo(4, 16)
        ..close(),
      Paint()..color = const Color(0xFFFB923C));
  final arm = math.sin(t * (fast ? 18 : 8)) * 0.3;
  for (final s in [-1.0, 1.0]) {
    c.save();
    c.translate(s * 11, 6);
    c.rotate(s * (0.5 + arm));
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(0, 4), width: 4, height: 11),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFF64748B));
    c.restore();
  }
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(0, 9), width: 18, height: 15),
          const Radius.circular(4)),
      Paint()..color = const Color(0xFF94A3B8));
  c.drawCircle(const Offset(0, 9), 2.5,
      Paint()..color = danger ? const Color(0xFFFF1744) : const Color(0xFF22D3EE));
  c.drawLine(const Offset(0, -12), const Offset(0, -19),
      Paint()
        ..color = const Color(0xFF64748B)
        ..strokeWidth = 1.5);
  c.drawCircle(const Offset(0, -20), 2.6,
      Paint()..color = blink ? const Color(0xFFFF4D6D) : const Color(0xFFFBBF24));
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(0, -4), width: 24, height: 17),
          const Radius.circular(5)),
      Paint()..color = const Color(0xFFCBD5E1));
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(0, -4), width: 18, height: 9),
          const Radius.circular(3)),
      Paint()..color = const Color(0xFF0F172A));
  final eye = Paint()
    ..color = danger ? const Color(0xFFFF1744) : const Color(0xFF22D3EE);
  c.drawCircle(const Offset(-4, -4), 2.2, eye);
  c.drawCircle(const Offset(4, -4), 2.2, eye);
}

void _astronaut(Canvas c, double t, bool danger, bool fast) {
  final fl = 4 + math.sin(t * 28).abs() * 5;
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(0, 8), width: 22, height: 16),
          const Radius.circular(4)),
      Paint()..color = const Color(0xFF9CA3AF));
  c.drawPath(
      Path()
        ..moveTo(-3, 17)
        ..lineTo(0, 17 + fl)
        ..lineTo(3, 17)
        ..close(),
      Paint()..color = const Color(0xFFFBBF24));
  final sw = math.sin(t * (fast ? 16 : 8)) * 2;
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(0, 8), width: 16, height: 17),
          const Radius.circular(5)),
      Paint()..color = Colors.white);
  c.drawRect(Rect.fromCenter(center: const Offset(0, 9), width: 7, height: 4),
      Paint()..color = const Color(0xFF22D3EE));
  for (final s in [-1.0, 1.0]) {
    c.drawCircle(Offset(s * 9.5, 7 + s * sw * 0.5), 3.2, Paint()..color = Colors.white);
  }
  c.drawCircle(const Offset(0, -6), 10.5, Paint()..color = Colors.white);
  c.drawOval(Rect.fromCenter(center: const Offset(0, -6), width: 15, height: 12),
      Paint()..color = danger ? const Color(0xFF7F1D1D) : const Color(0xFF1E3A8A));
  c.drawOval(
      Rect.fromCenter(center: const Offset(-2.5, -8.5), width: 4.5, height: 2.5),
      Paint()..color = Colors.white.withOpacity(0.6));
}

// Personaje suelto (menú, lista de niveles, pantalla final)
class HeroPainter extends CustomPainter {
  final Animation<double> anim;
  final int kind;
  final double scale;
  HeroPainter(this.anim, this.kind, this.scale) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    paintCharacter(canvas, kind, size.center(Offset.zero), scale, t);
  }

  @override
  bool shouldRepaint(covariant HeroPainter old) => true;
}

// ==========================================
// 1. MENÚ PRINCIPAL
// ==========================================
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Widget _enter(int order, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + order * 120),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: c),
      ),
      child: child,
    );
  }

  Widget _button(String text, IconData icon, VoidCallback onTap,
      {bool primary = false}) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: primary
          ? ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: shape),
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(text,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                  shape: shape),
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(text),
            ),
    );
  }

  void _go(Widget page) {
    _sfx();
    Navigator.of(context)
        .push(_fadeRoute(page))
        .then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _enter(
                      0,
                      SizedBox(
                        width: 150,
                        height: 110,
                        child: CustomPaint(painter: HeroPainter(_anim, 0, 2.6)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _enter(
                      1,
                      const Text('Eco',
                          style: TextStyle(
                              fontSize: 46,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                              color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    _enter(
                      2,
                      const Text(
                        'Encuentra el final del laberinto\nguiándote por la vibración y tu memoria',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15, color: Colors.white60, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 40),
                    _enter(
                      3,
                      _button('JUGAR', Icons.play_arrow_rounded,
                          () => _go(const LevelSelectScreen()),
                          primary: true),
                    ),
                    const SizedBox(height: 14),
                    _enter(
                      4,
                      _button('INSTRUCCIONES', Icons.menu_book_rounded,
                          () => _go(const InstructionsScreen())),
                    ),
                    const SizedBox(height: 14),
                    _enter(
                      5,
                      _button('CONFIGURACIÓN', Icons.settings_rounded,
                          () => _go(const SettingsScreen())),
                    ),
                    const SizedBox(height: 32),
                    _enter(
                      6,
                      Text('Mejor puntuación: ${EcoStore.best}',
                          style: const TextStyle(
                              color: Colors.amberAccent, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. ELEGIR NIVEL (se desbloquean al avanzar)
// ==========================================
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Widget _card(int i) {
    final th = kThemes[i];
    final unlocked = i < EcoStore.unlocked;
    final completed = i < EcoStore.unlocked - 1;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + i * 120),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 30 * (1 - v)), child: child),
      ),
      child: Opacity(
        opacity: unlocked ? 1 : 0.55,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: th.bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: unlocked ? th.accent : Colors.white24, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: unlocked
                ? () {
                    _sfx();
                    Navigator.of(context)
                        .push(_fadeRoute(GameScreen(startLevel: i)))
                        .then((_) => setState(() {}));
                  }
                : () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Completa el nivel $i para desbloquear este.')),
                    ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: unlocked
                        ? CustomPaint(painter: HeroPainter(_anim, th.kind, 1.5))
                        : const Icon(Icons.lock, size: 36, color: Colors.white38),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NIVEL ${i + 1}',
                            style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                        Text(th.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(th.hero,
                            style: const TextStyle(color: Colors.white60)),
                        const SizedBox(height: 2),
                        Text('Memoriza: ${kLevels[i].memorySeconds} s',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (completed)
                    const Icon(Icons.check_circle, color: Colors.greenAccent)
                  else if (unlocked)
                    Icon(Icons.play_circle_fill, color: th.accent, size: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elige un nivel'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: kLevels.length,
        itemBuilder: (context, i) => _card(i),
      ),
    );
  }
}

// ==========================================
// 3. CONFIGURACIÓN
// ==========================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar progreso'),
        content: const Text(
            'Se bloquearán de nuevo los niveles y se borrará tu mejor puntuación.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reiniciar')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        EcoStore.unlocked = 1;
        EcoStore.best = 0;
      });
      EcoStore.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
                EcoStore.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: Colors.cyanAccent),
            title: const Text('Sonido', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Efectos al empezar, chocar y ganar'),
            value: EcoStore.sound,
            onChanged: (v) {
              setState(() => EcoStore.sound = v);
              EcoStore.save();
              if (v) SystemSound.play(SystemSoundType.click);
            },
          ),
          const Divider(height: 32),
          const Text('Controles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('¿Cómo quieres mover a tu personaje?',
              style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('📱 Inclinación'),
                selected: EcoStore.control == ControlMode.tilt,
                onSelected: (_) {
                  setState(() => EcoStore.control = ControlMode.tilt);
                  EcoStore.save();
                },
              ),
              ChoiceChip(
                label: const Text('⬆️➡️⬇️⬅️ Flechas'),
                selected: EcoStore.control == ControlMode.arrows,
                onSelected: (_) {
                  setState(() => EcoStore.control = ControlMode.arrows);
                  EcoStore.save();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            EcoStore.control == ControlMode.tilt
                ? 'Inclina el teléfono para mover al personaje. Si tu teléfono no tiene sensor, aparecerán las flechas.'
                : 'Usa las flechas en pantalla (o las del teclado en la computadora).',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const Divider(height: 40),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent)),
            onPressed: _confirmReset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reiniciar progreso'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. INSTRUCCIONES
// ==========================================
class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  Widget _step(IconData icon, String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
            ),
            child: Icon(icon, color: Colors.cyanAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(text,
                    style: const TextStyle(color: Colors.white70, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instrucciones'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _step(Icons.visibility, '1. Memoriza',
              'Al empezar verás el laberinto unos segundos (de 7 a 10 según el nivel). Fíjate bien en el camino de INICIO a FIN.'),
          _step(Icons.visibility_off, '2. Avanza a ciegas',
              'Cuando el laberinto desaparece, mueve a tu personaje desde INICIO hasta FIN recordando el camino.'),
          _step(Icons.vibration, '3. Siente la vibración',
              'Mientras más cerca estés de la pared, más fuerte y más seguido vibra el teléfono. Si vibra mucho, ¡corrige!'),
          _step(Icons.favorite, '4. Tienes 3 vidas',
              'Si tocas la pared pierdes una vida y regresas al inicio. Sin vidas, el nivel se reinicia.'),
          _step(Icons.screen_rotation, '5. Controles',
              'Inclina el teléfono o usa las flechas. Puedes cambiarlo en Configuración.'),
          _step(Icons.lock_open, '6. Desbloquea niveles',
              'Pasa un nivel para abrir el siguiente. ¡Son 5 mundos con un personaje distinto cada uno!'),
        ],
      ),
    );
  }
}

// ==========================================
// 5. JUEGO
// ==========================================
class GameScreen extends StatefulWidget {
  final int startLevel;
  const GameScreen({super.key, this.startLevel = 0});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  static const int maxLives = 3;

  late int level;
  late int memoryTime;
  int totalScore = 0;
  int streak = 0;
  int lives = maxLives;
  bool isMemoryPhase = true;
  bool isGameOver = false;
  bool isVictory = false;
  bool isDanger = false;
  double _dangerK = 0;
  int _runId = 0;
  double _facing = 1;

  Offset playerPos = const Offset(0.12, 0.92);
  final List<Offset> _trail = [];

  LevelData get data => kLevels[level];
  LevelTheme get th => kThemes[level];
  Offset get startPoint => data.points.first;
  Offset get endPoint => data.points.last;
  bool get isLastLevel => level == kLevels.length - 1;

  Size _board = Size.zero;
  final FocusNode _focus = FocusNode();
  final Set<String> _held = {};

  Timer? _memoryTimer;
  Timer? _loop;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  late final AnimationController _fx = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();
  late final AnimationController _bg = AnimationController(
      vsync: this, duration: const Duration(seconds: 12))
    ..repeat();
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420), value: 1);
  late final AnimationController _flash = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500), value: 1);
  late final AnimationController _reveal = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  double _ax = 0, _ay = 0, _sumX = 0, _sumY = 0, _baseX = 0, _baseY = 0;
  int _samples = 0;
  bool _calibrated = false;
  bool _hasSensor = false;

  DateTime _lastBuzz = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _safeUntil = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    level = widget.startLevel;
    memoryTime = data.memorySeconds;
    playerPos = startPoint;
    _listenTilt();
    startMemoryPhase();
    _reveal.forward(from: 0);
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _listenTilt() {
    try {
      // Si tu versión de sensors_plus es antigua, usa accelerometerEvents.listen(...)
      _accelSub = accelerometerEventStream().listen((e) {
        _hasSensor = true;
        _ax = e.x;
        _ay = e.y;
        if (isMemoryPhase) {
          _sumX += e.x;
          _sumY += e.y;
          _samples++;
        }
      }, onError: (Object _) {});
    } catch (_) {}
  }

  void startMemoryPhase() {
    _memoryTimer?.cancel();
    _sumX = 0;
    _sumY = 0;
    _samples = 0;
    _calibrated = false;
    _memoryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (memoryTime > 1) {
        setState(() => memoryTime--);
      } else {
        timer.cancel();
        if (_samples > 0) {
          _baseX = _sumX / _samples;
          _baseY = _sumY / _samples;
          _calibrated = true;
        }
        setState(() => isMemoryPhase = false);
        _buzz(120, 120);
        _sfx();
      }
    });
  }

  // Teclado: flechas y W, A, S, D
  void _onKey(KeyEvent event) {
    String? k;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      k = 'up';
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      k = 'down';
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      k = 'left';
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      k = 'right';
    }
    if (k == null) return;
    if (event is KeyUpEvent) {
      _held.remove(k);
    } else {
      _held.add(k);
    }
  }

  void _tick() {
    if (!mounted || isMemoryPhase || isGameOver || isVictory) return;
    if (_board == Size.zero) return;

    double dx = 0, dy = 0;
    const keySpeed = 2.4;
    if (_held.contains('left')) dx -= keySpeed;
    if (_held.contains('right')) dx += keySpeed;
    if (_held.contains('up')) dy -= keySpeed;
    if (_held.contains('down')) dy += keySpeed;

    if (EcoStore.control == ControlMode.tilt && _calibrated) {
      final tx = _baseX - _ax;
      final ty = _ay - _baseY;
      if (tx.abs() > 0.5) dx += tx * 0.6;
      if (ty.abs() > 0.5) dy += ty * 0.6;
    }

    dx = dx.clamp(-3.2, 3.2);
    dy = dy.clamp(-3.2, 3.2);
    if (dx == 0 && dy == 0) {
      if (_trail.isNotEmpty) setState(() => _trail.removeAt(0));
      return;
    }
    if (dx.abs() > 0.2) _facing = dx > 0 ? 1.0 : -1.0;
    _move(dx, dy);
  }

  void _move(double dx, double dy) {
    final w = _board.width, h = _board.height;
    final px = (playerPos.dx * w + dx).clamp(0.0, w);
    final py = (playerPos.dy * h + dy).clamp(0.0, h);
    final pos = Offset(px, py);

    final pts = data.points.map((p) => Offset(p.dx * w, p.dy * h)).toList();
    final half = data.halfWidth * w;
    final ratio = _distToPath(pos, pts) / half;

    if ((pos - pts.last).distance < half) {
      setState(() => playerPos = Offset(px / w, py / h));
      _win();
      return;
    }

    if (ratio >= 1.0) {
      if (DateTime.now().isAfter(_safeUntil)) _hit();
      return;
    }

    if (ratio > 0.6) {
      final k = ((ratio - 0.6) / 0.4).clamp(0.0, 1.0);
      final interval = (260 - 200 * k).round();
      if (DateTime.now().difference(_lastBuzz).inMilliseconds > interval) {
        _buzz(40, (50 + 205 * k).round());
      }
    }

    setState(() {
      playerPos = Offset(px / w, py / h);
      isDanger = ratio > 0.6;
      _dangerK = ratio > 0.6 ? ((ratio - 0.6) / 0.4).clamp(0.0, 1.0) : 0;
      _trail.add(playerPos);
      if (_trail.length > 22) _trail.removeAt(0);
    });
  }

  double _distToPath(Offset p, List<Offset> pts) {
    var best = double.infinity;
    for (var i = 0; i < pts.length - 1; i++) {
      best = math.min(best, _distToSegment(p, pts[i], pts[i + 1]));
    }
    return best;
  }

  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq)
        .clamp(0.0, 1.0);
    return (p - Offset(a.dx + ab.dx * t, a.dy + ab.dy * t)).distance;
  }

  Future<void> _buzz(int duration, int amplitude) async {
    _lastBuzz = DateTime.now();
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: duration, amplitude: amplitude.clamp(1, 255));
    }
  }

  void _hit() {
    _buzz(300, 255);
    _sfx();
    _safeUntil = DateTime.now().add(const Duration(milliseconds: 900));
    _shake.forward(from: 0);
    _flash.forward(from: 0);
    setState(() {
      lives--;
      isDanger = false;
      _dangerK = 0;
      _trail.clear();
      if (lives <= 0) {
        isGameOver = true;
        streak = 0;
        EcoStore.best = math.max(EcoStore.best, totalScore);
        EcoStore.save();
      } else {
        playerPos = startPoint;
      }
    });
  }

  void _win() {
    _buzz(200, 200);
    _sfx();
    setState(() {
      isVictory = true;
      isDanger = false;
      _dangerK = 0;
      totalScore += 100 * (level + 1) + lives * 25;
      streak++;
      EcoStore.best = math.max(EcoStore.best, totalScore);
      // Desbloquea el siguiente nivel
      EcoStore.unlocked =
          math.max(EcoStore.unlocked, math.min(kLevels.length, level + 2));
      EcoStore.save();
    });
  }

  void _resetLevel() {
    _held.clear();
    _trail.clear();
    _runId++;
    _reveal.forward(from: 0);
    setState(() {
      lives = maxLives;
      memoryTime = data.memorySeconds;
      isMemoryPhase = true;
      isGameOver = false;
      isVictory = false;
      isDanger = false;
      _dangerK = 0;
      playerPos = startPoint;
    });
    startMemoryPhase();
  }

  void _onPrimaryButton() {
    if (isVictory) {
      if (isLastLevel) {
        level = 0;
        totalScore = 0;
        streak = 0;
      } else {
        level++;
      }
    }
    _resetLevel();
  }

  @override
  void dispose() {
    _memoryTimer?.cancel();
    _loop?.cancel();
    _accelSub?.cancel();
    _fx.dispose();
    _bg.dispose();
    _shake.dispose();
    _flash.dispose();
    _reveal.dispose();
    _focus.dispose();
    super.dispose();
  }

  Widget _heart(bool filled) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: Icon(
        filled ? Icons.favorite : Icons.favorite_border,
        key: ValueKey(filled),
        color: Colors.redAccent,
        size: 26,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showMaze = isMemoryPhase || isGameOver || isVictory;
    final showPad =
        EcoStore.control == ControlMode.arrows || !_hasSensor;
    final playing = !isMemoryPhase && !isGameOver && !isVictory;

    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 84,
                      child: Row(
                          children:
                              List.generate(maxLives, (i) => _heart(i < lives))),
                    ),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: Text(
                              'Nivel ${level + 1} · ${th.name}',
                              key: ValueKey(level),
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 92,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: isMemoryPhase
                              ? _memoryChip()
                              : const SizedBox(key: ValueKey('none')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // El laberinto siempre mantiene la proporción 3:4
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: AnimatedBuilder(
                      animation: _shake,
                      builder: (context, child) {
                        final s = _shake.value;
                        final dx = math.sin(s * math.pi * 10) * 9 * (1 - s);
                        return Transform.translate(
                            offset: Offset(dx, 0), child: child);
                      },
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: th.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: th.accent.withOpacity(0.4)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LayoutBuilder(builder: (context, c) {
                            _board = Size(c.maxWidth, c.maxHeight);
                            final w = c.maxWidth, h = c.maxHeight;
                            return Stack(
                              children: [
                                // Fondo animado del mundo
                                CustomPaint(
                                  size: Size.infinite,
                                  painter: BackdropPainter(_bg, th.kind),
                                ),
                                // Laberinto
                                AnimatedOpacity(
                                  opacity: showMaze ? 1 : 0,
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOut,
                                  child: AnimatedBuilder(
                                    animation: _reveal,
                                    builder: (context, _) => CustomPaint(
                                      size: Size.infinite,
                                      painter: MazePainter(
                                        data,
                                        th,
                                        Curves.easeInOut
                                            .transform(_reveal.value),
                                      ),
                                    ),
                                  ),
                                ),
                                _tag(startPoint, 'INICIO', Colors.green,
                                    Colors.white, w, h, false),
                                _tag(endPoint, 'FIN', Colors.amber,
                                    Colors.black, w, h, true),
                                // Personaje, estela y meta
                                CustomPaint(
                                  size: Size.infinite,
                                  painter: FxPainter(
                                    fx: _fx,
                                    trail: List<Offset>.of(_trail),
                                    player: playerPos,
                                    dangerK: _dangerK,
                                    end: endPoint,
                                    kind: th.kind,
                                    facing: _facing,
                                    theme: th,
                                  ),
                                ),
                                if (playing)
                                  Align(
                                    alignment: const Alignment(0, 0.97),
                                    child: AnimatedDefaultTextStyle(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      style: TextStyle(
                                        color: isDanger
                                            ? Colors.redAccent
                                            : Colors.white54,
                                        fontSize: 14,
                                        fontWeight: isDanger
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      child: Text(isDanger
                                          ? '⚠️ ¡CUIDADO, CERCA DEL BORDE!'
                                          : 'Guíate por la vibración'),
                                    ),
                                  ),
                                IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _flash,
                                    builder: (context, _) => Container(
                                      color: Colors.redAccent.withOpacity(
                                          0.38 * (1 - _flash.value)),
                                    ),
                                  ),
                                ),
                                if (isGameOver || isVictory) _endOverlay(),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (showPad)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _padButton('up', Icons.keyboard_arrow_up),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _padButton('left', Icons.keyboard_arrow_left),
                          _padButton('down', Icons.keyboard_arrow_down),
                          _padButton('right', Icons.keyboard_arrow_right),
                        ],
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memoryChip() {
    return Container(
      key: const ValueKey('chip'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amberAccent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('timer$_runId'),
              tween: Tween(begin: 1.0, end: 0.0),
              duration: Duration(seconds: data.memorySeconds),
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 2.5,
                color: Colors.amberAccent,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('${memoryTime}s',
              style: const TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ],
      ),
    );
  }

  Widget _tag(Offset p, String text, Color bg, Color fg, double w, double h,
      bool toLeft) {
    return Positioned(
      left: toLeft ? null : p.dx * w + 20,
      right: toLeft ? w - (p.dx * w - 20) : null,
      top: p.dy * h - 11,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
      ),
    );
  }

  Widget _padButton(String dir, IconData icon) {
    return Listener(
      onPointerDown: (_) => _held.add(dir),
      onPointerUp: (_) => _held.remove(dir),
      onPointerCancel: (_) => _held.remove(dir),
      child: Container(
        width: 60,
        height: 42,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: th.accent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: th.accent.withOpacity(0.6)),
        ),
        child: Icon(icon, color: th.accent),
      ),
    );
  }

  Widget _endOverlay() {
    final allDone = isVictory && isLastLevel;
    final title = allDone
        ? '¡Completaste los 5 niveles!'
        : isVictory
            ? 'Nivel ${level + 1} completado'
            : '¡Te saliste del camino!';
    final buttonText = allDone
        ? 'JUGAR DE NUEVO'
        : isVictory
            ? 'SIGUIENTE NIVEL'
            : 'REINTENTAR NIVEL';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
      ),
      child: Container(
        color: Colors.black.withOpacity(0.78),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isVictory)
                SizedBox(
                  width: 150,
                  height: 100,
                  child: CustomPaint(painter: HeroPainter(_fx, th.kind, 2.3)),
                )
              else
                const Icon(Icons.heart_broken, size: 64, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: totalScore),
                duration: const Duration(milliseconds: 900),
                builder: (context, v, _) => Text(
                    'Puntuación: $v  |  Racha: $streak',
                    style: const TextStyle(color: Colors.amberAccent)),
              ),
              if (isVictory && !isLastLevel)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('¡Nuevo nivel desbloqueado!',
                      style: TextStyle(color: Colors.greenAccent)),
                ),
              const SizedBox(height: 22),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black),
                onPressed: _onPrimaryButton,
                child: Text(buttonText),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ELEGIR NIVEL'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PINTORES DEL JUEGO
// ==========================================
class MazePainter extends CustomPainter {
  final LevelData data;
  final LevelTheme theme;
  final double progress;
  MazePainter(this.data, this.theme, this.progress);

  @override
  void paint(Canvas canvas, Size size) =>
      paintMaze(canvas, size, data, theme, progress);

  @override
  bool shouldRepaint(covariant MazePainter old) =>
      old.data != data || old.theme != theme || old.progress != progress;
}

// Fondo animado de cada mundo
class BackdropPainter extends CustomPainter {
  final Animation<double> anim;
  final int kind;
  BackdropPainter(this.anim, this.kind) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    final w = size.width, h = size.height;
    for (var i = 0; i < 28; i++) {
      final k = (i % 3) + 1;
      final bx = _r(i + 1.0) * w;
      final ph = (_r(i + 9.0) + t * k) % 1.0;
      final sway = math.sin(t * 2 * math.pi * k + i);
      switch (kind) {
        case 0: // polvo de cueva
          canvas.drawCircle(
              Offset(bx + sway * 8, h * (1 - ph)),
              0.8 + _r(i + 4.0) * 1.4,
              Paint()
                ..color = const Color(0xFFC4B5FD)
                    .withOpacity(0.08 + _r(i + 2.0) * 0.15));
          break;
        case 1: // burbujas
          canvas.drawCircle(
              Offset(bx + sway * 7, h * (1 - ph)),
              2 + _r(i + 4.0) * 4,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1
                ..color = Colors.white.withOpacity(0.22));
          break;
        case 2: // hojas que caen
          canvas.save();
          canvas.translate(bx + sway * 14, h * ph);
          canvas.rotate(t * 2 * math.pi * k + i);
          canvas.drawOval(
              Rect.fromCenter(center: Offset.zero, width: 7, height: 3.5),
              Paint()
                ..color = (i.isEven
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFDC2626))
                    .withOpacity(0.5));
          canvas.restore();
          break;
        case 3: // lluvia de datos neón
          canvas.drawRect(
              Rect.fromLTWH(bx, h * ph, 1.5, 10 + _r(i + 4.0) * 16),
              Paint()
                ..color = (i.isEven
                        ? const Color(0xFF22D3EE)
                        : const Color(0xFFFF2BD6))
                    .withOpacity(0.25));
          break;
        default: // estrellas que titilan
          final tw = 0.3 + 0.7 * sway.abs();
          canvas.drawCircle(
              Offset(bx, _r(i + 9.0) * h),
              0.7 + _r(i + 4.0) * 1.3,
              Paint()..color = Colors.white.withOpacity(0.7 * tw));
      }
    }
  }

  @override
  bool shouldRepaint(covariant BackdropPainter old) => old.kind != kind;
}

// Personaje, estela y meta (sin ondas)
class FxPainter extends CustomPainter {
  final Animation<double> fx;
  final List<Offset> trail;
  final Offset player;
  final double dangerK;
  final Offset end;
  final int kind;
  final double facing;
  final LevelTheme theme;

  FxPainter({
    required this.fx,
    required this.trail,
    required this.player,
    required this.dangerK,
    required this.end,
    required this.kind,
    required this.facing,
    required this.theme,
  }) : super(repaint: fx);

  @override
  void paint(Canvas canvas, Size size) {
    final t = fx.value;
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    Offset px(Offset n) => Offset(n.dx * size.width, n.dy * size.height);
    final color = Color.lerp(theme.accent, Colors.redAccent, dangerK)!;
    final c = px(player);

    // Meta: portal dorado
    final g = px(end);
    canvas.drawCircle(
        g,
        16,
        Paint()
          ..color = const Color(0xFFFBBF24).withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(g, 11 + 1.5 * math.sin(now * 4),
        Paint()..color = const Color(0xFFFBBF24).withOpacity(0.9));
    canvas.save();
    canvas.translate(g.dx, g.dy);
    canvas.rotate(now * 1.5);
    final ray = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 1.5;
    for (var i = 0; i < 4; i++) {
      canvas.rotate(math.pi / 4);
      canvas.drawLine(const Offset(-8, 0), const Offset(8, 0), ray);
    }
    canvas.restore();
    for (var i = 0; i < 2; i++) {
      final ph = (t + i * 0.5) % 1.0;
      canvas.drawCircle(
          g,
          12 + 22 * ph,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFFBBF24).withOpacity((1 - ph) * 0.5));
    }

    // Estela
    for (var i = 0; i < trail.length; i++) {
      final k = (i + 1) / trail.length;
      canvas.drawCircle(px(trail[i]), 1.5 + 4 * k,
          Paint()..color = color.withOpacity(0.35 * k));
    }

    // Personaje del nivel
    paintCharacter(canvas, kind, c, 1.0, now,
        danger: dangerK > 0.3, fast: dangerK > 0.3, facing: facing);
  }

  @override
  bool shouldRepaint(covariant FxPainter old) => true;
}
