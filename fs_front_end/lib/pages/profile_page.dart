import 'package:flutter/material.dart';
import '../theme_config/colors_config.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../auth/login.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDarkMode ? myLightBackground : MyprimaryDark;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final UserModel? user = authProvider.currentUser;

        // Si l'utilisateur n'est pas chargé, afficher un loader
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: null),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: null,
            actions: <Widget>[
              IconButton(
                icon: Icon(
                  isDarkMode
                      ? Icons.wb_sunny_outlined
                      : Icons.dark_mode_outlined,
                  color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
                ),
                onPressed: () {
                  Provider.of<ThemeProvider>(
                    context,
                    listen: false,
                  ).toggleTheme();
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ouvrir l\'édition du profil'),
                    ),
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
                    backgroundImage:
                        user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                        ? NetworkImage(user.avatarUrl!)
                        : const AssetImage('assets/images/paris.jpg')
                              as ImageProvider,
                    backgroundColor: isDarkMode
                        ? myAccentVibrantBlue.withOpacity(0.8)
                        : MyprimaryDark.withOpacity(0.8),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    user.username,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  Text(
                    user.email ?? 'Email non renseigné',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      user.bio!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  // Statistiques
                  _buildStatsRow(user, isDarkMode),
                  const SizedBox(height: 30),
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _buildProfileDetail(
                            Icons.sports_soccer,
                            'Poste Préféré',
                            user.preferredPosition ?? 'Non renseigné',
                            myAccentVibrantBlue,
                            isDarkMode,
                          ),
                          const Divider(),
                          _buildProfileDetail(
                            Icons.phone,
                            'Téléphone',
                            user.phone ?? 'Non renseigné',
                            MyprimaryDark,
                            isDarkMode,
                          ),
                          const Divider(),
                          _buildProfileDetail(
                            Icons.star,
                            'Note',
                            user.rating != null
                                ? '${user.rating!.toStringAsFixed(1)} / 5'
                                : 'Pas encore noté',
                            myAccentVibrantBlue,
                            isDarkMode,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await authProvider.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      }
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
      },
    );
  }

  Widget _buildStatsRow(UserModel user, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Matchs', user.matchesPlayed.toString(), isDarkMode),
        _buildStatItem('Victoires', user.matchesWon.toString(), isDarkMode),
        _buildStatItem('Défaites', user.matchesLost.toString(), isDarkMode),
        _buildStatItem(
          'Win Rate',
          '${user.winRate.toStringAsFixed(0)}%',
          isDarkMode,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, bool isDarkMode) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: myAccentVibrantBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
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
