import 'package:flutter/material.dart';
import '../theme_config/colors_config.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDarkMode ? myLightBackground : MyprimaryDark;

    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: <Widget>[
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
              color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
            ),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ouvrir l\'édition du profil')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mon Profil',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              CircleAvatar(
                radius: 60,
                backgroundImage: const AssetImage('assets/images/paris.jpg'),
                backgroundColor: isDarkMode
                    ? myAccentVibrantBlue.withOpacity(0.8)
                    : MyprimaryDark.withOpacity(0.8),
              ),
              const SizedBox(height: 15),
              Text(
                'Jean Dupont',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              Text(
                'Paris | j.dupont@email.com',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildProfileDetail(
                        Icons.local_fire_department,
                        'Niveau de Jeu',
                        'Intermédiaire (3 ans)',
                        myAccentVibrantBlue,
                        isDarkMode,
                      ),
                      const Divider(),
                      _buildProfileDetail(
                        Icons.calendar_month,
                        'Prochaine Réservation',
                        'Le 15/12 à 20h00 - Le Five',
                        MyprimaryDark,
                        isDarkMode,
                      ),
                      const Divider(),
                      _buildProfileDetail(
                        Icons.sports_soccer,
                        'Poste Préféré',
                        'Attaquant / Buteur',
                        myAccentVibrantBlue,
                        isDarkMode,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  Provider.of<AuthProvider>(context, listen: false).logout();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Déconnecté')));
                },
                icon: const Icon(Icons.logout, color: myAccentVibrantBlue),
                label: const Text(
                  'Déconnexion',
                  style: TextStyle(
                    color: myAccentVibrantBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyprimaryDark,
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

  Widget _buildProfileDetail(
    IconData icon,
    String label,
    String value,
    Color color,
    bool isDarkMode,
  ) {
    final Color valueColor = isDarkMode ? myLightBackground : MyprimaryDark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 16, color: valueColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
