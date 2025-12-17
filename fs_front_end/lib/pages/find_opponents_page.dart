import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme_config/colors_config.dart';
import '../services/teams_service.dart';

/// Page pour trouver des adversaires et gérer les défis
class FindOpponentsPage extends StatefulWidget {
  const FindOpponentsPage({super.key});

  @override
  State<FindOpponentsPage> createState() => _FindOpponentsPageState();
}

class _FindOpponentsPageState extends State<FindOpponentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedSkillLevel;
  bool _isLoading = false;

  // Données
  List<TeamSearchResult> _opponents = [];
  List<MatchChallenge> _sentChallenges = [];
  List<MatchChallenge> _receivedChallenges = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final service = TeamsService.instance;
      final results = await Future.wait([
        service.searchOpponents(skillLevel: _selectedSkillLevel),
        service.getSentChallenges(),
        service.getReceivedChallenges(),
      ]);

      if (mounted) {
        setState(() {
          _opponents = results[0] as List<TeamSearchResult>;
          _sentChallenges = results[1] as List<MatchChallenge>;
          _receivedChallenges = results[2] as List<MatchChallenge>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trouver des adversaires'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search, size: 18),
                  const SizedBox(width: 4),
                  const Text('Recherche'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.send, size: 18),
                  const SizedBox(width: 4),
                  const Text('Envoyés'),
                  if (_sentChallenges
                      .where((c) => c.status == ChallengeStatus.pending)
                      .isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: myAccentVibrantBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_sentChallenges.where((c) => c.status == ChallengeStatus.pending).length}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inbox, size: 18),
                  const SizedBox(width: 4),
                  const Text('Reçus'),
                  if (_receivedChallenges
                      .where((c) => c.status == ChallengeStatus.pending)
                      .isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_receivedChallenges.where((c) => c.status == ChallengeStatus.pending).length}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          indicatorColor: myAccentVibrantBlue,
          labelColor: myAccentVibrantBlue,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSearchTab(isDarkMode),
                _buildSentChallengesTab(isDarkMode),
                _buildReceivedChallengesTab(isDarkMode),
              ],
            ),
    );
  }

  Widget _buildSearchTab(bool isDarkMode) {
    return Column(
      children: [
        // Filtre par niveau
        _buildSkillFilter(isDarkMode),
        // Liste des équipes
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _opponents.isEmpty
                ? _buildEmptyState(
                    icon: Icons.groups,
                    message: 'Aucune équipe en recherche d\'adversaire',
                    subtitle: 'Revenez plus tard ou modifiez vos filtres',
                    isDarkMode: isDarkMode,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _opponents.length,
                    itemBuilder: (context, index) {
                      return _buildOpponentCard(_opponents[index], isDarkMode);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillFilter(bool isDarkMode) {
    final levels = ['Tous', 'débutant', 'intermédiaire', 'confirmé', 'expert'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: levels.map((level) {
          final isSelected = level == 'Tous'
              ? _selectedSkillLevel == null
              : _selectedSkillLevel == level;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSkillLevel = level == 'Tous' ? null : level;
                });
                _loadData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? myAccentVibrantBlue
                      : (isDarkMode ? MyprimaryDark : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  level == 'Tous' ? level : _capitalizeFirst(level),
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDarkMode ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOpponentCard(TeamSearchResult team, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? MyprimaryDark : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Logo équipe
                CircleAvatar(
                  radius: 28,
                  backgroundColor: myAccentVibrantBlue.withOpacity(0.2),
                  backgroundImage: team.teamLogoUrl != null
                      ? NetworkImage(team.teamLogoUrl!)
                      : null,
                  child: team.teamLogoUrl == null
                      ? Text(
                          team.teamName[0].toUpperCase(),
                          style: const TextStyle(
                            color: myAccentVibrantBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
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
                        team.teamName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? myLightBackground : MyprimaryDark,
                        ),
                      ),
                      Text(
                        'par @${team.ownerUsername}',
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Niveau
                if (team.skillLevel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getSkillLevelColor(
                        team.skillLevel!,
                      ).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _capitalizeFirst(team.skillLevel!),
                      style: TextStyle(
                        color: _getSkillLevelColor(team.skillLevel!),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),

            // Infos
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${team.membersCount} membres',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(width: 16),
                if (team.preferredDays != null &&
                    team.preferredDays!.isNotEmpty) ...[
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      team.preferredDays!.join(', '),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            // Lieu préféré
            if (team.preferredLocations != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      team.preferredLocations!,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Description
            if (team.description != null && team.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey[800]!.withOpacity(0.5)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.format_quote, color: Colors.grey[500], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        team.description!,
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.grey[300]
                              : Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Bouton défier
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showChallengeDialog(context, team),
                icon: const Icon(Icons.sports_soccer, size: 20),
                label: const Text('Défier cette équipe'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: myAccentVibrantBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentChallengesTab(bool isDarkMode) {
    if (_sentChallenges.isEmpty) {
      return _buildEmptyState(
        icon: Icons.send,
        message: 'Aucun défi envoyé',
        subtitle: 'Recherchez des adversaires et défiez-les !',
        isDarkMode: isDarkMode,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sentChallenges.length,
        itemBuilder: (context, index) {
          return _buildChallengeCard(
            _sentChallenges[index],
            isDarkMode,
            isSent: true,
          );
        },
      ),
    );
  }

  Widget _buildReceivedChallengesTab(bool isDarkMode) {
    if (_receivedChallenges.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox,
        message: 'Aucun défi reçu',
        subtitle: 'Les équipes qui vous défient apparaîtront ici',
        isDarkMode: isDarkMode,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receivedChallenges.length,
        itemBuilder: (context, index) {
          return _buildChallengeCard(
            _receivedChallenges[index],
            isDarkMode,
            isSent: false,
          );
        },
      ),
    );
  }

  Widget _buildChallengeCard(
    MatchChallenge challenge,
    bool isDarkMode, {
    required bool isSent,
  }) {
    final opponentTeamName = isSent
        ? challenge.challengedTeamName
        : challenge.challengerTeamName;
    final opponentLogoUrl = isSent
        ? challenge.challengedTeamLogoUrl
        : challenge.challengerTeamLogoUrl;
    final opponentUsername = isSent
        ? challenge.challengedOwnerUsername
        : challenge.challengerOwnerUsername;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? MyprimaryDark : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Logo équipe adversaire
                CircleAvatar(
                  radius: 24,
                  backgroundColor: myAccentVibrantBlue.withOpacity(0.2),
                  backgroundImage: opponentLogoUrl != null
                      ? NetworkImage(opponentLogoUrl)
                      : null,
                  child: opponentLogoUrl == null
                      ? Text(
                          opponentTeamName[0].toUpperCase(),
                          style: const TextStyle(
                            color: myAccentVibrantBlue,
                            fontWeight: FontWeight.bold,
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
                        isSent ? 'Défi envoyé à' : 'Défi de',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      Text(
                        opponentTeamName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? myLightBackground : MyprimaryDark,
                        ),
                      ),
                      Text(
                        '@$opponentUsername',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(challenge.status),
              ],
            ),

            // Date et lieu proposés
            if (challenge.proposedDate != null ||
                challenge.proposedLocation != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              if (challenge.proposedDate != null)
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat(
                        'EEEE d MMMM à HH:mm',
                        'fr_FR',
                      ).format(challenge.proposedDate!),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              if (challenge.proposedLocation != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        challenge.proposedLocation!,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],

            // Message
            if (challenge.message != null && challenge.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey[800]!.withOpacity(0.5)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.message, color: Colors.grey[500], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        challenge.message!,
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.grey[300]
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Score (si match terminé)
            if (challenge.status == ChallengeStatus.completed &&
                challenge.challengerScore != null &&
                challenge.challengedScore != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: myAccentVibrantBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      challenge.challengerTeamName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${challenge.challengerScore} - ${challenge.challengedScore}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: myAccentVibrantBlue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      challenge.challengedTeamName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],

            // Actions
            if (challenge.status == ChallengeStatus.pending) ...[
              const SizedBox(height: 16),
              if (isSent)
                // Bouton annuler pour les défis envoyés
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelChallenge(challenge.id),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Annuler le défi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                )
              else
                // Boutons accepter/refuser pour les défis reçus
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _respondToChallenge(challenge.id, false),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Refuser'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _respondToChallenge(challenge.id, true),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Accepter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
            ],

            // Section score (si match accepté ou terminé)
            if (challenge.status == ChallengeStatus.accepted ||
                challenge.status == ChallengeStatus.completed) ...[
              const SizedBox(height: 16),
              _buildScoreSection(challenge, isSent, isDarkMode),
            ],

            // Date du défi
            const SizedBox(height: 8),
            Text(
              'Défi du ${DateFormat('d MMM yyyy', 'fr_FR').format(challenge.createdAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  /// Section d'affichage et de soumission du score
  Widget _buildScoreSection(
    MatchChallenge challenge,
    bool isChallenger,
    bool isDarkMode,
  ) {
    final myTeamId = isChallenger
        ? challenge.challengerTeamId
        : challenge.challengedTeamId;
    final hasSubmitted = challenge.hasSubmittedScore(myTeamId);
    final opponentSubmittedScore = challenge.getOpponentSubmittedScore(
      myTeamId,
    );

    // Si le score est validé ou en conflit, afficher le résultat final
    if (challenge.scoreValidated || challenge.scoreConflict) {
      return _buildFinalScoreDisplay(challenge, isChallenger, isDarkMode);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CAS 1: L'adversaire a soumis un score et j'attends de valider/contester
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
                // Affichage du score proposé avec noms d'équipes clairs
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
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
                              challenge.challengerTeamName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${opponentSubmittedScore['challengerScore']}',
                                style: TextStyle(
                                  fontSize: 28,
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
                      // Séparateur VS
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '-',
                          style: TextStyle(
                            fontSize: 24,
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
                              challenge.challengedTeamName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${opponentSubmittedScore['challengedScore']}',
                                style: TextStyle(
                                  fontSize: 28,
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
                const SizedBox(height: 16),
                // Boutons Valider / Contester
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _contestScore(challenge),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Contester'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _validateScore(challenge),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Valider'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '⚠️ Si vous contestez, le match sera déclaré nul (0-0)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ]
        // CAS 2: J'ai déjà soumis mon score, en attente de validation par l'adversaire
        else if (hasSubmitted) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
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
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.green[200] : Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]
        // CAS 3: Personne n'a encore soumis - je peux soumettre mon score
        else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showScoreDialog(
                context,
                challenge,
                isChallenger: isChallenger,
              ),
              icon: const Icon(Icons.scoreboard, size: 18),
              label: const Text('Enregistrer le score'),
              style: ElevatedButton.styleFrom(
                backgroundColor: myAccentVibrantBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Valide le score soumis par l'adversaire
  Future<void> _validateScore(MatchChallenge challenge) async {
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
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await TeamsService.instance.validateMatchScore(
        challenge.id,
        validate: true,
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Score validé !'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    }
  }

  /// Conteste le score - résulte en match nul
  Future<void> _contestScore(MatchChallenge challenge) async {
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
            child: const Text('Contester'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await TeamsService.instance.validateMatchScore(
        challenge.id,
        validate: false,
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Score contesté - Match nul déclaré'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadData();
      }
    }
  }

  /// Affiche le score final (validé ou match nul en cas de conflit)
  Widget _buildFinalScoreDisplay(
    MatchChallenge challenge,
    bool isChallenger,
    bool isDarkMode,
  ) {
    final isConflict = challenge.scoreConflict;
    final myTeamName = isChallenger
        ? challenge.challengerTeamName
        : challenge.challengedTeamName;
    final opponentTeamName = isChallenger
        ? challenge.challengedTeamName
        : challenge.challengerTeamName;
    final myScore = isChallenger
        ? challenge.challengerScore
        : challenge.challengedScore;
    final opponentScore = isChallenger
        ? challenge.challengedScore
        : challenge.challengerScore;

    // Déterminer le résultat
    String resultText;
    Color resultColor;
    IconData resultIcon;

    if (myScore != null && opponentScore != null) {
      if (myScore > opponentScore) {
        resultText = 'Victoire !';
        resultColor = Colors.green;
        resultIcon = Icons.emoji_events;
      } else if (myScore < opponentScore) {
        resultText = 'Défaite';
        resultColor = Colors.red;
        resultIcon = Icons.sentiment_dissatisfied;
      } else {
        resultText = 'Match nul';
        resultColor = Colors.orange;
        resultIcon = Icons.handshake;
      }
    } else {
      resultText = 'Score en attente';
      resultColor = Colors.grey;
      resultIcon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [resultColor.withOpacity(0.1), resultColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: resultColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Icône et résultat
          Icon(resultIcon, size: 32, color: resultColor),
          const SizedBox(height: 8),
          Text(
            resultText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: resultColor,
            ),
          ),

          // Score affiché avec noms d'équipes clairs
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDarkMode ? MyprimaryDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
              ],
            ),
            child: Row(
              children: [
                // Mon équipe
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        myTeamName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${myScore ?? 0}',
                          style: TextStyle(
                            fontSize: 28,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '-',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                // Équipe adverse
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        opponentTeamName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${opponentScore ?? 0}',
                          style: TextStyle(
                            fontSize: 28,
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

          // Message de conflit si applicable
          if (isConflict) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Scores contradictoires → Match nul déclaré',
                    style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ChallengeStatus status) {
    Color color;
    switch (status) {
      case ChallengeStatus.pending:
        color = Colors.orange;
        break;
      case ChallengeStatus.accepted:
        color = Colors.green;
        break;
      case ChallengeStatus.rejected:
        color = Colors.red;
        break;
      case ChallengeStatus.cancelled:
        color = Colors.grey;
        break;
      case ChallengeStatus.expired:
        color = Colors.grey;
        break;
      case ChallengeStatus.completed:
        color = myAccentVibrantBlue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? subtitle,
    required bool isDarkMode,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  void _showChallengeDialog(BuildContext context, TeamSearchResult team) {
    final messageController = TextEditingController();
    final locationController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Défier ${team.teamName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date proposée
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        selectedDate != null
                            ? DateFormat(
                                'EEEE d MMMM à HH:mm',
                                'fr_FR',
                              ).format(selectedDate!)
                            : 'Proposer une date (optionnel)',
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 90),
                          ),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 20, minute: 0),
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedDate = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),

                    // Lieu proposé
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Lieu proposé (optionnel)',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Message
                    TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message (optionnel)',
                        prefixIcon: Icon(Icons.message),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _sendChallenge(
                      team.teamId,
                      proposedDate: selectedDate,
                      proposedLocation: locationController.text.isEmpty
                          ? null
                          : locationController.text,
                      message: messageController.text.isEmpty
                          ? null
                          : messageController.text,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myAccentVibrantBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Envoyer le défi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showScoreDialog(
    BuildContext context,
    MatchChallenge challenge, {
    required bool isChallenger,
  }) {
    int myScore = 0;
    int opponentScore = 0;

    // Déterminer les noms d'équipe
    final myTeamName = isChallenger
        ? challenge.challengerTeamName
        : challenge.challengedTeamName;
    final opponentTeamName = isChallenger
        ? challenge.challengedTeamName
        : challenge.challengerTeamName;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Enregistrer le score'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Info validation mutuelle
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
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
                            'L\'adversaire devra confirmer ce score',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              myTeamName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const Text(
                              '(Vous)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: myScore > 0
                                      ? () => setDialogState(() => myScore--)
                                      : null,
                                  icon: const Icon(Icons.remove_circle),
                                ),
                                Text(
                                  '$myScore',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setDialogState(() => myScore++),
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: myAccentVibrantBlue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        '-',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              opponentTeamName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const Text(
                              '(Adversaire)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: opponentScore > 0
                                      ? () => setDialogState(
                                          () => opponentScore--,
                                        )
                                      : null,
                                  icon: const Icon(Icons.remove_circle),
                                ),
                                Text(
                                  '$opponentScore',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setDialogState(() => opponentScore++),
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: myAccentVibrantBlue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _updateScore(challenge.id, myScore, opponentScore);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myAccentVibrantBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendChallenge(
    int teamId, {
    DateTime? proposedDate,
    String? proposedLocation,
    String? message,
  }) async {
    final result = await TeamsService.instance.createChallenge(
      challengedTeamId: teamId,
      proposedDate: proposedDate,
      proposedLocation: proposedLocation,
      message: message,
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Défi envoyé ! ⚽'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
      _tabController.animateTo(1); // Aller à l'onglet "Envoyés"
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'envoi du défi'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelChallenge(int challengeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le défi'),
        content: const Text('Voulez-vous vraiment annuler ce défi ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await TeamsService.instance.cancelChallenge(challengeId);
      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Défi annulé')));
        _loadData();
      }
    }
  }

  Future<void> _respondToChallenge(int challengeId, bool accept) async {
    final result = await TeamsService.instance.respondToChallenge(
      challengeId,
      accept: accept,
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Défi accepté ! 🎉' : 'Défi refusé'),
          backgroundColor: accept ? Colors.green : Colors.grey,
        ),
      );
      _loadData();
    }
  }

  Future<void> _updateScore(
    int challengeId,
    int myScore,
    int opponentScore,
  ) async {
    final result = await TeamsService.instance.submitMatchScore(
      challengeId,
      myScore: myScore,
      opponentScore: opponentScore,
    );

    if (result != null && mounted) {
      String message;
      Color bgColor;

      if (result.scoreValidated) {
        message = '✅ Score validé ! Les deux équipes ont confirmé le résultat.';
        bgColor = Colors.green;
      } else if (result.scoreConflict) {
        message =
            '⚠️ Conflit de score ! Le score soumis ne correspond pas à celui de l\'adversaire.';
        bgColor = Colors.orange;
      } else {
        message =
            '⏳ Score enregistré. En attente de confirmation de l\'adversaire.';
        bgColor = Colors.blue;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: bgColor),
      );
      _loadData();
    }
  }

  Color _getSkillLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'débutant':
        return Colors.green;
      case 'intermédiaire':
        return Colors.orange;
      case 'confirmé':
        return Colors.red;
      case 'expert':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
