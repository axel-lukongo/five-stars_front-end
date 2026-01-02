import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme_config/colors_config.dart';
import '../widgets/win_rate_gauge.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../auth/login.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatelessWidget {
  Widget _buildGlassContainer({
    required Widget child,
    required Gradient gradient,
    double borderRadius = 20,
    double blur = 10,
    List<BoxShadow>? boxShadow,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow:
                boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Gradient gradient,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
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
                  _buildGlassContainer(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [
                              myAccentVibrantBlue.withOpacity(0.18),
                              Colors.black.withOpacity(0.10),
                            ]
                          : [
                              myAccentVibrantBlue.withOpacity(0.13),
                              Colors.white.withOpacity(0.10),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
                  _buildGlassActionButton(
                    onPressed: () async {
                      await authProvider.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      }
                    },
                    icon: Icons.logout,
                    label: 'Déconnexion',
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.orange.withOpacity(0.8),
                        Colors.orange.withOpacity(0.6),
                      ],
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(
              'Matchs',
              user.matchesPlayed.toString(),
              isDarkMode,
              emoji: '⚽',
            ),
            _buildStatItem(
              'Victoires',
              user.matchesWon.toString(),
              isDarkMode,
              emoji: '🏆',
            ),
            _buildStatItem(
              'Défaites',
              user.matchesLost.toString(),
              isDarkMode,
              emoji: '❌',
            ),
            WinRateGauge(winRate: user.winRate / 100.0, isDarkMode: isDarkMode),
          ],
        ),
        const SizedBox(height: 10),
        Divider(
          color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
          thickness: 1.2,
          indent: 10,
          endIndent: 10,
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    bool isDarkMode, {
    String? emoji,
  }) {
    return Column(
      children: [
        if (emoji != null) Text(emoji, style: const TextStyle(fontSize: 18)),
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
