import 'package:flutter/material.dart';
import '../theme_config/colors_config.dart';
import '../services/teams_service.dart';

/// Page de chat entre deux équipes pour un match confirmé
class MatchChatPage extends StatefulWidget {
  final int challengeId;
  final String myTeamName;
  final String opponentTeamName;
  final String? opponentTeamLogoUrl;
  final int myTeamId;

  const MatchChatPage({
    super.key,
    required this.challengeId,
    required this.myTeamName,
    required this.opponentTeamName,
    this.opponentTeamLogoUrl,
    required this.myTeamId,
  });

  @override
  State<MatchChatPage> createState() => _MatchChatPageState();
}

class _MatchChatPageState extends State<MatchChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TeamsService _teamsService = TeamsService.instance;

  List<MatchChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupWebSocket();
  }

  Future<void> _loadData() async {
    // Charger les messages
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    final messages = await _teamsService.getMatchMessages(widget.challengeId);

    setState(() {
      _messages = messages;
      _isLoading = false;
    });

    // Marquer comme lus
    await _teamsService.markMatchMessagesAsRead(widget.challengeId);

    // Scroll vers le bas
    _scrollToBottom();
  }

  void _setupWebSocket() {
    // Configurer le callback pour les nouveaux messages
    _teamsService.onNewMatchMessage = (message) {
      if (message.challengeId == widget.challengeId) {
        setState(() {
          // Éviter les doublons
          if (!_messages.any((m) => m.id == message.id)) {
            _messages.add(message);
          }
        });
        _scrollToBottom();
        // Marquer comme lu
        _teamsService.markMatchMessagesAsRead(widget.challengeId);
      }
    };

    _teamsService.onMatchChatConnected = () {
      debugPrint('Match chat connecté');
    };

    _teamsService.onMatchChatDisconnected = () {
      debugPrint('Match chat déconnecté');
    };

    // Se connecter au WebSocket
    _teamsService.connectToMatchChat(widget.challengeId);
  }

  @override
  void dispose() {
    _teamsService.onNewMatchMessage = null;
    _teamsService.onMatchChatConnected = null;
    _teamsService.onMatchChatDisconnected = null;
    _teamsService.disconnectFromMatchChat();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    setState(() => _isSending = true);

    // Utiliser WebSocket si connecté
    if (_teamsService.isMatchChatConnected) {
      _teamsService.sendMatchMessageWs(content);
      setState(() => _isSending = false);
    } else {
      // Fallback sur REST
      final message = await _teamsService.sendMatchMessage(
        widget.challengeId,
        content,
      );
      if (message != null) {
        setState(() {
          if (!_messages.any((m) => m.id == message.id)) {
            _messages.add(message);
          }
        });
        _scrollToBottom();
      }
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? myLightBackground : MyprimaryDark;

    final Color myTeamBubbleColor = isDarkMode
        ? myAccentVibrantBlue.withValues(alpha: 0.85)
        : myAccentVibrantBlue;

    final Color opponentBubbleColor = isDarkMode
        ? MyprimaryDark
        : Colors.grey[200]!;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: myAccentVibrantBlue,
              backgroundImage: widget.opponentTeamLogoUrl != null
                  ? NetworkImage(widget.opponentTeamLogoUrl!)
                  : null,
              child: widget.opponentTeamLogoUrl == null
                  ? Icon(Icons.groups, color: MyprimaryDark, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.opponentTeamName,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Chat du match',
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
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
                          'Commencez à discuter avec votre adversaire !',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[500]
                                : Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMyTeam = message.senderTeamId == widget.myTeamId;

                      // Afficher la date si c'est un nouveau jour
                      final showDate =
                          index == 0 ||
                          !_isSameDay(
                            _messages[index - 1].createdAt,
                            message.createdAt,
                          );

                      // Afficher le nom de l'expéditeur si ce n'est pas mon équipe
                      // et si le message précédent n'est pas du même utilisateur
                      final showSenderName =
                          !isMyTeam &&
                          (index == 0 ||
                              _messages[index - 1].senderUserId !=
                                  message.senderUserId);

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
                            isMyTeam,
                            showSenderName,
                            myTeamBubbleColor,
                            opponentBubbleColor,
                            textColor,
                            isDarkMode,
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // ===== BARRE DE SAISIE =====
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
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
                      enabled: !_isSending,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    onPressed: _isSending ? null : _sendMessage,
                    backgroundColor: _isSending
                        ? Colors.grey
                        : myAccentVibrantBlue,
                    elevation: 0,
                    child: _isSending
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    MatchChatMessage message,
    bool isMyTeam,
    bool showSenderName,
    Color myTeamBubbleColor,
    Color opponentBubbleColor,
    Color textColor,
    bool isDarkMode,
  ) {
    return Align(
      alignment: isMyTeam ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar pour l'adversaire
            if (!isMyTeam) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey[400],
                backgroundImage: message.senderAvatarUrl != null
                    ? NetworkImage(message.senderAvatarUrl!)
                    : null,
                child: message.senderAvatarUrl == null
                    ? Text(
                        message.senderUsername.isNotEmpty
                            ? message.senderUsername[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
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
                  color: isMyTeam ? myTeamBubbleColor : opponentBubbleColor,
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomLeft: isMyTeam
                        ? const Radius.circular(20)
                        : const Radius.circular(6),
                    bottomRight: isMyTeam
                        ? const Radius.circular(6)
                        : const Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: isMyTeam
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Nom de l'expéditeur + nom d'équipe
                    if (showSenderName)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${message.senderUsername} (${message.senderTeamName})',
                          style: TextStyle(
                            color: isDarkMode
                                ? myAccentVibrantBlue
                                : Colors.grey[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    // Contenu du message
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMyTeam ? MyprimaryDark : textColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Heure
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        color: (isMyTeam ? MyprimaryDark : textColor)
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
