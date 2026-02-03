import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

/// Interaktive Tagesreflektion mit Atemübung, Fragen und Zusammenfassung
class DayReflectionScreen extends StatefulWidget {
  const DayReflectionScreen({super.key});

  @override
  State<DayReflectionScreen> createState() => _DayReflectionScreenState();
}

class _DayReflectionScreenState extends State<DayReflectionScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0; // 0: Atemübung, 1-5: Fragen, 6: Zusammenfassung
  
  // Atemübung
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;
  late Animation<double> _pulseAnimation;
  int _breathCount = 0;
  int _totalBreaths = 5;
  bool _breathIn = true;
  Timer? _breathTimer;
  
  // Fragen
  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Was war heute dein größter Erfolg?',
      'icon': Icons.celebration_rounded,
      'color': Color(0xFF10B981),
      'hint': 'Denk an etwas, worauf du stolz bist.',
    },
    {
      'question': 'Was würdest du heute anders machen?',
      'icon': Icons.lightbulb_rounded,
      'color': Color(0xFF3B82F6),
      'hint': 'Jeder Tag ist eine Lektion.',
    },
    {
      'question': 'Wofür bist du heute dankbar?',
      'icon': Icons.favorite_rounded,
      'color': Color(0xFFEC4899),
      'hint': 'Auch kleine Dinge zählen.',
    },
    {
      'question': 'Wie hat sich dein Körper heute angefühlt?',
      'icon': Icons.accessibility_new_rounded,
      'color': Color(0xFFF97316),
      'hint': 'Höre auf deinen Körper.',
    },
    {
      'question': 'Was wünschst du dir für morgen?',
      'icon': Icons.auto_awesome_rounded,
      'color': Color(0xFF8B5CF6),
      'hint': 'Setze dir ein kleines Ziel.',
    },
  ];
  
  final List<String> _answers = [];
  
  // Zusammenfassung
  final Random _random = Random();
  List<String> _motivationalMessages = [
    'Du machst große Fortschritte! 🌱',
    'Jeder Tag ist eine neue Chance! ✨',
    'Du bist auf dem richtigen Weg! 💚',
    'Kleine Schritte führen zum Ziel! 🎯',
    'Du schaffst das! 💪',
  ];

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _breathAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(
        parent: _breathController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _breathController,
        curve: Curves.easeInOut,
      ),
    );
    _startBreathing();
  }

  void _startBreathing() {
    _breathController.repeat(reverse: true);
    _breathTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      setState(() {
        _breathIn = !_breathIn;
        if (!_breathIn) {
          _breathCount++;
          HapticFeedback.lightImpact();
          if (_breathCount >= _totalBreaths) {
            timer.cancel();
            _breathController.stop();
            _breathController.reset();
            Future.delayed(const Duration(milliseconds: 800), () {
              setState(() {
                _currentStep = 1;
              });
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _breathController.dispose();
    _breathTimer?.cancel();
    super.dispose();
  }

  void _nextQuestion() {
    if (_currentStep <= _questions.length) {
      setState(() {
        _currentStep++;
      });
      HapticFeedback.selectionClick();
    }
  }

  void _saveAnswer(String answer) {
    if (_currentStep > 0 && _currentStep <= _questions.length) {
      if (_answers.length < _currentStep) {
        _answers.add(answer);
      } else {
        _answers[_currentStep - 1] = answer;
      }
    }
  }

  void _finish() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEvening = DateTime.now().hour >= 16;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            _buildContent(colors, isEvening),
            // Close Button (top)
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: colors.onSurface),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colors, bool isEvening) {
    if (_currentStep == 0) {
      return _buildBreathingExercise(colors);
    } else if (_currentStep > 0 && _currentStep <= _questions.length) {
      return _buildQuestion(colors, _currentStep - 1);
    } else {
      return _buildSummary(colors);
    }
  }

  Widget _buildBreathingExercise(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Lass uns zur Ruhe kommen',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Nimm dir einen Moment Zeit\nund konzentriere dich auf deine Atmung',
            style: TextStyle(
              fontSize: 16,
              color: colors.onSurface.withOpacity(0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 80),
          // Animierter Kreis mit mehreren Layern
          AnimatedBuilder(
            animation: _breathAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulse
                  Transform.scale(
                    scale: _breathAnimation.value * 1.3,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981).withOpacity(
                          0.1 * (1 - _pulseAnimation.value),
                        ),
                      ),
                    ),
                  ),
                  // Middle pulse
                  Transform.scale(
                    scale: _breathAnimation.value * 1.15,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981).withOpacity(
                          0.15 * (1 - _pulseAnimation.value),
                        ),
                      ),
                    ),
                  ),
                  // Main circle
                  Transform.scale(
                    scale: _breathAnimation.value,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF10B981),
                            const Color(0xFF059669),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _breathIn ? 'Einatmen' : 'Ausatmen',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 60),
          // Progress
          Column(
            children: [
              Text(
                '$_breathCount von $_totalBreaths Atemzügen',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface.withOpacity(0.8),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 6,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _breathCount / _totalBreaths,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF10B981),
                          Color(0xFF059669),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(ColorScheme colors, int questionIndex) {
    final question = _questions[questionIndex];
    final TextEditingController controller = TextEditingController(
      text: questionIndex < _answers.length ? _answers[questionIndex] : '',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Indicator
          Row(
            children: List.generate(
              _questions.length,
              (index) => Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(
                    right: index < _questions.length - 1 ? 4 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: index <= questionIndex
                        ? const Color(0xFF10B981)
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Question Number
          Text(
            'Frage ${questionIndex + 1} von ${_questions.length}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),
          // Question Text
          Text(
            question['question'] as String,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
              height: 1.3,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            question['hint'] as String,
            style: TextStyle(
              fontSize: 15,
              color: colors.onSurface.withOpacity(0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 40),
          // Text Input
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.outlineVariant.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: controller,
              maxLines: 8,
              style: TextStyle(
                fontSize: 16,
                color: colors.onSurface,
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: 'Schreibe deine Gedanken auf...',
                hintStyle: TextStyle(
                  color: colors.onSurface.withOpacity(0.4),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
              ),
              onChanged: (value) => _saveAnswer(value),
              autofocus: true,
            ),
          ),
          const SizedBox(height: 32),
          // Next Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _saveAnswer(controller.text);
                _nextQuestion();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                questionIndex < _questions.length - 1
                    ? 'Weiter'
                    : 'Zur Zusammenfassung',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(ColorScheme colors) {
    final now = DateTime.now();
    final month = now.month;
    final monthName = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
    ][month - 1];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF10B981),
                  Color(0xFF059669),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 56,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                Text(
                  _motivationalMessages[_random.nextInt(_motivationalMessages.length)],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Monats-Statistiken
          Text(
            'Dein $monthName im Überblick',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.outlineVariant.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildStatRow(
                  colors,
                  Icons.local_fire_department_rounded,
                  'Streak',
                  '${_random.nextInt(20) + 5} Tage',
                  const Color(0xFFF97316),
                ),
                const SizedBox(height: 20),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.outlineVariant.withOpacity(0.2),
                ),
                const SizedBox(height: 20),
                _buildStatRow(
                  colors,
                  Icons.restaurant_menu_rounded,
                  'Rezepte gekocht',
                  '${_random.nextInt(30) + 15}',
                  const Color(0xFF10B981),
                ),
                const SizedBox(height: 20),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.outlineVariant.withOpacity(0.2),
                ),
                const SizedBox(height: 20),
                _buildStatRow(
                  colors,
                  Icons.favorite_rounded,
                  'Favoriten',
                  '${_random.nextInt(20) + 10}',
                  const Color(0xFFEC4899),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Deine Antworten
          Text(
            'Deine heutigen Gedanken',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            _questions.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.outlineVariant.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (_questions[index]['color'] as Color).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _questions[index]['icon'] as IconData,
                            size: 20,
                            color: _questions[index]['color'] as Color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _questions[index]['question'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface.withOpacity(0.9),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (index < _answers.length && _answers[index].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, left: 44),
                        child: Text(
                          _answers[index],
                          style: TextStyle(
                            fontSize: 15,
                            color: colors.onSurface.withOpacity(0.7),
                            height: 1.5,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 12, left: 44),
                        child: Text(
                          '(Keine Antwort)',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.onSurface.withOpacity(0.4),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Finish Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _finish,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Abschließen',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    ColorScheme colors,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: color,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withOpacity(0.8),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
