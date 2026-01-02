import 'package:flutter/material.dart';

class WinRateGauge extends StatelessWidget {
  final double winRate; // 0.0 à 1.0
  final bool isDarkMode;
  const WinRateGauge({
    super.key,
    required this.winRate,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (winRate * 100).clamp(0, 100).toInt();
    return Column(
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: winRate,
                strokeWidth: 7,
                backgroundColor: isDarkMode
                    ? Colors.grey[800]
                    : Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  winRate > 0.7
                      ? Colors.green
                      : winRate > 0.4
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Win Rate',
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
