import 'package:flutter/foundation.dart';
import '../services/messages_service.dart';

/// État du provider pour les messages
enum MessagesLoadingState { idle, loading, loaded, error }

/// Provider pour gérer l'état des messages avec WebSocket
class MessagesProvider with ChangeNotifier {
  final MessagesService _messagesService = MessagesService.instance;

  // État global
  MessagesLoadingState _conversationsState = MessagesLoadingState.idle;
  String? _errorMessage;
  int _unreadCount = 0;
  bool _isWebSocketConnected = false;

  // Liste des conversations
  List<ConversationPreview> _conversations = [];

  // Conversation active
  int? _activeUserId;
  ConversationOut? _activeConversation;
  MessagesLoadingState _messagesState = MessagesLoadingState.idle;
  bool _isSending = false;

  // Indicateur de frappe
  int? _typingUserId;

  // Getters
  MessagesLoadingState get conversationsState => _conversationsState;
  MessagesLoadingState get messagesState => _messagesState;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unreadCount;
  List<ConversationPreview> get conversations => _conversations;
  ConversationOut? get activeConversation => _activeConversation;
  int? get activeUserId => _activeUserId;
  bool get isSending => _isSending;
  bool get isWebSocketConnected => _isWebSocketConnected;
  int? get typingUserId => _typingUserId;

  /// Initialise les callbacks WebSocket et se connecte
  void initWebSocket() {
    _messagesService.onNewMessage = _handleNewMessage;
    _messagesService.onMessageSent = _handleMessageSent;
    _messagesService.onMessagesRead = _handleMessagesRead;
    _messagesService.onTyping = _handleTyping;
    _messagesService.onConnected = () {
      _isWebSocketConnected = true;
      notifyListeners();
    };
    _messagesService.onDisconnected = () {
      _isWebSocketConnected = false;
      notifyListeners();
    };

    _messagesService.connect();
  }

  /// Gère un nouveau message reçu
  void _handleNewMessage(MessageModel message) {
    debugPrint('📩 New message received from ${message.senderId}');

    // Si on est dans la conversation avec cet utilisateur, ajouter le message
    if (_activeUserId == message.senderId && _activeConversation != null) {
      _activeConversation = ConversationOut(
        user: _activeConversation!.user,
        messages: [..._activeConversation!.messages, message],
        hasMore: _activeConversation!.hasMore,
      );

      // Marquer comme lu automatiquement puisqu'on est dans la conversation
      _messagesService.markAsReadRealtime(message.senderId);
    } else {
      // Sinon, incrémenter le compteur de non lus
      _unreadCount++;

      // Mettre à jour l'aperçu de la conversation
      _updateConversationPreviewFromMessage(message);
    }

    // Réinitialiser l'indicateur de frappe
    if (_typingUserId == message.senderId) {
      _typingUserId = null;
    }

    notifyListeners();
  }

  /// Gère la confirmation d'envoi de message
  void _handleMessageSent(MessageModel message) {
    debugPrint('✅ Message sent confirmed: ${message.id}');

    // Ajouter le message à la conversation active
    if (_activeConversation != null) {
      // Vérifier si le message n'est pas déjà dans la liste (éviter les doublons)
      final exists = _activeConversation!.messages.any(
        (m) => m.id == message.id,
      );
      if (!exists) {
        _activeConversation = ConversationOut(
          user: _activeConversation!.user,
          messages: [..._activeConversation!.messages, message],
          hasMore: _activeConversation!.hasMore,
        );
      }

      // Mettre à jour l'aperçu
      _updateConversationPreview(message);
    }

    _isSending = false;
    notifyListeners();
  }

  /// Gère la notification que des messages ont été lus
  void _handleMessagesRead(int readerId, List<int> messageIds) {
    debugPrint('👁️ Messages read by $readerId: $messageIds');

    // Mettre à jour le statut des messages dans la conversation active
    if (_activeConversation != null) {
      final updatedMessages = _activeConversation!.messages.map((m) {
        if (messageIds.contains(m.id)) {
          return MessageModel(
            id: m.id,
            senderId: m.senderId,
            receiverId: m.receiverId,
            content: m.content,
            isRead: true,
            createdAt: m.createdAt,
            readAt: DateTime.now(),
          );
        }
        return m;
      }).toList();

      _activeConversation = ConversationOut(
        user: _activeConversation!.user,
        messages: updatedMessages,
        hasMore: _activeConversation!.hasMore,
      );

      notifyListeners();
    }
  }

