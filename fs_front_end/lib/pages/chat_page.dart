import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_config/colors_config.dart';
import '../providers/messages_provider.dart';
import '../providers/auth_provider.dart';
import '../services/messages_service.dart';

class ChatPage extends StatefulWidget {
  final int friendId;
  final String friendName;
  final String? friendAvatarUrl;

  const ChatPage({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendAvatarUrl,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    // Charger la conversation et initialiser WebSocket
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MessagesProvider>();
      provider.initWebSocket();
      provider.startConversation(
        widget.friendId,
        widget.friendName,
        widget.friendAvatarUrl,
      );
    });

    // Écouter le scroll pour charger plus de messages
    _scrollController.addListener(_onScroll);

    // Écouter les changements de texte pour l'indicateur de frappe
    _messageController.addListener(_onTextChanged);
  }

  void _onScroll() {
    if (_scrollController.position.atEdge) {
      if (_scrollController.position.pixels == 0) {
        // En haut de la liste - charger plus de messages
        context.read<MessagesProvider>().loadMoreMessages();
      }
    }
  }

  void _onTextChanged() {
    // Envoyer l'indicateur de frappe (throttled)
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 500), () {
      if (_messageController.text.isNotEmpty) {
        context.read<MessagesProvider>().sendTyping();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    context.read<MessagesProvider>().sendMessage(content);

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

    final Color receiverBubbleColor = isDarkMode
        ? MyprimaryDark
        : Colors.grey[200]!;

    final currentUserId = context.read<AuthProvider>().currentUser?.id;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await context.read<MessagesProvider>().closeConversation();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: MyprimaryDark,
                backgroundImage: widget.friendAvatarUrl != null
                    ? NetworkImage(widget.friendAvatarUrl!)
                    : null,
                child: widget.friendAvatarUrl == null
                    ? Text(
                        widget.friendName.isNotEmpty
                            ? widget.friendName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: myAccentVibrantBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Text(
                widget.friendName,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          iconTheme: Theme.of(context).appBarTheme.iconTheme,
        ),
        body: Column(
          children: <Widget>[
            // ===== LISTE DES MESSAGES =====
            Expanded(
              child: Consumer<MessagesProvider>(
                builder: (context, provider, _) {
                  if (provider.messagesState == MessagesLoadingState.loading &&
                      provider.activeConversation == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = provider.activeConversation?.messages ?? [];

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
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
                            'Envoyez le premier message !',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.grey[500]
                                  : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isSender = message.senderId == currentUserId;

                      // Afficher la date si c'est un nouveau jour
                      final showDate =
                          index == 0 ||
                          !_isSameDay(
                            messages[index - 1].createdAt,
                            message.createdAt,
                          );

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
                            senderBubbleColor,
                            receiverBubbleColor,
                            textColor,
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
                child: Consumer<MessagesProvider>(
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
                            enabled: !provider.isSending,
                          ),
                        ),
                        const SizedBox(width: 10),
                        FloatingActionButton(
                          onPressed: provider.isSending ? null : _sendMessage,
                          backgroundColor: provider.isSending
                              ? Colors.grey
                              : myAccentVibrantBlue,
                          elevation: 0,
                          child: provider.isSending
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
      ),
    );
  }

  Widget _buildMessageBubble(
    MessageModel message,
    bool isSender,
    Color senderBubbleColor,
    Color receiverBubbleColor,
    Color textColor,
  ) {
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isSender ? senderBubbleColor : receiverBubbleColor,
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
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isSender ? MyprimaryDark : textColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: (isSender ? MyprimaryDark : textColor).withValues(
                      alpha: 0.6,
                    ),
                    fontSize: 10,
                  ),
                ),
                if (isSender) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead
                        ? Colors.blue
                        : MyprimaryDark.withValues(alpha: 0.6),
                  ),
                ],
              ],
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
