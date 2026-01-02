import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../theme_config/colors_config.dart';
import '../models/user_model.dart';
import '../providers/friends_provider.dart';
import '../services/friends_service.dart';
import '../services/auth_service.dart';

/// Page pour afficher le profil d'un autre utilisateur
class UserProfilePage extends StatefulWidget {
  final UserModel? user;
  final UserBasicInfo? userBasicInfo;
  final bool showAddFriendButton;

  const UserProfilePage({
    super.key,
    this.user,
    this.userBasicInfo,
    this.showAddFriendButton = false,
  }) : assert(user != null || userBasicInfo != null);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
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

  UserModel? _fullUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFullUserProfile();
  }

  Future<void> _loadFullUserProfile() async {
    // Si on a déjà un UserModel complet, l'utiliser directement
    if (widget.user != null) {
      setState(() {
        _fullUser = widget.user;
        _isLoading = false;
      });
      return;
    }

    // Sinon, charger le profil complet depuis le backend
    if (widget.userBasicInfo != null) {
      try {
        final userData = await AuthService.instance.getUserProfile(
          widget.userBasicInfo!.id,
        );
        if (userData != null && mounted) {
          setState(() {
            _fullUser = UserModel.fromJson(userData);
            _isLoading = false;
          });
        } else if (mounted) {
          // En cas d'échec, utiliser les données basiques disponibles
          setState(() {
            _fullUser = UserModel(
              id: widget.userBasicInfo!.id,
              username: widget.userBasicInfo!.username,
              avatarUrl: widget.userBasicInfo!.avatarUrl,
              preferredPosition: widget.userBasicInfo!.preferredPosition,
              rating: widget.userBasicInfo!.rating,
            );
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _fullUser = UserModel(
              id: widget.userBasicInfo!.id,
              username: widget.userBasicInfo!.username,
              avatarUrl: widget.userBasicInfo!.avatarUrl,
              preferredPosition: widget.userBasicInfo!.preferredPosition,
              rating: widget.userBasicInfo!.rating,
            );
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDarkMode ? myLightBackground : MyprimaryDark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = _fullUser!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user.username,
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 20),
              // Avatar
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
              // Nom d'utilisateur
              Text(
                user.username,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              // Email (si disponible)
              if (user.email != null && user.email!.isNotEmpty)
                Text(
                  user.email!,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              // Bio
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
              // Détails du profil
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
              // Bouton Ajouter en ami (si applicable)
              if (widget.showAddFriendButton) ...[
                const SizedBox(height: 30),
                _buildFriendActionButton(user),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendActionButton(UserModel user) {
    return Consumer<FriendsProvider>(
      builder: (context, friendsProvider, _) {
        // Vérifier si déjà ami ou demande en attente
        final isAlreadyFriend = friendsProvider.friends.any(
          (f) => f.user.id == user.id,
        );
        final hasPendingSent = friendsProvider.pendingSent.any(
          (r) => r.user.id == user.id,
        );
        final hasPendingReceived = friendsProvider.pendingReceived.any(
          (r) => r.fromUser.id == user.id,
        );

        if (isAlreadyFriend) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Déjà ami',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        if (hasPendingSent) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_empty, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Demande envoyée',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        if (hasPendingReceived) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final request = friendsProvider.pendingReceived.firstWhere(
                    (r) => r.fromUser.id == user.id,
                  );
                  await friendsProvider.acceptFriendRequest(
                    request.friendshipId,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Demande acceptée !'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Accepter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final request = friendsProvider.pendingReceived.firstWhere(
                    (r) => r.fromUser.id == user.id,
                  );
                  await friendsProvider.rejectFriendRequest(
                    request.friendshipId,
                  );
                },
                icon: const Icon(Icons.close),
                label: const Text('Refuser'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          );
        }

        return ElevatedButton.icon(
          onPressed: () async {
            await friendsProvider.sendFriendRequest(user.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Demande envoyée à ${user.username}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          icon: const Icon(Icons.person_add),
          label: const Text('Ajouter en ami'),
          style: ElevatedButton.styleFrom(
            backgroundColor: myAccentVibrantBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
          style: const TextStyle(
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
