import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_config/colors_config.dart';
import '../providers/friends_provider.dart';
import '../providers/messages_provider.dart';
import '../services/friends_service.dart';
import 'chat_page.dart';
import 'user_profile_page.dart';

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({super.key});

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Charger les amis et les conversations au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendsProvider>().loadFriends();
      context.read<MessagesProvider>().loadConversations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDarkMode ? myLightBackground : MyprimaryDark;

    return Scaffold(
      appBar: AppBar(
        title: null,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Consumer<FriendsProvider>(
                builder: (context, provider, _) {
                  return Text('Amis (${provider.friendsCount})');
                },
              ),
            ),
            Tab(
              child: Consumer<FriendsProvider>(
                builder: (context, provider, _) {
                  final count = provider.totalPendingCount;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Demandes'),
                      if (count > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: myAccentVibrantBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const Tab(text: 'Rechercher'),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 8,
            ),
            child: Text(
              'Mes Amis',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(isDarkMode),
                _buildRequestsTab(isDarkMode),
                _buildSearchTab(isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Onglet des amis
  Widget _buildFriendsTab(bool isDarkMode) {
    return Consumer<FriendsProvider>(
      builder: (context, provider, _) {
        if (provider.state == FriendsLoadingState.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.state == FriendsLoadingState.error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(provider.errorMessage ?? 'Une erreur est survenue'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.loadFriends(),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        if (provider.friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun ami pour le moment',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recherchez des joueurs pour les ajouter !',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadFriends(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 90),
            itemCount: provider.friends.length,
            itemBuilder: (context, index) {
              final friend = provider.friends[index];
              return _buildFriendCard(friend, isDarkMode);
            },
          ),
        );
      },
    );
  }

  /// Carte d'un ami
  Widget _buildFriendCard(FriendWithInfo friend, bool isDarkMode) {
    final Color cardTitleColor = isDarkMode ? myLightBackground : MyprimaryDark;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: MyprimaryDark,
          backgroundImage: friend.user.avatarUrl != null
              ? NetworkImage(friend.user.avatarUrl!)
              : null,
          child: friend.user.avatarUrl == null
              ? Text(
                  friend.user.username.isNotEmpty
                      ? friend.user.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: myAccentVibrantBlue,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          friend.user.username,
          style: TextStyle(fontWeight: FontWeight.bold, color: cardTitleColor),
        ),
        subtitle: Text(
          friend.user.preferredPosition ?? 'Position non définie',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (friend.user.rating != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: myAccentVibrantBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '⭐ ${friend.user.rating!.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(width: 8),
            Consumer<MessagesProvider>(
              builder: (context, messagesProvider, _) {
                final unreadCount = messagesProvider.getUnreadCountForUser(
                  friend.user.id,
                );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.chat_bubble_outline,
                        color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) => ChatPage(
                              friendId: friend.user.id,
                              friendName: friend.user.username,
                              friendAvatarUrl: friend.user.avatarUrl,
                            ),
                          ),
                        );
                        // Note: les conversations sont rechargées dans closeConversation()
                      },
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
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
                );
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfilePage(
                        userBasicInfo: friend.user,
                        showAddFriendButton: false,
                      ),
                    ),
                  );
                } else if (value == 'remove') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Supprimer cet ami ?'),
                      content: Text(
                        'Voulez-vous vraiment supprimer ${friend.user.username} de votre liste d\'amis ?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Supprimer',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    await context.read<FriendsProvider>().removeFriend(
                      friend.friendshipId,
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: myAccentVibrantBlue),
                      SizedBox(width: 8),
                      Text('Voir le profil'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Supprimer'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Onglet des demandes
  Widget _buildRequestsTab(bool isDarkMode) {
    return Consumer<FriendsProvider>(
      builder: (context, provider, _) {
        if (provider.pendingReceived.isEmpty && provider.pendingSent.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 80,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune demande en attente',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 90),
          children: [
            if (provider.pendingReceived.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Demandes reçues',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? myLightBackground : MyprimaryDark,
                  ),
                ),
              ),
              ...provider.pendingReceived.map(
                (request) => _buildPendingReceivedCard(request, isDarkMode),
              ),
            ],
            if (provider.pendingSent.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Demandes envoyées',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? myLightBackground : MyprimaryDark,
                  ),
                ),
              ),
              ...provider.pendingSent.map(
                (request) => _buildPendingSentCard(request, isDarkMode),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Carte de demande reçue
  Widget _buildPendingReceivedCard(PendingRequest request, bool isDarkMode) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        onTap: () {
          // Naviguer vers le profil de l'utilisateur
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfilePage(
                userBasicInfo: request.fromUser,
                showAddFriendButton: false,
              ),
            ),
          );
        },
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: MyprimaryDark,
          backgroundImage: request.fromUser.avatarUrl != null
              ? NetworkImage(request.fromUser.avatarUrl!)
              : null,
          child: request.fromUser.avatarUrl == null
              ? Text(
                  request.fromUser.username.isNotEmpty
                      ? request.fromUser.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: myAccentVibrantBlue,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          request.fromUser.username,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? myLightBackground : MyprimaryDark,
          ),
        ),
        subtitle: Text(
          'Veut devenir votre ami',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () async {
                await context.read<FriendsProvider>().acceptFriendRequest(
                  request.friendshipId,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () async {
                await context.read<FriendsProvider>().rejectFriendRequest(
                  request.friendshipId,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Carte de demande envoyée
  Widget _buildPendingSentCard(FriendWithInfo request, bool isDarkMode) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        onTap: () {
          // Naviguer vers le profil de l'utilisateur
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfilePage(
                userBasicInfo: request.user,
                showAddFriendButton: false,
              ),
            ),
          );
        },
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: MyprimaryDark,
          backgroundImage: request.user.avatarUrl != null
              ? NetworkImage(request.user.avatarUrl!)
              : null,
          child: request.user.avatarUrl == null
              ? Text(
                  request.user.username.isNotEmpty
                      ? request.user.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: myAccentVibrantBlue,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          request.user.username,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? myLightBackground : MyprimaryDark,
          ),
        ),
        subtitle: Text(
          'En attente de réponse',
          style: TextStyle(color: Colors.orange[400]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          tooltip: 'Annuler la demande',
          onPressed: () async {
            await context.read<FriendsProvider>().removeFriend(
              request.friendshipId,
            );
          },
        ),
      ),
    );
  }

  /// Onglet de recherche
  Widget _buildSearchTab(bool isDarkMode) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher un joueur...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        context.read<FriendsProvider>().clearSearch();
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              context.read<FriendsProvider>().searchUsers(value);
            },
          ),
        ),
        Expanded(
          child: Consumer<FriendsProvider>(
            builder: (context, provider, _) {
              if (provider.isSearching) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_searchController.text.length < 2) {
                return Center(
                  child: Text(
                    'Entrez au moins 2 caractères',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                );
              }

              if (provider.searchResults.isEmpty) {
                return Center(
                  child: Text(
                    'Aucun résultat trouvé',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 90),
                itemCount: provider.searchResults.length,
                itemBuilder: (context, index) {
                  final result = provider.searchResults[index];
                  return _buildSearchResultCard(result, isDarkMode);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Carte de résultat de recherche
  Widget _buildSearchResultCard(SearchUserResult result, bool isDarkMode) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        onTap: () {
          // Naviguer vers le profil de l'utilisateur
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfilePage(
                userBasicInfo: result.user,
                showAddFriendButton: result.friendshipStatus != 'accepted',
              ),
            ),
          );
        },
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: MyprimaryDark,
          backgroundImage: result.user.avatarUrl != null
              ? NetworkImage(result.user.avatarUrl!)
              : null,
          child: result.user.avatarUrl == null
              ? Text(
                  result.user.username.isNotEmpty
                      ? result.user.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: myAccentVibrantBlue,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          result.user.username,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? myLightBackground : MyprimaryDark,
          ),
        ),
        subtitle: Text(
          result.user.preferredPosition ?? 'Position non définie',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        trailing: _buildSearchActionButton(result),
      ),
    );
  }

  /// Bouton d'action selon le statut de la relation
  Widget _buildSearchActionButton(SearchUserResult result) {
    final status = result.friendshipStatus;

    if (status == 'accepted') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Ami',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (status == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'En attente',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
      );
    }

    return ElevatedButton.icon(
      icon: const Icon(Icons.person_add, size: 18),
      label: const Text('Ajouter'),
      style: ElevatedButton.styleFrom(
        backgroundColor: myAccentVibrantBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () async {
        final provider = context.read<FriendsProvider>();
        final result2 = await provider.sendFriendRequest(result.user.id);
        if (!result2['ok'] && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result2['message'] ?? 'Erreur')),
          );
        }
      },
    );
  }
}
