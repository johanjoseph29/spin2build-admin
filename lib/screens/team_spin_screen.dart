import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class TeamSpinScreen extends StatefulWidget {
  static const String routeName = '/team-spin';

  const TeamSpinScreen({super.key});

  @override
  State<TeamSpinScreen> createState() => _TeamSpinScreenState();
}

class _TeamSpinScreenState extends State<TeamSpinScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isValidating = false;
  String? _errorMessage;
  Map<String, dynamic>? _teamData;
  String? _assignedTopicTitle;

  // Wheel animation
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _currentAngle = 0.0;
  bool _isSpinning = false;
  List<String> _wheelSegments = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _teamData = null;
      _assignedTopicTitle = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final code = _codeController.text.trim().toUpperCase();
      final res = await api.post('/team/validate', body: {'code': code});

      if (res is Map<String, dynamic>) {
        setState(() {
          _teamData = res;
          if (res['assignment'] != null) {
            _assignedTopicTitle = res['assignment']['title'] as String?;
          }
          if (res['available_topics'] != null && res['available_topics'] is List) {
            final list = (res['available_topics'] as List)
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList();
            if (list.isNotEmpty) {
              _wheelSegments = list;
            }
          }
        });
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Validation error: $e');
    } finally {
      if (mounted) {
        setState(() => _isValidating = false);
      }
    }
  }

  Future<void> _loadTopicsForWheel() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final topics = await api.getTopics();
      final titles = topics
          .where((t) => t['assigned'] != true)
          .map((t) => t['title'].toString())
          .toList();

      if (mounted) {
        setState(() {
          _wheelSegments = titles.isNotEmpty
              ? titles
              : [
                  'AI Chatbot',
                  'Health Tracker',
                  'Campus Portal',
                  'Smart Finance',
                  'Eco Hub',
                  'Cyber Vault'
                ];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _wheelSegments = [
            'AI Chatbot',
            'Health Tracker',
            'Campus Portal',
            'Smart Finance',
            'Eco Hub',
            'Cyber Vault'
          ];
        });
      }
    }
  }

  Future<void> _spinWheel() async {
    if (_isSpinning || _teamData == null) return;

    setState(() {
      _isSpinning = true;
      _errorMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final code = _teamData!['code'] as String;
      final res = await api.post('/team/spin', body: {'code': code});

      final topicTitle = res['title'] as String? ?? 'Assigned Topic';

      // Ensure the won topic is in the wheel segments so it lands directly on it!
      if (!_wheelSegments.contains(topicTitle)) {
        _wheelSegments.insert(0, topicTitle);
      }
      final targetIndex = _wheelSegments.indexOf(topicTitle);
      final segmentAngle = (2 * math.pi) / _wheelSegments.length;
      
      // Calculate target rotation angle so the top arrow points at the chosen topic:
      // The top arrow is at -pi/2 (270 degrees)
      final segmentCenterAngle = (targetIndex * segmentAngle) + (segmentAngle / 2);
      final stopAngle = (3 * math.pi / 2) - segmentCenterAngle;

      final fullSpins = (6 + math.Random().nextInt(3)) * 2 * math.pi;
      final targetAngle = _currentAngle + fullSpins + ((stopAngle - (_currentAngle % (2 * math.pi))) % (2 * math.pi));

      _animation = Tween<double>(
        begin: _currentAngle,
        end: targetAngle,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      )..addListener(() {
          setState(() {
            _currentAngle = _animation.value;
          });
        });

      _animationController.reset();
      await _animationController.forward();

      if (mounted) {
        setState(() {
          _assignedTopicTitle = topicTitle;
          _isSpinning = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isSpinning = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSpinning = false;
          _errorMessage = 'Spin failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark competition theme
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: Color(0xFF00D2FF), size: 26),
            SizedBox(width: 8),
            Text(
              'SPIN2BUILD',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(LoginScreen.routeName);
            },
            icon: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white70, size: 18),
            label: const Text(
              'Admin Login',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: _teamData == null ? _buildCodeEntryCard() : _buildWheelCard(),
          ),
        ),
      ),
    );
  }

  // --- Step 1: Team Access Code Entry ---
  Widget _buildCodeEntryCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.casino_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Team Topic Wheel',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the 6-character access code provided by the organizer',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 28),

              if (_errorMessage != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.3),
                    border: Border.all(color: Colors.red.shade400),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFF87171), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              color: Color(0xFFFCA5A5), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Access Code Input
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: 'CODE12',
                  hintStyle: TextStyle(
                    color: Colors.white24,
                    letterSpacing: 6,
                    fontFamily: 'monospace',
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your access code';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _validateCode(),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isValidating ? null : _validateCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isValidating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Join Topic Selection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step 2: The Interactive Fortune Wheel ---
  Widget _buildWheelCard() {
    final teamName = _teamData?['team_name'] as String? ?? 'Team';
    final hasAssigned = _assignedTopicTitle != null;

    return Card(
      elevation: 8,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Team Header Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group_rounded,
                      color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    teamName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _teamData = null;
                        _assignedTopicTitle = null;
                        _codeController.clear();
                      });
                    },
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_errorMessage != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // If already assigned
            if (hasAssigned) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B).withOpacity(0.4),
                  border: Border.all(color: const Color(0xFF059669), width: 1.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.stars_rounded,
                        color: Color(0xFF34D399), size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'YOUR ASSIGNED TOPIC',
                      style: TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _assignedTopicTitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your topic has been registered in the competition database.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ] else ...[
              // The Spinning Wheel
              Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: _currentAngle,
                    child: CustomPaint(
                      size: const Size(280, 280),
                      painter: _WheelPainter(
                        segments: _wheelSegments.isNotEmpty
                            ? _wheelSegments
                            : ['Spin', 'To', 'Build', 'Winner'],
                      ),
                    ),
                  ),
                  // Pointer at top
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 24,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black38, blurRadius: 4)
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_drop_down,
                            color: Color(0xFFDC2626), size: 24),
                      ),
                    ),
                  ),
                  // Center Hub
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 8)
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.bolt_rounded,
                          color: Color(0xFF00D2FF), size: 30),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: 200,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSpinning ? null : _spinWheel,
                  icon: _isSpinning
                      ? const SizedBox.shrink()
                      : const Icon(Icons.rotate_right_rounded, size: 24),
                  label: _isSpinning
                      ? const Text('SPINNING...',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16))
                      : const Text('SPIN THE WHEEL',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<String> segments;

  _WheelPainter({required this.segments});

  static const List<Color> _palette = [
    Color(0xFF6366F1),
    Color(0xFF06B6D4),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF3B82F6),
    Color(0xFF14B8A6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final total = segments.length;
    final sweepAngle = (2 * math.pi) / total;

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white24;

    for (int i = 0; i < total; i++) {
      paint.color = _palette[i % _palette.length];
      final startAngle = i * sweepAngle;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      // Draw label
      final textAngle = startAngle + (sweepAngle / 2);
      final textRadius = radius * 0.65;
      final textX = center.dx + (textRadius * math.cos(textAngle));
      final textY = center.dy + (textRadius * math.sin(textAngle));

      final span = TextSpan(
        text: segments[i].length > 12
            ? '${segments[i].substring(0, 10)}..'
            : segments[i],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );

      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 60);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + (math.pi / 2));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}
