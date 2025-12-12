import 'package:flutter/material.dart';
import '../theme_config/colors_config.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const double _playerAvatarRadius = 25;
  static const double _playerAvatarDiameter = _playerAvatarRadius * 2;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDarkMode ? myLightBackground : MyprimaryDark;
    final Color pitchColor =
        isDarkMode ? Colors.green[800]! : Colors.green[600]!;
    final Color lineColor = isDarkMode ? Colors.white70 : Colors.white;

    final List<String> substitutePlayers = <String>[
      'Joueur A',
      'Joueur B',
      'Joueur C',
      'Joueur D',
    ];

    return Scaffold(
      appBar: AppBar(title: null),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Mon Équipe',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 20),

              // Mini terrain
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: pitchColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: lineColor, width: 2),
                ),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double pitchWidth = constraints.maxWidth;
                    const double pitchHeight = 250;

                    const double minPlayerLeftPos = 20;
                    final double maxPlayerLeftPos =
                        (pitchWidth / 2) - _playerAvatarDiameter - 20;

                    final double segmentSpacing =
                        (maxPlayerLeftPos - minPlayerLeftPos) / 4;

                    return Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(painter: _PitchPainter(lineColor)),
                        ),

                        // Joueurs (5)
                        Positioned(
                          left: minPlayerLeftPos,
                          top: pitchHeight / 2 - _playerAvatarRadius - 15,
                          child: _buildPlayerDisplay(
                            'Gardien',
                            'G',
                            isDarkMode,
                          ),
                        ),
                        Positioned(
                          left: minPlayerLeftPos + segmentSpacing,
                          top: pitchHeight * 0.25 - _playerAvatarRadius - 15,
                          child: _buildPlayerDisplay('Hugo', 'D1', isDarkMode),
                        ),
                        Positioned(
                          left: minPlayerLeftPos + segmentSpacing,
                          top: pitchHeight * 0.75 - _playerAvatarRadius - 15,
                          child: _buildPlayerDisplay('Léo', 'D2', isDarkMode),
                        ),
                        Positioned(
                          left: minPlayerLeftPos + 2 * segmentSpacing,
                          top: pitchHeight / 2 - _playerAvatarRadius - 15,
                          child: _buildPlayerDisplay('Sam', 'M', isDarkMode),
                        ),
                        Positioned(
                          left: minPlayerLeftPos + 3 * segmentSpacing,
                          top: pitchHeight / 2 - _playerAvatarRadius - 15,
                          child: _buildPlayerDisplay('Tom', 'A', isDarkMode),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Remplaçants',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 10.0,
                runSpacing: 10.0,
                children: substitutePlayers.map<Widget>((String playerName) {
                  return _buildSubstitutePlayer(playerName, isDarkMode);
                }).toList(),
              ),

              const SizedBox(height: 40),

              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Recherche d'adversaires...")),
                  );
                },
                icon: const Icon(Icons.search, color: MyprimaryDark),
                label: const Text(
                  'Trouver des adversaires',
                  style: TextStyle(
                    color: MyprimaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: myAccentVibrantBlue,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
              ),

              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerDisplay(String playerName, String label, bool isDarkMode) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CircleAvatar(
          radius: _playerAvatarRadius,
          backgroundColor: myAccentVibrantBlue,
          child: Text(
            label,
            style: const TextStyle(
              color: MyprimaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          playerName,
          style: TextStyle(
            color: isDarkMode ? myLightBackground : MyprimaryDark,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSubstitutePlayer(String name, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? MyprimaryDark.withOpacity(0.7) : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? myAccentVibrantBlue.withOpacity(0.3)
              : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            radius: 12,
            backgroundColor: myAccentVibrantBlue.withOpacity(0.7),
            child: Text(
              name[0],
              style: const TextStyle(
                color: MyprimaryDark,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              color: isDarkMode ? myLightBackground : MyprimaryDark,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.add_circle_outline,
            size: 18,
            color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
          ),
        ],
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  final Color lineColor;

  _PitchPainter(this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Rectangle extérieur
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Ligne médiane
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Cercle central
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.height * 0.15,
      paint,
    );

    // Surfaces
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        size.height * 0.25,
        size.width * 0.15,
        size.height * 0.5,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.85,
        size.height * 0.25,
        size.width * 0.15,
        size.height * 0.5,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}