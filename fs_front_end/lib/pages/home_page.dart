import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../theme_config/colors_config.dart';
import '../providers/teams_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/auth_provider.dart';
import '../services/teams_service.dart';
import 'discover_teams_page.dart';
import 'team_chat_page.dart';
import 'find_opponents_page.dart';
import 'match_chat_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _playerAvatarRadius = 25;
  static const double _playerAvatarDiameter = _playerAvatarRadius * 2;

  // État pour le mode recherche d'adversaire
  bool _isLookingForOpponent = false;
  bool _isLoadingSearchPrefs = false;
  TeamSearchPreference? _searchPreference;
  int? _lastLoadedTeamId;

  // État pour les matchs à venir
  List<MatchChallenge> _upcomingMatches = [];
  bool _isLoadingMatches = false;

  // État pour les messages non lus des matchs
  Map<int, int> _unreadMatchMessages = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TeamsProvider>();
      provider.loadMyTeam();
      // Démarrer le polling pour les notifications en temps réel
      provider.startChatPolling();
      // Ajouter un listener pour recharger les préférences quand l'équipe change
      provider.addListener(_onTeamChanged);
      // Charger les préférences de recherche
      _loadSearchPreferences();
    });
  }

  /// Callback quand l'équipe change
  void _onTeamChanged() {
    final provider = context.read<TeamsProvider>();
    final currentTeam = provider.currentDisplayedTeam;

    // Recharger les préférences si l'équipe a changé
    if (currentTeam != null && currentTeam.id != _lastLoadedTeamId) {
      _loadSearchPreferences();
    }
  }

  /// Charge les préférences de recherche pour l'équipe actuelle
  Future<void> _loadSearchPreferences() async {
    final provider = context.read<TeamsProvider>();
    final team = provider.currentDisplayedTeam;

    // Si pas d'équipe ou pas membre de cette équipe
    if (team == null || !provider.isPartOfCurrentTeam) {
      setState(() {
        _isLookingForOpponent = false;
        _searchPreference = null;
        _lastLoadedTeamId = team?.id;
        _upcomingMatches = [];
      });
      return;
    }

    _lastLoadedTeamId = team.id;
    setState(() => _isLoadingSearchPrefs = true);

    try {
      // Charger les matchs pour tous les membres
      final matchesFuture = TeamsService.instance.getTeamMatches(
        team.id,
        status: 'accepted',
      );

      // Les préférences de recherche ne sont chargées que pour l'owner
      if (provider.isCurrentTeamMine) {
        final results = await Future.wait([
          TeamsService.instance.getSearchPreferences(team.id),
          matchesFuture,
          TeamsService.instance.getAllUnreadCounts(),
        ]);

        if (mounted) {
          setState(() {
            _searchPreference = results[0] as TeamSearchPreference?;
            _isLookingForOpponent =
                _searchPreference?.isLookingForOpponent ?? false;
            _upcomingMatches = results[1] as List<MatchChallenge>;
            _unreadMatchMessages = results[2] as Map<int, int>;
            _isLoadingSearchPrefs = false;
          });
        }
      } else {
        // Membre mais pas owner : charger uniquement les matchs
        final results = await Future.wait([
          matchesFuture,
          TeamsService.instance.getAllUnreadCounts(),
        ]);

        if (mounted) {
          setState(() {
            _searchPreference = null;
            _isLookingForOpponent = false;
            _upcomingMatches = results[0] as List<MatchChallenge>;
            _unreadMatchMessages = results[1] as Map<int, int>;
            _isLoadingSearchPrefs = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSearchPrefs = false);
      }
    }
  }

  /// Recharge les matchs à venir
  Future<void> _loadUpcomingMatches() async {
    final provider = context.read<TeamsProvider>();
    final team = provider.currentDisplayedTeam;
    if (team == null) return;

    setState(() => _isLoadingMatches = true);

    try {
      final matches = await TeamsService.instance.getTeamMatches(
        team.id,
        status: 'accepted',
      );
      if (mounted) {
        setState(() {
          _upcomingMatches = matches;
          _isLoadingMatches = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMatches = false);
      }
    }
  }

  /// Bascule le mode recherche d'adversaire
  Future<void> _toggleSearchMode(bool value) async {
    final provider = context.read<TeamsProvider>();
    final team = provider.currentDisplayedTeam;
    if (team == null) return;

    setState(() => _isLookingForOpponent = value);

    try {
      final result = await TeamsService.instance.updateSearchPreferences(
        team.id,
        isLookingForOpponent: value,
        preferredDays: _searchPreference?.preferredDays,
        preferredTimeSlots: _searchPreference?.preferredTimeSlots,
        preferredLocations: _searchPreference?.preferredLocations,
        skillLevel: _searchPreference?.skillLevel,
        description: _searchPreference?.description,
      );

      if (result != null && mounted) {
        setState(() => _searchPreference = result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? '🔍 Mode recherche activé ! Les autres équipes peuvent maintenant vous trouver.'
                  : 'Mode recherche désactivé.',
            ),
            backgroundColor: value ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      // Revenir à l'état précédent en cas d'erreur
      if (mounted) {
        setState(() => _isLookingForOpponent = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la mise à jour'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Widget pour activer/désactiver le mode recherche d'adversaire
  Widget _buildSearchModeToggle(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isLookingForOpponent
            ? myAccentVibrantBlue.withOpacity(0.15)
            : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isLookingForOpponent
              ? myAccentVibrantBlue
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isLookingForOpponent ? Icons.visibility : Icons.visibility_off,
            color: _isLookingForOpponent
                ? myAccentVibrantBlue
                : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode recherche d\'adversaire',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _isLookingForOpponent
                        ? (isDarkMode ? Colors.white : MyprimaryDark)
                        : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                  ),
                ),
                Text(
                  _isLookingForOpponent
                      ? 'Votre équipe est visible pour les adversaires'
                      : 'Activez pour être trouvé par d\'autres équipes',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoadingSearchPrefs)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: _isLookingForOpponent,
              onChanged: _toggleSearchMode,
              activeColor: myAccentVibrantBlue,
            ),
        ],
      ),
    );
  }

  /// Section des matchs à venir
  Widget _buildUpcomingMatchesSection(
    int myTeamId,
    bool isDarkMode,
    Color titleColor,
    bool isOwner,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.sports_soccer, color: myAccentVibrantBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              'Matchs à venir',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: myAccentVibrantBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_upcomingMatches.length}',
                style: const TextStyle(
                  color: myAccentVibrantBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._upcomingMatches.map(
          (match) => _buildMatchCard(match, myTeamId, isDarkMode, isOwner),
        ),
      ],
    );
  }

  /// Carte pour afficher un match
  Widget _buildMatchCard(
    MatchChallenge match,
    int myTeamId,
    bool isDarkMode,
    bool isOwner,
  ) {
    final isChallenger = match.challengerTeamId == myTeamId;
    final opponentName = match.getOpponentName(myTeamId);
    final opponentLogo = match.getOpponentLogoUrl(myTeamId);
    final hasSubmitted = match.hasSubmittedScore(myTeamId);
    final opponentSubmittedScore = match.getOpponentSubmittedScore(myTeamId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: myAccentVibrantBlue.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec adversaire
          Row(
            children: [
              // Logo adversaire
              CircleAvatar(
                radius: 24,
                backgroundColor: myAccentVibrantBlue.withOpacity(0.2),
                backgroundImage: opponentLogo != null
                    ? NetworkImage(opponentLogo)
                    : null,
                child: opponentLogo == null
                    ? Text(
                        opponentName[0].toUpperCase(),
                        style: const TextStyle(
                          color: myAccentVibrantBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'vs $opponentName',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : MyprimaryDark,
                      ),
                    ),
                    Text(
                      isChallenger ? 'Défi envoyé' : 'Défi reçu',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Bouton chat avec badge de messages non lus
              _buildMatchChatButton(match, myTeamId, isDarkMode),
              const SizedBox(width: 8),
              // Statut
              _buildMatchStatusBadge(match, hasSubmitted, isDarkMode),
            ],
          ),
          const SizedBox(height: 12),
          // Infos du match
          if (match.proposedDate != null || match.proposedLocation != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (match.proposedDate != null)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatMatchDate(match.proposedDate!),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white : MyprimaryDark,
                          ),
                        ),
                      ],
                    ),
                  if (match.proposedDate != null &&
                      match.proposedLocation != null)
                    const SizedBox(height: 8),
                  if (match.proposedLocation != null)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            match.proposedLocation!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white : MyprimaryDark,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Afficher le score de l'adversaire s'il a soumis et que je n'ai pas soumis
          if (opponentSubmittedScore != null && !hasSubmitted) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'L\'adversaire a soumis le score suivant :',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
                                ? Colors.orange[200]
                                : Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Affichage du score avec noms d'équipes
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Équipe challenger
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                match.challengerTeamName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${opponentSubmittedScore['challengerScore']}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.blue[300]
                                        : Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Séparateur
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '-',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                        // Équipe challengée
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                match.challengedTeamName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${opponentSubmittedScore['challengedScore']}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.red[300]
                                        : Colors.red[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Boutons Valider / Contester - seulement pour l'owner
                  if (isOwner) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _contestMatchScore(match),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Contester'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _validateMatchScore(match),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Valider'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '⚠️ Si vous contestez → Match nul (0-0)',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    // Message pour les membres non-owner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'En attente de la validation du score par le capitaine',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.orange[300]
                                    : Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ]
          // Si j'ai déjà soumis, attente de validation
          else if (hasSubmitted) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.hourglass_empty,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Score soumis ! En attente de validation par l\'adversaire.',
                      style: TextStyle(color: Colors.green[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ]
          // Personne n'a soumis - seul l'owner peut soumettre
          else if (isOwner) ...[
            ElevatedButton.icon(
              onPressed: () => _showSubmitScoreDialog(match, myTeamId),
              icon: const Icon(Icons.scoreboard, size: 18),
              label: const Text('Enregistrer le résultat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: myAccentVibrantBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ]
          // Membre mais pas owner - afficher un message
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'En attente que le capitaine enregistre le résultat.',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Badge de statut du match
  Widget _buildMatchStatusBadge(
    MatchChallenge match,
    bool hasSubmitted,
    bool isDarkMode,
  ) {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    if (match.scoreConflict) {
      bgColor = Colors.red.withOpacity(0.1);
      textColor = Colors.red;
      text = 'Conflit';
      icon = Icons.warning;
    } else if (hasSubmitted) {
      bgColor = Colors.orange.withOpacity(0.1);
      textColor = Colors.orange;
      text = 'En attente';
      icon = Icons.hourglass_empty;
    } else {
      bgColor = myAccentVibrantBlue.withOpacity(0.1);
      textColor = myAccentVibrantBlue;
      text = 'À jouer';
      icon = Icons.sports_soccer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton de chat pour un match avec badge de messages non lus
  Widget _buildMatchChatButton(
    MatchChallenge match,
    int myTeamId,
    bool isDarkMode,
  ) {
    final unreadCount = _unreadMatchMessages[match.id] ?? 0;
    final isChallenger = match.challengerTeamId == myTeamId;
    final myTeamName = isChallenger
        ? match.challengerTeamName
        : match.challengedTeamName;
    final opponentName = match.getOpponentName(myTeamId);
    final opponentLogo = match.getOpponentLogoUrl(myTeamId);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchChatPage(
              challengeId: match.id,
              myTeamName: myTeamName,
              opponentTeamName: opponentName,
              opponentTeamLogoUrl: opponentLogo,
              myTeamId: myTeamId,
            ),
          ),
        );
        // Recharger les messages non lus après retour du chat
        _loadUnreadCounts();
      },
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: myAccentVibrantBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              color: myAccentVibrantBlue,
              size: 20,
            ),
          ),
          // Badge de messages non lus
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Recharge les compteurs de messages non lus
  Future<void> _loadUnreadCounts() async {
    final counts = await TeamsService.instance.getAllUnreadCounts();
    if (mounted) {
      setState(() {
        _unreadMatchMessages = counts;
      });
    }
  }

  /// Formater la date du match
  String _formatMatchDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final matchDay = DateTime(date.year, date.month, date.day);

    String dayText;
    if (matchDay == today) {
      dayText = "Aujourd'hui";
    } else if (matchDay == tomorrow) {
      dayText = 'Demain';
    } else {
      final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      final months = [
        'jan',
        'fév',
        'mar',
        'avr',
        'mai',
        'juin',
        'juil',
        'août',
        'sep',
        'oct',
        'nov',
        'déc',
      ];
      dayText =
          '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
    }

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$dayText à ${hour}h$minute';
  }

  /// Dialog pour soumettre le score
  Future<void> _showSubmitScoreDialog(
    MatchChallenge match,
    int myTeamId,
  ) async {
    final myScoreController = TextEditingController();
    final opponentScoreController = TextEditingController();
    final opponentName = match.getOpponentName(myTeamId);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enregistrer le résultat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Entrez le score du match contre $opponentName',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Votre équipe',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: myScoreController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '-',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          opponentName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: opponentScoreController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'L\'adversaire devra confirmer ce score pour qu\'il soit validé.',
                        style: TextStyle(color: Colors.blue[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final myScore = int.tryParse(myScoreController.text);
                final opponentScore = int.tryParse(
                  opponentScoreController.text,
                );
                if (myScore != null && opponentScore != null) {
                  Navigator.pop(context, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: myAccentVibrantBlue,
              ),
              child: const Text(
                'Valider',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final myScore = int.parse(myScoreController.text);
      final opponentScore = int.parse(opponentScoreController.text);

      final updated = await TeamsService.instance.submitMatchScore(
        match.id,
        myScore: myScore,
        opponentScore: opponentScore,
      );

      if (mounted) {
        if (updated != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                updated.scoreValidated
                    ? '✅ Score validé ! Les deux équipes ont confirmé le résultat.'
                    : '⏳ Score enregistré. En attente de confirmation de l\'adversaire.',
              ),
              backgroundColor: updated.scoreValidated
                  ? Colors.green
                  : Colors.orange,
            ),
          );
          _loadUpcomingMatches();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de l\'enregistrement du score'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Valider le score soumis par l'adversaire
  Future<void> _validateMatchScore(MatchChallenge match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider le score'),
        content: const Text('Confirmez-vous que ce score est correct ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await TeamsService.instance.validateMatchScore(
        match.id,
        validate: true,
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Score validé !'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUpcomingMatches();
      }
    }
  }

  /// Contester le score - résulte en match nul
  Future<void> _contestMatchScore(MatchChallenge match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contester le score'),
        content: const Text(
          'Si vous contestez ce score, le match sera déclaré nul (0-0).\n\n'
          'Êtes-vous sûr de vouloir contester ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Contester',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await TeamsService.instance.validateMatchScore(
        match.id,
        validate: false,
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Score contesté - Match nul déclaré (0-0)'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadUpcomingMatches();
      }
    }
  }

  @override
  void dispose() {
    // Retirer le listener
    try {
      context.read<TeamsProvider>().removeListener(_onTeamChanged);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDarkMode ? myLightBackground : MyprimaryDark;

    return Scaffold(
      appBar: AppBar(title: null),
      body: Consumer<TeamsProvider>(
        builder: (context, teamsProvider, _) {
          if (teamsProvider.state == TeamsLoadingState.loading &&
              teamsProvider.allTeams.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final allTeams = teamsProvider.allTeams;
          final currentIndex = teamsProvider.currentTeamIndex;

          return RefreshIndicator(
            onRefresh: () => teamsProvider.loadMyTeam(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildTeamHeader(
                      context: context,
                      teamsProvider: teamsProvider,
                      titleColor: titleColor,
                      isDarkMode: isDarkMode,
                    ),
                    // Widget pour activer le mode recherche d'adversaire
                    if (teamsProvider.isCurrentTeamMine &&
                        teamsProvider.currentDisplayedTeam != null)
                      _buildSearchModeToggle(isDarkMode),
                    const SizedBox(height: 20),
                    if (allTeams.isEmpty)
                      _buildEmptyTeamPlaceholder(isDarkMode)
                    else
                      _buildTeamPitch(
                        context,
                        team: teamsProvider.currentDisplayedTeam!,
                        isMyTeam: teamsProvider.isCurrentTeamMine,
                        isDarkMode: isDarkMode,
                      ),
                    const SizedBox(height: 10),
                    if (allTeams.length > 1)
                      _buildPageIndicators(
                        allTeams.length,
                        currentIndex,
                        isDarkMode,
                      ),
                    const SizedBox(height: 20),
                    if (teamsProvider.isCurrentTeamMine)
                      _buildSubstitutesSection(
                        context,
                        teamsProvider: teamsProvider,
                        titleColor: titleColor,
                        isDarkMode: isDarkMode,
                      )
                    else if (teamsProvider.currentDisplayedTeam != null)
                      _buildOtherTeamSubstitutes(
                        teamsProvider.currentDisplayedTeam!,
                        titleColor: titleColor,
                        isDarkMode: isDarkMode,
                      ),
                    const SizedBox(height: 20),
                    // Indicateur de candidatures en attente
                    if (teamsProvider.isCurrentTeamMine &&
                        teamsProvider.pendingApplicationsCount > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_active,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${teamsProvider.pendingApplicationsCount} candidature(s) en attente',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _showAllApplicationsDialog(context),
                              child: const Text('Voir'),
                            ),
                          ],
                        ),
                      ),
                    // Section des matchs à venir (visible pour tous les membres)
                    if (teamsProvider.isPartOfCurrentTeam &&
                        _upcomingMatches.isNotEmpty)
                      _buildUpcomingMatchesSection(
                        teamsProvider.currentDisplayedTeam!.id,
                        isDarkMode,
                        titleColor,
                        teamsProvider.isCurrentTeamMine,
                      ),
                    const SizedBox(height: 10),
                    // Bouton pour trouver une équipe
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DiscoverTeamsPage(),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.person_search,
                        color: isDarkMode ? Colors.orange : Colors.orange[700],
                      ),
                      label: Text(
                        'Trouver une équipe',
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.orange
                              : Colors.orange[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: BorderSide(
                          color: isDarkMode
                              ? Colors.orange
                              : Colors.orange[700]!,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Bouton pour trouver des adversaires
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FindOpponentsPage(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.sports_soccer,
                        color: MyprimaryDark,
                      ),
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
        },
      ),
    );
  }

  /// Widget pour le bouton de chat avec badge de messages non lus
  Widget _buildChatButton({
    required BuildContext context,
    required TeamDetail team,
    required int unreadCount,
    required bool isDarkMode,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.chat_bubble_outline,
            size: 18,
            color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
          ),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeamChatPage(
                  teamId: team.id,
                  teamName: team.name,
                  teamLogoUrl: team.logoUrl,
                ),
              ),
            );
            // Recharger les chats pour mettre à jour le compteur
            if (context.mounted) {
              context.read<TeamsProvider>().loadMyTeamChats();
            }
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Chat d\'équipe',
        ),
        // Badge rouge pour les messages non lus
        if (unreadCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTeamHeader({
    required BuildContext context,
    required TeamsProvider teamsProvider,
    required Color titleColor,
    required bool isDarkMode,
  }) {
    final currentTeam = teamsProvider.currentDisplayedTeam;
    final isMyTeam = teamsProvider.isCurrentTeamMine;
    final allTeams = teamsProvider.allTeams;

    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.chevron_left,
            color: teamsProvider.canGoPrevious
                ? (isDarkMode ? myAccentVibrantBlue : MyprimaryDark)
                : Colors.grey.withOpacity(0.3),
            size: 32,
          ),
          onPressed: teamsProvider.canGoPrevious
              ? () => teamsProvider.goToPreviousTeam()
              : null,
        ),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isMyTeam
                          ? myAccentVibrantBlue.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isMyTeam ? '👑 Mon équipe' : '👤 Membre',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMyTeam ? myAccentVibrantBlue : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isMyTeam)
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        size: 16,
                        color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
                      ),
                      onPressed: () => _showEditTeamNameDialog(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  // Bouton chat d'équipe avec badge de messages non lus
                  if (currentTeam != null)
                    _buildChatButton(
                      context: context,
                      team: currentTeam,
                      unreadCount: teamsProvider.getUnreadCountForTeam(
                        currentTeam.id,
                      ),
                      isDarkMode: isDarkMode,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                currentTeam?.name ?? 'Mon Équipe',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (allTeams.length > 1)
                Text(
                  '${teamsProvider.currentTeamIndex + 1} / ${allTeams.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.chevron_right,
            color: teamsProvider.canGoNext
                ? (isDarkMode ? myAccentVibrantBlue : MyprimaryDark)
                : Colors.grey.withOpacity(0.3),
            size: 32,
          ),
          onPressed: teamsProvider.canGoNext
              ? () => teamsProvider.goToNextTeam()
              : null,
        ),
      ],
    );
  }

  Widget _buildPageIndicators(int count, int currentIndex, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 12 : 8,
          height: isActive ? 12 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? myAccentVibrantBlue
                : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyTeamPlaceholder(bool isDarkMode) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.green[800]! : Colors.green[600]!,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDarkMode ? Colors.white70 : Colors.white,
          width: 2,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups, size: 48, color: Colors.white.withOpacity(0.7)),
            const SizedBox(height: 12),
            Text(
              'Aucune équipe',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ajoutez des amis pour créer votre équipe',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamPitch(
    BuildContext context, {
    required TeamDetail team,
    required bool isMyTeam,
    required bool isDarkMode,
  }) {
    final Color pitchColor = isDarkMode
        ? Colors.green[800]!
        : Colors.green[600]!;
    final Color lineColor = isDarkMode ? Colors.white70 : Colors.white;
    final starters = team.starters;

    return Container(
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
              Positioned(
                left: minPlayerLeftPos,
                top: pitchHeight / 2 - _playerAvatarRadius - 15,
                child: _buildPlayerSlot(
                  context,
                  slotIndex: 0,
                  position: PlayerPosition.goalkeeper,
                  member: _getMemberBySlot(starters, 0),
                  isDarkMode: isDarkMode,
                  isEditable: isMyTeam,
                ),
              ),
              Positioned(
                left: minPlayerLeftPos + segmentSpacing,
                top: pitchHeight * 0.25 - _playerAvatarRadius - 15,
                child: _buildPlayerSlot(
                  context,
                  slotIndex: 1,
                  position: PlayerPosition.defender,
                  member: _getMemberBySlot(starters, 1),
                  isDarkMode: isDarkMode,
                  isEditable: isMyTeam,
                ),
              ),
              Positioned(
                left: minPlayerLeftPos + segmentSpacing,
                top: pitchHeight * 0.75 - _playerAvatarRadius - 15,
                child: _buildPlayerSlot(
                  context,
                  slotIndex: 2,
                  position: PlayerPosition.defender,
                  member: _getMemberBySlot(starters, 2),
                  isDarkMode: isDarkMode,
                  isEditable: isMyTeam,
                ),
              ),
              Positioned(
                left: minPlayerLeftPos + 2 * segmentSpacing,
                top: pitchHeight / 2 - _playerAvatarRadius - 15,
                child: _buildPlayerSlot(
                  context,
                  slotIndex: 3,
                  position: PlayerPosition.midfielder,
                  member: _getMemberBySlot(starters, 3),
                  isDarkMode: isDarkMode,
                  isEditable: isMyTeam,
                ),
              ),
              Positioned(
                left: minPlayerLeftPos + 3 * segmentSpacing,
                top: pitchHeight / 2 - _playerAvatarRadius - 15,
                child: _buildPlayerSlot(
                  context,
                  slotIndex: 4,
                  position: PlayerPosition.forward,
                  member: _getMemberBySlot(starters, 4),
                  isDarkMode: isDarkMode,
                  isEditable: isMyTeam,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubstitutesSection(
    BuildContext context, {
    required TeamsProvider teamsProvider,
    required Color titleColor,
    required bool isDarkMode,
  }) {
    final myTeam = teamsProvider.myTeam;
    final substitutes = myTeam?.substitutes ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Remplaçants',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: myAccentVibrantBlue),
              onPressed: () => _showAddPlayerDialog(
                context,
                slotIndex: 5 + substitutes.length,
                position: PlayerPosition.substitute,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (substitutes.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? MyprimaryDark.withOpacity(0.5)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            child: Center(
              child: Text(
                'Aucun remplaçant\nAppuyez sur + pour ajouter',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          )
        else
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: substitutes
                .map<Widget>(
                  (member) => _buildSubstitutePlayer(
                    member,
                    isDarkMode,
                    isEditable: true,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildOtherTeamSubstitutes(
    TeamDetail team, {
    required Color titleColor,
    required bool isDarkMode,
  }) {
    final substitutes = team.substitutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Remplaçants',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 10),
        if (substitutes.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? MyprimaryDark.withOpacity(0.5)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            child: Center(
              child: Text(
                'Aucun remplaçant',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          )
        else
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: substitutes
                .map<Widget>(
                  (member) => _buildSubstitutePlayer(
                    member,
                    isDarkMode,
                    isEditable: false,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  TeamMember? _getMemberBySlot(List<TeamMember> members, int slotIndex) {
    try {
      return members.firstWhere((m) => m.slotIndex == slotIndex);
    } catch (_) {
      return null;
    }
  }

  Widget _buildPlayerSlot(
    BuildContext context, {
    required int slotIndex,
    required PlayerPosition position,
    TeamMember? member,
    required bool isDarkMode,
    required bool isEditable,
  }) {
    final teamsProvider = context.read<TeamsProvider>();
    final isSlotOpen = isEditable && teamsProvider.isSlotOpen(slotIndex);
    final openSlot = isEditable
        ? teamsProvider.getOpenSlotForIndex(slotIndex)
        : null;

    if (member != null) {
      return GestureDetector(
        onTap: isEditable ? () => _showPlayerOptions(context, member) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(
              radius: _playerAvatarRadius,
              backgroundColor: myAccentVibrantBlue,
              backgroundImage: member.user.avatarUrl != null
                  ? NetworkImage(member.user.avatarUrl!)
                  : null,
              child: member.user.avatarUrl == null
                  ? Text(
                      member.user.username.isNotEmpty
                          ? member.user.username[0].toUpperCase()
                          : position.shortName,
                      style: const TextStyle(
                        color: MyprimaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              member.user.username.length > 8
                  ? '${member.user.username.substring(0, 8)}...'
                  : member.user.username,
              style: TextStyle(
                color: isDarkMode ? myLightBackground : MyprimaryDark,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Si le slot est en mode recherche
    if (isSlotOpen && openSlot != null) {
      return GestureDetector(
        onTap: () => _showOpenSlotOptions(context, openSlot, position),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              children: [
                CircleAvatar(
                  radius: _playerAvatarRadius,
                  backgroundColor: Colors.orange.withOpacity(0.8),
                  child: const Icon(
                    Icons.person_search,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (openSlot.applicationsCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${openSlot.applicationsCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Recherche',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Slot vide
    return GestureDetector(
      onTap: isEditable
          ? () => _showAddPlayerDialog(
              context,
              slotIndex: slotIndex,
              position: position,
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            radius: _playerAvatarRadius,
            backgroundColor: Colors.white.withOpacity(0.3),
            child: Icon(
              isEditable ? Icons.add : Icons.person_outline,
              color: Colors.white.withOpacity(0.8),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            position.shortName,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubstitutePlayer(
    TeamMember member,
    bool isDarkMode, {
    required bool isEditable,
  }) {
    return GestureDetector(
      onTap: isEditable ? () => _showPlayerOptions(context, member) : null,
      child: Container(
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
              backgroundImage: member.user.avatarUrl != null
                  ? NetworkImage(member.user.avatarUrl!)
                  : null,
              child: member.user.avatarUrl == null
                  ? Text(
                      member.user.username.isNotEmpty
                          ? member.user.username[0].toUpperCase()
                          : 'R',
                      style: const TextStyle(
                        color: MyprimaryDark,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              member.user.username,
              style: TextStyle(
                color: isDarkMode ? myLightBackground : MyprimaryDark,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            if (member.user.rating != null)
              Text(
                '⭐${member.user.rating!.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  void _showPlayerOptions(BuildContext context, TeamMember member) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final isOwner = member.user.id == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? MyprimaryDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: myAccentVibrantBlue,
              backgroundImage: member.user.avatarUrl != null
                  ? NetworkImage(member.user.avatarUrl!)
                  : null,
              child: member.user.avatarUrl == null
                  ? Text(
                      member.user.username[0].toUpperCase(),
                      style: const TextStyle(
                        color: MyprimaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  member.user.username,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? myLightBackground : MyprimaryDark,
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: myAccentVibrantBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Vous',
                      style: TextStyle(
                        fontSize: 12,
                        color: myAccentVibrantBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              member.position.displayName,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: myAccentVibrantBlue),
              title: const Text('Changer de position'),
              onTap: () {
                Navigator.pop(ctx);
                _showChangePositionDialog(context, member);
              },
            ),
            // Le propriétaire ne peut pas se retirer de l'équipe
            if (!isOwner)
              ListTile(
                leading: const Icon(Icons.remove_circle, color: Colors.red),
                title: const Text('Retirer de l\'équipe'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Retirer ce joueur ?'),
                      content: Text(
                        'Voulez-vous retirer ${member.user.username} de l\'équipe ?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          child: const Text(
                            'Retirer',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<TeamsProvider>().removeMemberFromMyTeam(
                      member.user.id,
                    );
                  }
                },
              )
            else
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'En tant que propriétaire, vous ne pouvez pas quitter l\'équipe.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddPlayerDialog(
    BuildContext context, {
    required int slotIndex,
    required PlayerPosition position,
  }) async {
    await context.read<FriendsProvider>().loadFriends();
    if (!context.mounted) return;
    final friends = context.read<FriendsProvider>().friends;
    final teamsProvider = context.read<TeamsProvider>();
    final currentUser = context.read<AuthProvider>().currentUser;
    final availableFriends = friends
        .where((f) => !teamsProvider.isUserInTeam(f.user.id))
        .toList();

    // Vérifier si le propriétaire peut s'ajouter lui-même
    final canAddSelf =
        currentUser != null && !teamsProvider.isUserInTeam(currentUser.id);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? MyprimaryDark : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (sheetCtx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Ajouter un ${position.displayName}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? myLightBackground : MyprimaryDark,
                ),
              ),
            ),
            // Option pour s'ajouter soi-même
            if (canAddSelf)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: myAccentVibrantBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: myAccentVibrantBlue.withOpacity(0.3),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: myAccentVibrantBlue,
                    backgroundImage: currentUser.avatarUrl != null
                        ? NetworkImage(currentUser.avatarUrl!)
                        : null,
                    child: currentUser.avatarUrl == null
                        ? Text(
                            currentUser.username[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  title: Text(
                    'Me placer ici',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? myLightBackground : MyprimaryDark,
                    ),
                  ),
                  subtitle: Text(
                    '@${currentUser.username}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.person_add,
                    color: myAccentVibrantBlue,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await teamsProvider.addMemberToMyTeam(
                      userId: currentUser.id,
                      position: position,
                      slotIndex: slotIndex,
                    );
                  },
                ),
              ),
            // Option pour mettre en mode recherche
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.person_search, color: Colors.white),
                ),
                title: const Text(
                  'Mettre en mode recherche',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Les joueurs de l\'app pourront postuler',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  _showOpenSlotDialog(context, slotIndex, position);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[400])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'ou choisir un ami',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[400])),
                ],
              ),
            ),
            if (availableFriends.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Tous vos amis sont déjà dans l\'équipe !',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: availableFriends.length,
                  itemBuilder: (listCtx, index) {
                    final friend = availableFriends[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: MyprimaryDark,
                        backgroundImage: friend.user.avatarUrl != null
                            ? NetworkImage(friend.user.avatarUrl!)
                            : null,
                        child: friend.user.avatarUrl == null
                            ? Text(
                                friend.user.username[0].toUpperCase(),
                                style: const TextStyle(
                                  color: myAccentVibrantBlue,
                                ),
                              )
                            : null,
                      ),
                      title: Text(friend.user.username),
                      subtitle: Text(
                        friend.user.preferredPosition ?? 'Position non définie',
                      ),
                      trailing: friend.user.rating != null
                          ? Text('⭐ ${friend.user.rating!.toStringAsFixed(1)}')
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await teamsProvider.addMemberToMyTeam(
                          userId: friend.user.id,
                          position: position,
                          slotIndex: slotIndex,
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOpenSlotDialog(
    BuildContext context,
    int slotIndex,
    PlayerPosition position,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDarkMode ? MyprimaryDark : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.person_search, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Rechercher un ${position.displayName}',
              style: TextStyle(
                color: isDarkMode ? myLightBackground : MyprimaryDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Les joueurs de l\'application pourront voir ce poste et postuler pour rejoindre votre équipe.',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (optionnel)',
                hintText: 'Ex: Recherche défenseur expérimenté...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Annuler',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await context
                  .read<TeamsProvider>()
                  .openSlotForSearch(
                    position: position,
                    slotIndex: slotIndex,
                    description: descriptionController.text.trim().isNotEmpty
                        ? descriptionController.text.trim()
                        : null,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Poste ouvert à la recherche !'
                          : 'Erreur lors de l\'ouverture du poste',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.person_search, color: Colors.white),
            label: const Text('Ouvrir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showOpenSlotOptions(
    BuildContext context,
    OpenSlot openSlot,
    PlayerPosition position,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final teamsProvider = context.read<TeamsProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? MyprimaryDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.orange,
              child: Icon(Icons.person_search, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              'Poste ${position.displayName} en recherche',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? myLightBackground : MyprimaryDark,
              ),
            ),
            if (openSlot.description != null) ...[
              const SizedBox(height: 8),
              Text(
                openSlot.description!,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${openSlot.applicationsCount} candidature(s)',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (openSlot.applicationsCount > 0)
              ListTile(
                leading: const Icon(Icons.people, color: myAccentVibrantBlue),
                title: const Text('Voir les candidatures'),
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${openSlot.applicationsCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showApplicationsDialog(context, openSlot);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.red),
              title: const Text('Fermer la recherche'),
              subtitle: const Text('Annuler la recherche pour ce poste'),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Fermer la recherche ?'),
                    content: const Text(
                      'Les candidatures en attente seront annulées.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: const Text(
                          'Fermer',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await teamsProvider.closeOpenSlot(openSlot.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showApplicationsDialog(BuildContext context, OpenSlot openSlot) async {
    final teamsProvider = context.read<TeamsProvider>();
    await teamsProvider.loadReceivedApplications();

    if (!context.mounted) return;

    final applications = teamsProvider.receivedApplications
        .where((a) => a.openSlotId == openSlot.id)
        .toList();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? MyprimaryDark : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (sheetCtx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Candidatures (${applications.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? myLightBackground : MyprimaryDark,
                ),
              ),
            ),
            if (applications.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune candidature pour le moment',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: applications.length,
                  itemBuilder: (listCtx, index) {
                    final app = applications[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: myAccentVibrantBlue,
                                  backgroundImage:
                                      app.applicant.avatarUrl != null
                                      ? NetworkImage(app.applicant.avatarUrl!)
                                      : null,
                                  child: app.applicant.avatarUrl == null
                                      ? Text(
                                          app.applicant.username[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: MyprimaryDark,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app.applicant.username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (app.applicant.rating != null)
                                        Text(
                                          '⭐ ${app.applicant.rating!.toStringAsFixed(1)}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (app.message != null &&
                                app.message!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '"${app.message}"',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: isDarkMode
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await teamsProvider.rejectApplication(
                                      app.id,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Candidature refusée'),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Refuser',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await teamsProvider.acceptApplication(
                                      app.id,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Joueur ajouté à l\'équipe !',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                  ),
                                  label: const Text('Accepter'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAllApplicationsDialog(BuildContext context) async {
    final teamsProvider = context.read<TeamsProvider>();
    await teamsProvider.loadReceivedApplications();

    if (!context.mounted) return;

    final applications = teamsProvider.receivedApplications;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? MyprimaryDark : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (sheetCtx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.inbox, color: myAccentVibrantBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Toutes les candidatures (${applications.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? myLightBackground : MyprimaryDark,
                    ),
                  ),
                ],
              ),
            ),
            if (applications.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune candidature en attente',
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: applications.length,
                  itemBuilder: (listCtx, index) {
                    final app = applications[index];
                    // Trouver le slot correspondant
                    final openSlot = teamsProvider.myOpenSlots
                        .where((s) => s.id == app.openSlotId)
                        .firstOrNull;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: myAccentVibrantBlue,
                                  backgroundImage:
                                      app.applicant.avatarUrl != null
                                      ? NetworkImage(app.applicant.avatarUrl!)
                                      : null,
                                  child: app.applicant.avatarUrl == null
                                      ? Text(
                                          app.applicant.username[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: MyprimaryDark,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app.applicant.username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (openSlot != null)
                                        Text(
                                          'Pour : ${openSlot.position.displayName}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (app.applicant.rating != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '⭐ ${app.applicant.rating!.toStringAsFixed(1)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                            if (app.message != null &&
                                app.message!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '"${app.message}"',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: isDarkMode
                                        ? Colors.grey[300]
                                        : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await teamsProvider.rejectApplication(
                                      app.id,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Candidature refusée'),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Refuser',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await teamsProvider.acceptApplication(
                                      app.id,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Joueur ajouté à l\'équipe !',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Accepter',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showChangePositionDialog(BuildContext context, TeamMember member) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? MyprimaryDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Changer la position de ${member.user.username}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? myLightBackground : MyprimaryDark,
              ),
            ),
            const SizedBox(height: 16),
            ...PlayerPosition.values.map(
              (position) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: member.position == position
                      ? myAccentVibrantBlue
                      : Colors.grey,
                  child: Text(
                    position.shortName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(position.displayName),
                trailing: member.position == position
                    ? const Icon(Icons.check, color: myAccentVibrantBlue)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  int newSlotIndex = member.slotIndex;
                  if (position == PlayerPosition.substitute &&
                      member.slotIndex < 5) {
                    newSlotIndex = 5;
                  } else if (position != PlayerPosition.substitute &&
                      member.slotIndex >= 5) {
                    switch (position) {
                      case PlayerPosition.goalkeeper:
                        newSlotIndex = 0;
                        break;
                      case PlayerPosition.defender:
                        newSlotIndex = 1;
                        break;
                      case PlayerPosition.midfielder:
                        newSlotIndex = 3;
                        break;
                      case PlayerPosition.forward:
                        newSlotIndex = 4;
                        break;
                      default:
                        break;
                    }
                  }
                  await context.read<TeamsProvider>().updateMemberPosition(
                    userId: member.user.id,
                    position: position,
                    slotIndex: newSlotIndex,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTeamNameDialog(BuildContext context) {
    final teamsProvider = context.read<TeamsProvider>();
    final controller = TextEditingController(
      text: teamsProvider.myTeam?.name ?? 'Mon Équipe',
    );
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Nom de l\'équipe'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (controller.text.trim().isNotEmpty) {
                final currentMembers = teamsProvider.myTeam?.members ?? [];
                await teamsProvider.saveMyTeamComposition(
                  name: controller.text.trim(),
                  members: currentMembers
                      .map(
                        (m) => MyTeamMemberInput(
                          userId: m.user.id,
                          position: m.position,
                          slotIndex: m.slotIndex,
                        ),
                      )
                      .toList(),
                );
              }
            },
            child: const Text('Enregistrer'),
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
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.height * 0.15,
      paint,
    );
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
