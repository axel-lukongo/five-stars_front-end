import 'package:flutter/material.dart';
import '../theme_config/colors_config.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDarkMode ? myLightBackground : MyprimaryDark;
    final Color iconColor = isDarkMode ? myAccentVibrantBlue : MyprimaryDark;

    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(Icons.search, color: iconColor),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Terrains à Proximité',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: Card(
                  elevation: 10,
                  color: isDarkMode
                      ? MyprimaryDark
                      : myAccentVibrantBlue.withOpacity(0.1),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.location_on, size: 60, color: iconColor),
                        const SizedBox(height: 10),
                        Text(
                          "Carte Interactive (Urban Soccer, Five)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        Text(
                          "Centres affichés sur une carte fluide et zoomable.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Créneaux Disponibles",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),
              _buildPitchCard(
                context,
                "Urban Soccer Paris 17",
                "5 terrains, Prochain créneau: 19:00",
              ),
              _buildPitchCard(
                context,
                "Le Five Saint-Ouen",
                "3 terrains, Prochain créneau: 20:30",
              ),
              _buildPitchCard(
                context,
                "Foot Time La Défense",
                "4 terrains, Prochain créneau: 18:00",
              ),
              _buildPitchCard(
                context,
                "Sport Indoor Créteil",
                "2 terrains, Prochain créneau: 21:00",
              ),
              _buildPitchCard(
                context,
                "Urban Soccer Puteaux",
                "6 terrains, Prochain créneau: 19:30",
              ),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPitchCard(BuildContext context, String title, String subtitle) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color cardTitleColor = isDarkMode ? myLightBackground : MyprimaryDark;
    final Color cardSubtitleColor =
        isDarkMode ? Colors.grey[400]! : Colors.black54;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        leading: const Icon(
          Icons.sports_soccer,
          color: myAccentVibrantBlue,
          size: 36,
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: cardTitleColor),
        ),
        subtitle: Text(subtitle, style: TextStyle(color: cardSubtitleColor)),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode
                ? MyprimaryDark
                : myAccentVibrantBlue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
          ),
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Afficher les détails de $title')),
          );
        },
      ),
    );
  }
}