  /// Gère l'indicateur de frappe
  void _handleTyping(int userId) {
    if (_activeUserId == userId) {
      _typingUserId = userId;
      notifyListeners();

      // Effacer après 3 secondes
      Future.delayed(const Duration(seconds: 3), () {
        if (_typingUserId == userId) {
          _typingUserId = null;
          notifyListeners();
        }
      });
    }
  }

  /// Met à jour l'aperçu d'une conversation avec un nouveau message reçu
  void _updateConversationPreviewFromMessage(MessageModel message) {
    final senderId = message.senderId;
    final index = _conversations.indexWhere((c) => c.user.id == senderId);

    if (index != -1) {
      final oldConversation = _conversations[index];
      _conversations[index] = ConversationPreview(
        user: oldConversation.user,
        lastMessage: message,
        unreadCount: oldConversation.unreadCount + 1,
      );

      // Déplacer en haut
      final updated = _conversations.removeAt(index);
      _conversations.insert(0, updated);
    } else {
      // Nouvelle conversation - recharger depuis le serveur pour avoir les infos utilisateur
      loadConversations();
    }
  }

  /// Charge la liste des conversations
  Future<void> loadConversations() async {
    _conversationsState = MessagesLoadingState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _conversations = await _messagesService.getConversations();
      _conversationsState = MessagesLoadingState.loaded;

      // Mettre à jour le compteur de non lus
      _unreadCount = _conversations.fold(0, (sum, c) => sum + c.unreadCount);
    } catch (e) {
      _conversationsState = MessagesLoadingState.error;
      _errorMessage = 'Erreur: $e';
    }

