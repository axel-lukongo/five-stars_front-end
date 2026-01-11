import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme_config/colors_config.dart';
import '../providers/auth_provider.dart';
import '../auth/login.dart';
import 'edit_profile_page.dart';

class SettingsPage extends StatelessWidget {
  final AuthProvider authProvider;

  const SettingsPage({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDarkMode ? myLightBackground : MyprimaryDark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Paramètres',
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Compte
            Text(
              'Compte',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 16),

            // Carte pour l'édition du profil
            _buildGlassContainer(
              isDarkMode: isDarkMode,
              child: ListTile(
                leading: Icon(
                  Icons.edit,
                  color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
                  size: 28,
                ),
                title: Text(
                  'Modifier mon profil',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: const Text(
                  'Mettre à jour mes informations personnelles',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
                  size: 16,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Carte pour la suppression du compte
            _buildGlassContainer(
              isDarkMode: isDarkMode,
              child: ListTile(
                leading: Icon(
                  Icons.delete_forever,
                  color: Colors.red[700],
                  size: 28,
                ),
                title: Text(
                  'Supprimer mon compte',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: const Text(
                  'Action irréversible - toutes vos données seront perdues',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.red[700],
                  size: 16,
                ),
                onTap: () => _showDeleteAccountDialog(context, isDarkMode),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassContainer({
    required bool isDarkMode,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [
                      Colors.grey[850]!.withOpacity(0.6),
                      Colors.grey[900]!.withOpacity(0.4),
                    ]
                  : [
                      Colors.white.withOpacity(0.8),
                      Colors.grey[50]!.withOpacity(0.6),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
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

  void _showDeleteAccountDialog(BuildContext context, bool isDarkMode) {
    final TextEditingController confirmationController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red[700], size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Supprimer mon compte',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cette action est IRRÉVERSIBLE et entraînera :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('• Suppression de toutes vos données personnelles'),
              const Text(
                '• Suppression de vos équipes (si vous êtes propriétaire)',
              ),
              const Text('• Retrait de toutes les équipes où vous êtes membre'),
              const Text('• Suppression de votre historique de matchs'),
              const Text('• Suppression de tous vos messages'),
              const SizedBox(height: 20),
              Text(
                'Pour confirmer, tapez "SUPPRIMER" :',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmationController,
                decoration: InputDecoration(
                  hintText: 'SUPPRIMER',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            StatefulBuilder(
              builder: (context, setState) {
                return ElevatedButton(
                  onPressed: () async {
                    if (confirmationController.text == 'SUPPRIMER') {
                      // Fermer le dialogue de confirmation
                      Navigator.of(dialogContext).pop();

                      // Afficher un indicateur de chargement
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext loadingContext) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      );

                      // Supprimer le compte
                      final success = await authProvider.deleteAccount();

                      // Fermer l'indicateur de chargement
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }

                      if (success) {
                        // Rediriger vers la page de connexion avec un message de succès
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(
                                successMessage:
                                    'Votre compte a été supprimé avec succès',
                              ),
                            ),
                            (route) => false,
                          );
                        }
                      } else {
                        // Afficher un message d'erreur
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Erreur lors de la suppression du compte',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } else {
                      // Le texte ne correspond pas
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Veuillez taper "SUPPRIMER" pour confirmer',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirmer la suppression'),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
