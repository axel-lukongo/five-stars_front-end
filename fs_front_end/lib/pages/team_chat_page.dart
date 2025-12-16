import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_config/colors_config.dart';
import '../providers/teams_provider.dart';
import '../providers/auth_provider.dart';
import '../services/teams_service.dart';

class TeamChatPage extends StatefulWidget {
  final int teamId;
  final String teamName;
  final String? teamLogoUrl;

  const TeamChatPage({
    super.key,
    required this.teamId,
    required this.teamName,
    this.teamLogoUrl,
  });

  @override
  State<TeamChatPage> createState() => _TeamChatPageState();
}

class _TeamChatPageState extends State<TeamChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Charger les messages et se connecter au WebSocket
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TeamsProvider>();
      provider.loadTeamMessages(widget.teamId);
      // Se connecter au WebSocket pour le temps réel
      provider.connectToTeamChat(widget.teamId);
      // Marquer les messages comme lus à l'ouverture
      provider.markMessagesAsRead(widget.teamId);
    });

    // Écouter le scroll pour charger plus de messages
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.atEdge) {
      if (_scrollController.position.pixels == 0) {
        // En haut de la liste - charger les messages plus anciens
        final provider = context.read<TeamsProvider>();
        final messages = provider.getMessagesForTeam(widget.teamId);
        if (messages.isNotEmpty) {
          // Le premier message est le plus ancien (ordre chronologique)
          provider.loadTeamMessages(widget.teamId, beforeId: messages.first.id);
        }
      }
    }
  }

  @override
  void dispose() {
    // Déconnecter du WebSocket quand on quitte la page
    context.read<TeamsProvider>().disconnectFromTeamChat();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();

    // Utiliser WebSocket si connecté, sinon HTTP
    final provider = context.read<TeamsProvider>();
    if (provider.isTeamChatConnected) {
      provider.sendMessageRealtime(content);
    } else {
      provider.sendMessage(widget.teamId, content);
    }

    // Scroll vers le bas pour voir le nouveau message
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? myLightBackground : MyprimaryDark;

    final Color senderBubbleColor = isDarkMode
        ? myAccentVibrantBlue.withValues(alpha: 0.85)
        : myAccentVibrantBlue;

    final Color otherBubbleColor = isDarkMode
        ? MyprimaryDark
        : Colors.grey[200]!;

    final currentUserId = context.read<AuthProvider>().currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: myAccentVibrantBlue,
              backgroundImage: widget.teamLogoUrl != null
                  ? NetworkImage(widget.teamLogoUrl!)
                  : null,
              child: widget.teamLogoUrl == null
                  ? Icon(Icons.groups, color: MyprimaryDark, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.teamName,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Chat d\'équipe',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
      ),
      body: Column(
        children: <Widget>[
          // ===== LISTE DES MESSAGES =====
          Expanded(
            child: Consumer<TeamsProvider>(
              builder: (context, provider, _) {
                if (provider.isLoadingMessages &&
                    provider.getMessagesForTeam(widget.teamId).isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = provider.getMessagesForTeam(widget.teamId);

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 80,
                          color: isDarkMode
                              ? Colors.grey[600]
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun message',
                          style: TextStyle(
                            fontSize: 18,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Démarrez la conversation avec votre équipe !',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[500]
                                : Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Les messages sont en ordre chronologique (plus ancien -> plus récent)
                // Pas besoin d'inverser
                final displayMessages = messages;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: displayMessages.length,
                  itemBuilder: (context, index) {
                    final message = displayMessages[index];
                    final isSender = message.sender.id == currentUserId;

                    // Afficher la date si c'est un nouveau jour
                    final showDate =
                        index == 0 ||
                        !_isSameDay(
                          displayMessages[index - 1].createdAt,
                          message.createdAt,
                        );

                    // Afficher le nom de l'expéditeur si ce n'est pas nous
                    // et si le message précédent n'est pas du même expéditeur
                    final showSenderName =
                        !isSender &&
                        (index == 0 ||
                            displayMessages[index - 1].sender.id !=
                                message.sender.id);

                    return Column(
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              _formatDate(message.createdAt),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        _buildMessageBubble(
                          message,
                          isSender,
                          showSenderName,
                          senderBubbleColor,
                          otherBubbleColor,
                          textColor,
                          isDarkMode,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ===== BARRE DE SAISIE =====
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Consumer<TeamsProvider>(
                builder: (context, provider, _) {
                  return Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Écrire un message...',
                            hintStyle: TextStyle(
                              color: isDarkMode
                                  ? Colors.grey[500]
                                  : Colors.grey[700],
                            ),
                            filled: true,
                            fillColor: isDarkMode
                                ? MyprimaryDark.withValues(alpha: 0.7)
                                : Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: TextStyle(color: textColor),
                          onSubmitted: (_) => _sendMessage(),
                          enabled: !provider.isSendingMessage,
                        ),
                      ),
                      const SizedBox(width: 10),
                      FloatingActionButton(
                        onPressed: provider.isSendingMessage
                            ? null
                            : _sendMessage,
                        backgroundColor: provider.isSendingMessage
                            ? Colors.grey
                            : myAccentVibrantBlue,
                        elevation: 0,
                        child: provider.isSendingMessage
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, color: MyprimaryDark),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    TeamChatMessage message,
    bool isSender,
    bool showSenderName,
    Color senderBubbleColor,
    Color otherBubbleColor,
    Color textColor,
    bool isDarkMode,
  ) {
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar pour les autres
            if (!isSender) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: myAccentVibrantBlue,
                backgroundImage: message.sender.avatarUrl != null
                    ? NetworkImage(message.sender.avatarUrl!)
                    : null,
                child: message.sender.avatarUrl == null
                    ? Text(
                        message.sender.username.isNotEmpty
                            ? message.sender.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: MyprimaryDark,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            // Bulle de message
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxWidth: 280),
                decoration: BoxDecoration(
                  color: isSender ? senderBubbleColor : otherBubbleColor,
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomLeft: isSender
                        ? const Radius.circular(20)
                        : const Radius.circular(6),
                    bottomRight: isSender
                        ? const Radius.circular(6)
                        : const Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: isSender
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Nom de l'expéditeur
                    if (showSenderName)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.sender.username,
                          style: TextStyle(
                            color: myAccentVibrantBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    // Contenu du message
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isSender ? MyprimaryDark : textColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Heure
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        color: (isSender ? MyprimaryDark : textColor)
                            .withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return "Aujourd'hui";
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Hier';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