    notifyListeners();
  }

  /// Charge le compteur de messages non lus
  Future<void> loadUnreadCount() async {
    try {
      _unreadCount = await _messagesService.getUnreadCount();
      notifyListeners();
    } catch (_) {
      // Ignorer les erreurs silencieusement
    }
  }

  /// Retourne le nombre de messages non lus pour un utilisateur spécifique
  int getUnreadCountForUser(int userId) {
    final conversation = _conversations.firstWhere(
      (c) => c.user.id == userId,
      orElse: () => ConversationPreview(
        user: UserBasicInfo(id: userId, username: ''),
        lastMessage: MessageModel(
          id: 0,
          senderId: 0,
          receiverId: 0,
          content: '',
          isRead: true,
          createdAt: DateTime.now(),
        ),
        unreadCount: 0,
      ),
    );
    return conversation.unreadCount;
  }

  /// Ouvre une conversation avec un utilisateur
  Future<void> openConversation(int userId) async {
    _activeUserId = userId;
    _messagesState = MessagesLoadingState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _activeConversation = await _messagesService.getConversation(userId);
      _messagesState = MessagesLoadingState.loaded;

      // Marquer les messages comme lus
      if (_activeConversation != null) {
        _messagesService.markAsReadRealtime(userId);

        // Mettre à jour le compteur local
        final conversationIndex = _conversations.indexWhere(
          (c) => c.user.id == userId,
        );
        if (conversationIndex != -1) {
          final oldUnread = _conversations[conversationIndex].unreadCount;
          _unreadCount = (_unreadCount - oldUnread).clamp(0, _unreadCount);

          // Réinitialiser le compteur de cette conversation
          _conversations[conversationIndex] = ConversationPreview(
            user: _conversations[conversationIndex].user,
            lastMessage: _conversations[conversationIndex].lastMessage,
            unreadCount: 0,
          );
        }
      }
    } catch (e) {
      _messagesState = MessagesLoadingState.error;
      _errorMessage = 'Erreur: $e';
    }

    notifyListeners();
  }

  /// Charge plus de messages (pagination)
  Future<void> loadMoreMessages() async {
    if (_activeUserId == null || _activeConversation == null) return;
    if (!_activeConversation!.hasMore) return;

    final oldestMessageId = _activeConversation!.messages.isNotEmpty
        ? _activeConversation!.messages.first.id
        : null;

    try {
      final olderConversation = await _messagesService.getConversation(
        _activeUserId!,
        beforeId: oldestMessageId,
      );

      if (olderConversation != null) {
        // Fusionner les anciens messages avec les nouveaux
        final allMessages = [
          ...olderConversation.messages,
          ..._activeConversation!.messages,
        ];

        _activeConversation = ConversationOut(
          user: _activeConversation!.user,
          messages: allMessages,
          hasMore: olderConversation.hasMore,
        );
        notifyListeners();
      }
    } catch (_) {
      // Ignorer les erreurs de pagination
    }
  }

  /// Envoie un message via WebSocket (temps réel)
  void sendMessage(String content) {
    if (_activeUserId == null) return;
    if (content.trim().isEmpty) return;

    _isSending = true;
    notifyListeners();

    // Utiliser WebSocket pour l'envoi en temps réel
    if (_isWebSocketConnected) {
      _messagesService.sendMessageRealtime(_activeUserId!, content);
    } else {
      // Fallback sur REST si WebSocket non connecté
      _sendMessageRest(content);
    }
  }

  /// Fallback: envoie via REST
  Future<void> _sendMessageRest(String content) async {
    try {
      final message = await _messagesService.sendMessage(
        _activeUserId!,
        content,
      );

      if (message != null && _activeConversation != null) {
        _activeConversation = ConversationOut(
          user: _activeConversation!.user,
          messages: [..._activeConversation!.messages, message],
          hasMore: _activeConversation!.hasMore,
        );
        _updateConversationPreview(message);
      }

      _isSending = false;
      notifyListeners();
    } catch (e) {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Notifie que l'utilisateur est en train de taper
  void sendTyping() {
    if (_activeUserId != null && _isWebSocketConnected) {
      _messagesService.sendTyping(_activeUserId!);
    }
  }

  /// Met à jour l'aperçu de conversation après envoi d'un message
  void _updateConversationPreview(MessageModel message) {
    final index = _conversations.indexWhere((c) => c.user.id == _activeUserId);

    if (index != -1) {
      // Mettre à jour la conversation existante
      final oldConversation = _conversations[index];
      _conversations[index] = ConversationPreview(
        user: oldConversation.user,
        lastMessage: message,
        unreadCount: 0, // Pas de non lus puisqu'on est dans la conversation
      );

      // Déplacer en haut de la liste
      final updated = _conversations.removeAt(index);
      _conversations.insert(0, updated);
    }
  }

  /// Ferme la conversation active et recharge les compteurs
  Future<void> closeConversation() async {
    _activeUserId = null;
    _activeConversation = null;
    _messagesState = MessagesLoadingState.idle;
    _typingUserId = null;
    notifyListeners();

    // Recharger les conversations pour avoir les bons compteurs
    await loadConversations();
  }

  /// Démarre une nouvelle conversation (depuis la liste d'amis)
  Future<void> startConversation(
    int userId,
    String username,
    String? avatarUrl,
  ) async {
    _activeUserId = userId;
    _typingUserId = null;

    // Créer une conversation vide si elle n'existe pas
    _activeConversation = ConversationOut(
      user: UserBasicInfo(id: userId, username: username, avatarUrl: avatarUrl),
      messages: [],
      hasMore: false,
    );

    _messagesState = MessagesLoadingState.loaded;
    notifyListeners();

    // Charger les messages existants en arrière-plan
    try {
      final conversation = await _messagesService.getConversation(userId);
      if (conversation != null) {
        _activeConversation = conversation;

        // Marquer comme lus
        _messagesService.markAsReadRealtime(userId);

        notifyListeners();
      }
    } catch (_) {
      // Garder la conversation vide
    }
  }

  /// Réinitialise l'état (pour la déconnexion)
  void reset() {
    _messagesService.disconnect();
    _conversationsState = MessagesLoadingState.idle;
    _messagesState = MessagesLoadingState.idle;
    _errorMessage = null;
    _unreadCount = 0;
    _conversations = [];
    _activeUserId = null;
    _activeConversation = null;
    _isSending = false;
    _isWebSocketConnected = false;
    _typingUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _messagesService.disconnect();
    super.dispose();
  }
}
