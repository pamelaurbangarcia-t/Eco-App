import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(const EcoGameApp());
}

class EcoGameApp extends StatelessWidget {
  const EcoGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eco Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const EcoGameScreen(),
    );
  }
}

class EcoGameScreen extends StatefulWidget {
  const EcoGameScreen({super.key});

  @override
  State<EcoGameScreen> createState() => _EcoGameScreenState();
}

class _EcoGameScreenState extends State<EcoGameScreen> {
  StreamSubscription? _accelerometerSubscription;

  final List<String> _directions = ['Arriba', 'Abajo', 'Izquierda', 'Derecha'];
  final List<String> _sequence = [];
  int _userStep = 0;
  int _score = 0;
  bool _isPlaying = false;
  bool _isShowingSequence = false;
  String _message = 'Presiona "Iniciar Juego" para comenzar';
  String _activeDirection = '';

  @override
  void initState() {
    super.initState();
    _initSensors();
  }

  void _initSensors() {
    try {
      _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
        if (!_isPlaying || _isShowingSequence || !mounted) return;

        if (event.y < -4.0) {
          _handleUserInput('Arriba');
        } else if (event.y > 4.0) {
          _handleUserInput('Abajo');
        } else if (event.x > 4.0) {
          _handleUserInput('Izquierda');
        } else if (event.x < -4.0) {
          _handleUserInput('Derecha');
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _sequence.clear();
      _score = 0;
      _isPlaying = true;
      _message = '¡Atento a la secuencia!';
    });
    _nextRound();
  }

  void _nextRound() async {
    _userStep = 0;
    final random = Random();
    _sequence.add(_directions[random.nextInt(_directions.length)]);

    if (!mounted) return;
    setState(() {
      _isShowingSequence = true;
      _message = 'Memoriza la secuencia...';
    });

    for (String dir in _sequence) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _activeDirection = dir;
      });
      _vibrate(100);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _activeDirection = '';
      });
    }

    if (!mounted) return;
    setState(() {
      _isShowingSequence = false;
      _message = '¡Tu turno! Replica la secuencia';
    });
  }

  void _handleUserInput(String direction) {
    if (!_isPlaying || _isShowingSequence) return;

    _vibrate(80);

    if (_sequence[_userStep] == direction) {
      _userStep++;
      if (_userStep == _sequence.length) {
        setState(() {
          _score++;
          _message = '¡Correcto! Siguiente nivel...';
        });
        Future.delayed(const Duration(seconds: 1), _nextRound);
      }
    } else {
      _vibrate(500);
      setState(() {
        _isPlaying = false;
        _message = '¡Juego Terminado! Puntuación final: $_score';
      });
    }
  }

  void _vibrate(int duration) async {
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: duration);
      }
    } catch (_) {}
  }

  Color _getButtonColor(String direction) {
    if (_activeDirection == direction) {
      return Colors.amber;
    }
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eco - Memoria y Reflejos'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Puntuación: $_score',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _message,
              style: const TextStyle(fontSize: 18, color: Colors.cyanAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            Column(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _getButtonColor('Arriba')),
                  onPressed: () => _handleUserInput('Arriba'),
                  child: const Icon(Icons.arrow_upward, size: 40),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _getButtonColor('Izquierda')),
                      onPressed: () => _handleUserInput('Izquierda'),
                      child: const Icon(Icons.arrow_back, size: 40),
                    ),
                    const SizedBox(width: 50),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _getButtonColor('Derecha')),
                      onPressed: () => _handleUserInput('Derecha'),
                      child: const Icon(Icons.arrow_forward, size: 40),
                    ),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _getButtonColor('Abajo')),
                  onPressed: () => _handleUserInput('Abajo'),
                  child: const Icon(Icons.arrow_downward, size: 40),
                ),
              ],
            ),

            const SizedBox(height: 40),

            if (!_isPlaying)
              ElevatedButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar Juego', style: TextStyle(fontSize: 20)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
          ],
        ),
      ),
    );
  }
}