import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_config/colors_config.dart';
import '../providers/teams_provider.dart';
import '../services/teams_service.dart';

/// Page pour découvrir les équipes en recherche de joueurs
class DiscoverTeamsPage extends StatefulWidget {
  const DiscoverTeamsPage({super.key});

  @override
  State<DiscoverTeamsPage> createState() => _DiscoverTeamsPageState();
}

class _DiscoverTeamsPageState extends State<DiscoverTeamsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PlayerPosition? _selectedPositionFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    final teamsProvider = context.read<TeamsProvider>();
    await Future.wait([
      teamsProvider.loadAllOpenSlots(position: _selectedPositionFilter),
      teamsProvider.loadMyApplications(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trouver une équipe'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Équipes en recherche'),
            Tab(text: 'Mes candidatures'),
          ],
          indicatorColor: myAccentVibrantBlue,
          labelColor: myAccentVibrantBlue,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOpenSlotsTab(isDarkMode),
          _buildMyApplicationsTab(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildOpenSlotsTab(bool isDarkMode) {
    return Consumer<TeamsProvider>(
      builder: (context, teamsProvider, _) {
        return Column(
          children: [
            // Filtre par position
            _buildPositionFilter(isDarkMode),
            // Liste des postes
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => teamsProvider.loadAllOpenSlots(
                  position: _selectedPositionFilter,
                ),
                child: teamsProvider.allOpenSlots.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.sports_soccer,
                        message: 'Aucune équipe en recherche pour le moment',
                        isDarkMode: isDarkMode,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: teamsProvider.allOpenSlots.length,
                        itemBuilder: (context, index) {
                          final slot = teamsProvider.allOpenSlots[index];
                          return _buildOpenSlotCard(slot, isDarkMode);
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPositionFilter(bool isDarkMode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Tous',
            isSelected: _selectedPositionFilter == null,
            onTap: () => _applyFilter(null),
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 8),
          ...PlayerPosition.values
              .where((p) => p != PlayerPosition.substitute)
              .map(
                (position) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(
                    label: position.displayName,
                    isSelected: _selectedPositionFilter == position,
                    onTap: () => _applyFilter(position),
                    isDarkMode: isDarkMode,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? myAccentVibrantBlue
              : (isDarkMode ? MyprimaryDark : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? myAccentVibrantBlue : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDarkMode ? Colors.white70 : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _applyFilter(PlayerPosition? position) {
    setState(() {
      _selectedPositionFilter = position;
    });
    context.read<TeamsProvider>().loadAllOpenSlots(position: position);
  }

  Widget _buildOpenSlotCard(OpenSlot slot, bool isDarkMode) {
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
                // Logo équipe ou placeholder
                CircleAvatar(
                  radius: 28,
                  backgroundColor: myAccentVibrantBlue.withOpacity(0.2),
                  backgroundImage: slot.teamLogoUrl != null
                      ? NetworkImage(slot.teamLogoUrl!)
                      : null,
                  child: slot.teamLogoUrl == null
                      ? Text(
                          slot.teamName[0].toUpperCase(),
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
                        slot.teamName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? myLightBackground : MyprimaryDark,
                        ),
                      ),
                      Text(
                        'par @${slot.ownerUsername}',
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getPositionColor(slot.position).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    slot.position.displayName,
                    style: TextStyle(
                      color: _getPositionColor(slot.position),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (slot.description != null && slot.description!.isNotEmpty) ...[
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
                        slot.description!,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(slot.createdAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showApplyDialog(context, slot),
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Postuler'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: myAccentVibrantBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPositionColor(PlayerPosition position) {
    switch (position) {
      case PlayerPosition.goalkeeper:
        return Colors.orange;
      case PlayerPosition.defender:
        return Colors.blue;
      case PlayerPosition.midfielder:
        return Colors.green;
      case PlayerPosition.forward:
        return Colors.red;
      case PlayerPosition.substitute:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return 'il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
    } else if (diff.inHours > 0) {
      return 'il y a ${diff.inHours} heure${diff.inHours > 1 ? 's' : ''}';
    } else if (diff.inMinutes > 0) {
      return 'il y a ${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'à l\'instant';
    }
  }

  void _showApplyDialog(BuildContext context, OpenSlot slot) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDarkMode ? MyprimaryDark : Colors.white,
        title: Text(
          'Postuler chez ${slot.teamName}',
          style: TextStyle(
            color: isDarkMode ? myLightBackground : MyprimaryDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sports_soccer,
                  color: _getPositionColor(slot.position),
                ),
                const SizedBox(width: 8),
                Text(
                  'Poste : ${slot.position.displayName}',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Message (optionnel)',
                hintText: 'Présentez-vous en quelques mots...',
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
              final success = await context.read<TeamsProvider>().applyToSlot(
                slot.id,
                message: messageController.text.trim().isNotEmpty
                    ? messageController.text.trim()
                    : null,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Candidature envoyée !'
                          : 'Vous avez déjà postulé ou une erreur est survenue',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.send, color: Colors.white),
            label: const Text('Envoyer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: myAccentVibrantBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyApplicationsTab(bool isDarkMode) {
    return Consumer<TeamsProvider>(
      builder: (context, teamsProvider, _) {
        final applications = teamsProvider.myApplications;

        return RefreshIndicator(
          onRefresh: () => teamsProvider.loadMyApplications(),
          child: applications.isEmpty
              ? _buildEmptyState(
                  icon: Icons.inbox_outlined,
                  message: 'Vous n\'avez pas encore postulé',
                  isDarkMode: isDarkMode,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: applications.length,
                  itemBuilder: (context, index) {
                    final app = applications[index];
                    return _buildApplicationCard(app, isDarkMode);
                  },
                ),
        );
      },
    );
  }

  Widget _buildApplicationCard(SlotApplicationDetail app, bool isDarkMode) {
    final slot = app.openSlot;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (app.status) {
      case ApplicationStatus.pending:
        statusColor = Colors.orange;
        statusText = 'En attente';
        statusIcon = Icons.hourglass_empty;
        break;
      case ApplicationStatus.accepted:
        statusColor = Colors.green;
        statusText = 'Acceptée';
        statusIcon = Icons.check_circle;
        break;
      case ApplicationStatus.rejected:
        statusColor = Colors.red;
        statusText = 'Refusée';
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDarkMode ? MyprimaryDark : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: myAccentVibrantBlue.withOpacity(0.2),
                  child: Text(
                    slot.teamName[0].toUpperCase(),
                    style: const TextStyle(
                      color: myAccentVibrantBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.teamName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? myLightBackground : MyprimaryDark,
                        ),
                      ),
                      Text(
                        'Poste : ${slot.position.displayName}',
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (app.message != null && app.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Votre message : "${app.message}"',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Envoyée ${_formatDate(app.appliedAt)}',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required bool isDarkMode,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Rafraîchir'),
          ),
        ],
      ),
    );
  }
}
