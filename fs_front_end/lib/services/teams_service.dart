import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_config.dart';
import 'auth_service.dart';

/// Callback pour les événements WebSocket du chat d'équipe
typedef TeamMessageCallback = void Function(TeamChatMessage message);
typedef TeamMessagesReadCallback = void Function(int teamId);

/// Service pour gérer les équipes
class TeamsService {
  TeamsService._privateConstructor();
  static final TeamsService instance = TeamsService._privateConstructor();

  // Le service teams tourne sur le port 8003
  String get baseUrl => ApiConfig.teamsUrl;
  // URL WebSocket
  String get wsUrl {
    final httpUrl = baseUrl;
    if (httpUrl.startsWith('https://')) {
      return httpUrl.replaceFirst('https://', 'wss://');
    }
    return httpUrl.replaceFirst('http://', 'ws://');
  }

  // WebSocket pour le chat d'équipe
  WebSocketChannel? _teamChatChannel;
  StreamSubscription? _teamChatSubscription;
  bool _isTeamChatConnected = false;
  int? _connectedTeamId;
  Timer? _pingTimer;

  // Callbacks
  TeamMessageCallback? onNewTeamMessage;
  TeamMessagesReadCallback? onTeamMessagesRead;
  VoidCallback? onTeamChatConnected;
  VoidCallback? onTeamChatDisconnected;

  bool get isTeamChatConnected => _isTeamChatConnected;
  int? get connectedTeamId => _connectedTeamId;

  Future<Map<String, String>> get _headers async {
    final token = await AuthService.instance.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // Équipes
  // ============================================================

  /// Liste les équipes de l'utilisateur
  Future<List<TeamPreview>> getTeams() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teams'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => TeamPreview.fromJson(e)).toList();
      }
      throw Exception('Erreur ${response.statusCode}');
    } catch (e) {
      debugPrint('Erreur getTeams: $e');
      rethrow;
    }
  }

  /// Récupère les détails d'une équipe
  Future<TeamDetail?> getTeam(int teamId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$teamId'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        return TeamDetail.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur getTeam: $e');
      return null;
    }
  }

  /// Crée une nouvelle équipe
  Future<TeamPreview?> createTeam({
    required String name,
    String? description,
    String? logoUrl,
    bool isDefault = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teams'),
        headers: await _headers,
        body: jsonEncode({
          'name': name,
          'description': description,
          'logo_url': logoUrl,
          'is_default': isDefault,
        }),
      );

      if (response.statusCode == 201) {
        return TeamPreview.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur createTeam: $e');
      return null;
    }
  }

  /// Modifie une équipe
  Future<TeamPreview?> updateTeam(
    int teamId, {
    String? name,
    String? description,
    String? logoUrl,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$teamId'),
        headers: await _headers,
        body: jsonEncode({
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (logoUrl != null) 'logo_url': logoUrl,
        }),
      );

      if (response.statusCode == 200) {
        return TeamPreview.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur updateTeam: $e');
      return null;
    }
  }

  /// Supprime une équipe
  Future<bool> deleteTeam(int teamId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$teamId'),
        headers: await _headers,
      );

      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Erreur deleteTeam: $e');
      return false;
    }
  }

  // ============================================================
  // Membres
  // ============================================================

  /// Ajoute un membre à une équipe
  Future<TeamMember?> addMember(
    int teamId, {
    required int userId,
    required PlayerPosition position,
    required int slotIndex,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$teamId/members'),
        headers: await _headers,
        body: jsonEncode({
          'user_id': userId,
          'position': position.value,
          'slot_index': slotIndex,
        }),
      );

      if (response.statusCode == 201) {
        return TeamMember.fromJson(jsonDecode(response.body));
      }
      // Log response for debugging when add fails
      debugPrint(
        'addMember failed: status=${response.statusCode} body=${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('Erreur addMember: $e');
      return null;
    }
  }

  /// Modifie la position d'un membre
  Future<TeamMember?> updateMemberPosition(
    int teamId,
    int memberUserId, {
    required PlayerPosition position,
    required int slotIndex,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$teamId/members/$memberUserId/position'),
        headers: await _headers,
        body: jsonEncode({'position': position.value, 'slot_index': slotIndex}),
      );

      if (response.statusCode == 200) {
        return TeamMember.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur updateMemberPosition: $e');
      return null;
    }
  }

  /// Retire un membre de l'équipe
  Future<bool> removeMember(int teamId, int memberUserId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$teamId/members/$memberUserId'),
        headers: await _headers,
      );

      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Erreur removeMember: $e');
      return false;
    }
  }

  /// Permet à l'utilisateur actuel de quitter une équipe
  Future<bool> leaveTeam(int teamId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$teamId/leave'),
        headers: await _headers,
      );

      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Erreur leaveTeam: $e');
      return false;
    }
  }

  // ============================================================
  // Mon Équipe (équipe par défaut)
  // ============================================================

  /// Récupère l'équipe par défaut de l'utilisateur
  Future<TeamDetail?> getMyTeam() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my-team'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        return TeamDetail.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur getMyTeam: $e');
      return null;
    }
  }

  /// Met à jour l'équipe par défaut
  Future<TeamDetail?> updateMyTeam({
    String? name,
    required List<MyTeamMemberInput> members,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/my-team'),
        headers: await _headers,
        body: jsonEncode({
          if (name != null) 'name': name,
          'members': members.map((m) => m.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        return TeamDetail.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur updateMyTeam: $e');
      return null;
    }
  }

  /// Récupère les équipes où l'utilisateur est membre (mais pas propriétaire)
  Future<List<TeamDetail>> getTeamsMemberOf() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teams-member-of'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => TeamDetail.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getTeamsMemberOf: $e');
      return [];
    }
  }

  // ============================================================
  // Postes Ouverts (Recherche de joueurs)
  // ============================================================

  /// Crée un poste ouvert pour rechercher un joueur
  Future<OpenSlot?> createOpenSlot(
    int teamId, {
    required PlayerPosition position,
    required int slotIndex,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$teamId/slots/open'),
        headers: await _headers,
        body: jsonEncode({
          'position': position.value,
          'slot_index': slotIndex,
          if (description != null) 'description': description,
        }),
      );

      if (response.statusCode == 201) {
        return OpenSlot.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur createOpenSlot: $e');
      return null;
    }
  }

  /// Récupère les postes ouverts d'une équipe
  Future<List<OpenSlot>> getTeamOpenSlots(int teamId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$teamId/open-slots'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => OpenSlot.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getTeamOpenSlots: $e');
      return [];
    }
  }

  /// Ferme un poste ouvert
  Future<bool> closeOpenSlot(int slotId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/open-slots/$slotId'),
        headers: await _headers,
      );

      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Erreur closeOpenSlot: $e');
      return false;
    }
  }

  /// Liste tous les postes ouverts (pour chercher une équipe)
  Future<List<OpenSlot>> getAllOpenSlots({PlayerPosition? position}) async {
    try {
      var url = '$baseUrl/open-slots';
      if (position != null) {
        url += '?position=${position.value}';
      }

      final response = await http.get(Uri.parse(url), headers: await _headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => OpenSlot.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getAllOpenSlots: $e');
      return [];
    }
  }

  // ============================================================
  // Candidatures
  // ============================================================

  /// Postuler à un poste ouvert
  Future<SlotApplication?> applyToSlot(int slotId, {String? message}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/open-slots/$slotId/apply'),
        headers: await _headers,
        body: jsonEncode({if (message != null) 'message': message}),
      );

      if (response.statusCode == 201) {
        return SlotApplication.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur applyToSlot: $e');
      return null;
    }
  }

  /// Récupère mes candidatures
  Future<List<SlotApplicationDetail>> getMyApplications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my-applications'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => SlotApplicationDetail.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getMyApplications: $e');
      return [];
    }
  }

  /// Récupère les candidatures reçues pour une équipe
  Future<List<SlotApplication>> getTeamApplications(int teamId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$teamId/applications'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => SlotApplication.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getTeamApplications: $e');
      return [];
    }
  }

  /// Accepter ou refuser une candidature
  Future<SlotApplication?> respondToApplication(
    int applicationId, {
    required bool accept,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/applications/$applicationId'),
        headers: await _headers,
        body: jsonEncode({'action': accept ? 'accept' : 'reject'}),
      );

      if (response.statusCode == 200) {
        return SlotApplication.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur respondToApplication: $e');
      return null;
    }
  }

  // ============================================================
  // Chat d'équipe
  // ============================================================

  /// Récupère les messages du chat d'équipe
  Future<List<TeamChatMessage>> getTeamMessages(
    int teamId, {
    int limit = 50,
    int? beforeId,
  }) async {
    try {
      var url = '$baseUrl/$teamId/messages?limit=$limit';
      if (beforeId != null) {
        url += '&before_id=$beforeId';
      }

      final response = await http.get(Uri.parse(url), headers: await _headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => TeamChatMessage.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getTeamMessages: $e');
      return [];
    }
  }

  /// Envoie un message dans le chat d'équipe
  Future<TeamChatMessage?> sendTeamMessage(int teamId, String content) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$teamId/messages'),
        headers: await _headers,
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 201) {
        return TeamChatMessage.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur sendTeamMessage: $e');
      return null;
    }
  }

  /// Récupère la liste des chats d'équipe
  Future<List<TeamChatInfo>> getMyTeamChats() async {
    try {
      final headers = await _headers;
      debugPrint(
        'Token utilisé pour my-team-chats: \\u001b[33m${headers['Authorization']}\\u001b[0m',
      );
      final response = await http.get(
        Uri.parse('$baseUrl/my-team-chats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => TeamChatInfo.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getMyTeamChats: $e');
      return [];
    }
  }

  /// Marque tous les messages d'une équipe comme lus
  Future<bool> markMessagesAsRead(int teamId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$teamId/messages/read'),
        headers: await _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erreur markMessagesAsRead: $e');
      return false;
    }
  }

  // ============================================================
  // WebSocket - Chat d'équipe temps réel
  // ============================================================

  /// Connecte au WebSocket du chat d'équipe
  Future<void> connectToTeamChat(int teamId) async {
    // Déconnecter si déjà connecté à une autre équipe
    if (_isTeamChatConnected && _connectedTeamId != teamId) {
      disconnectFromTeamChat();
    }

    if (_isTeamChatConnected && _connectedTeamId == teamId) {
      return; // Déjà connecté à cette équipe
    }

    final token = await AuthService.instance.getAccessToken();
    if (token == null) {
      debugPrint('❌ Cannot connect WebSocket: no token');
      return;
    }

    try {
      final uri = Uri.parse('$wsUrl/ws/team-chat/$teamId/$token');
      debugPrint('🔌 Connecting to team chat WebSocket: $uri');

      _teamChatChannel = WebSocketChannel.connect(uri);
      _connectedTeamId = teamId;

      _teamChatSubscription = _teamChatChannel!.stream.listen(
        _onTeamChatMessage,
        onError: _onTeamChatError,
        onDone: _onTeamChatDone,
      );

      _isTeamChatConnected = true;
      onTeamChatConnected?.call();
      debugPrint('✅ Team chat WebSocket connected');

      // Démarrer le ping
      _startTeamChatPing();
    } catch (e) {
      debugPrint('❌ Team chat WebSocket connection error: $e');
    }
  }

  /// Déconnecte du WebSocket du chat d'équipe
  void disconnectFromTeamChat() {
    _pingTimer?.cancel();
    _teamChatSubscription?.cancel();
    _teamChatChannel?.sink.close();
    _teamChatChannel = null;
    _isTeamChatConnected = false;
    _connectedTeamId = null;
    onTeamChatDisconnected?.call();
    debugPrint('🔌 Team chat WebSocket disconnected');
  }

  void _onTeamChatMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String);
      final type = json['type'] as String?;

      switch (type) {
        case 'new_message':
          final message = TeamChatMessage.fromJson(json['message']);
          onNewTeamMessage?.call(message);
          break;
        case 'messages_read':
          final teamId = json['team_id'] as int;
          onTeamMessagesRead?.call(teamId);
          break;
        case 'pong':
          // Réponse au ping, connexion OK
          break;
        case 'error':
          debugPrint('Team chat WebSocket error: ${json['message']}');
          break;
      }
    } catch (e) {
      debugPrint('Error parsing team chat WebSocket message: $e');
    }
  }

  void _onTeamChatError(dynamic error) {
    debugPrint('❌ Team chat WebSocket error: $error');
    _isTeamChatConnected = false;
    onTeamChatDisconnected?.call();
  }

  void _onTeamChatDone() {
    debugPrint('🔌 Team chat WebSocket closed');
    _isTeamChatConnected = false;
    onTeamChatDisconnected?.call();
  }

  void _startTeamChatPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isTeamChatConnected) {
        _sendTeamChatAction({'action': 'ping'});
      }
    });
  }

  void _sendTeamChatAction(Map<String, dynamic> data) {
    if (_teamChatChannel != null && _isTeamChatConnected) {
      _teamChatChannel!.sink.add(jsonEncode(data));
    }
  }

  /// Envoie un message via WebSocket (temps réel)
  void sendTeamMessageRealtime(String content) {
    _sendTeamChatAction({'action': 'send_message', 'content': content});
  }

  /// Marque les messages comme lus via WebSocket
  void markTeamMessagesAsReadRealtime() {
    _sendTeamChatAction({'action': 'mark_read'});
  }

  // ============================================================
  // Recherche d'adversaires
  // ============================================================

  /// Met à jour les préférences de recherche d'adversaire
  Future<TeamSearchPreference?> updateSearchPreferences(
    int teamId, {
    required bool isLookingForOpponent,
    List<String>? preferredDays,
    List<String>? preferredTimeSlots,
    String? preferredLocations,
    String? skillLevel,
    String? description,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$teamId/search-preferences'),
        headers: await _headers,
        body: jsonEncode({
          'is_looking_for_opponent': isLookingForOpponent,
          'preferred_days': preferredDays,
          'preferred_time_slots': preferredTimeSlots,
          'preferred_locations': preferredLocations,
          'skill_level': skillLevel,
          'description': description,
        }),
      );

      if (response.statusCode == 200) {
        return TeamSearchPreference.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur updateSearchPreferences: $e');
      return null;
    }
  }

  /// Récupère les préférences de recherche d'une équipe
  Future<TeamSearchPreference?> getSearchPreferences(int teamId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$teamId/search-preferences'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        return TeamSearchPreference.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur getSearchPreferences: $e');
      return null;
    }
  }

  /// Recherche les équipes en recherche d'adversaire
  Future<List<TeamSearchResult>> searchOpponents({String? skillLevel}) async {
    try {
      var url = '$baseUrl/opponents/search';
      if (skillLevel != null) {
        url += '?skill_level=$skillLevel';
      }

      final response = await http.get(Uri.parse(url), headers: await _headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => TeamSearchResult.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur searchOpponents: $e');
      return [];
    }
  }

  // ============================================================
  // Défis de matchs
  // ============================================================

  /// Crée un défi envers une autre équipe
  Future<MatchChallenge?> createChallenge({
    required int challengedTeamId,
    DateTime? proposedDate,
    String? proposedLocation,
    String? message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges'),
        headers: await _headers,
        body: jsonEncode({
          'challenged_team_id': challengedTeamId,
          'proposed_date': proposedDate?.toIso8601String(),
          'proposed_location': proposedLocation,
          'message': message,
        }),
      );

      if (response.statusCode == 201) {
        return MatchChallenge.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur createChallenge: $e');
      return null;
    }
  }

  /// Récupère les défis envoyés
  Future<List<MatchChallenge>> getSentChallenges() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/challenges/sent'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => MatchChallenge.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getSentChallenges: $e');
      return [];
    }
  }

  /// Récupère les défis reçus
  Future<List<MatchChallenge>> getReceivedChallenges() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/challenges/received'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => MatchChallenge.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getReceivedChallenges: $e');
      return [];
    }
  }

  /// Répond à un défi (accepter ou refuser)
  Future<MatchChallenge?> respondToChallenge(
    int challengeId, {
    required bool accept,
    String? responseMessage,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges/$challengeId/respond'),
        headers: await _headers,
        body: jsonEncode({
          'action': accept ? 'accept' : 'reject',
          'response_message': responseMessage,
        }),
      );

      if (response.statusCode == 200) {
        return MatchChallenge.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur respondToChallenge: $e');
      return null;
    }
  }

  /// Soumet le score d'un match (validation mutuelle)
  /// myScore = score de mon équipe
  /// opponentScore = score de l'équipe adverse
  Future<MatchChallenge?> submitMatchScore(
    int challengeId, {
    required int myScore,
    required int opponentScore,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges/$challengeId/score'),
        headers: await _headers,
        body: jsonEncode({
          'my_score': myScore,
          'opponent_score': opponentScore,
        }),
      );

      if (response.statusCode == 200) {
        return MatchChallenge.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur submitMatchScore: $e');
      return null;
    }
  }

  /// Valide ou conteste le score soumis par l'adversaire
  /// validate = true pour valider, false pour contester (match nul)
  Future<MatchChallenge?> validateMatchScore(
    int challengeId, {
    required bool validate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges/$challengeId/validate'),
        headers: await _headers,
        body: jsonEncode({'validate': validate}),
      );

      if (response.statusCode == 200) {
        return MatchChallenge.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur validateMatchScore: $e');
      return null;
    }
  }

  /// Récupère les matchs d'une équipe
  /// status = "accepted" pour les matchs à venir, "completed" pour les terminés, null pour tous
  Future<List<MatchChallenge>> getTeamMatches(
    int teamId, {
    String? status,
  }) async {
    try {
      var url = '$baseUrl/$teamId/matches';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(Uri.parse(url), headers: await _headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => MatchChallenge.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getTeamMatches: $e');
      return [];
    }
  }

  /// Récupère les joueurs en commun entre deux équipes
  Future<List<String>> getCommonPlayers(int teamId, int opponentTeamId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$opponentTeamId/public-members'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        // Récupérer aussi les joueurs de notre équipe
        final myTeamResponse = await http.get(
          Uri.parse('$baseUrl/$teamId'),
          headers: await _headers,
        );

        if (myTeamResponse.statusCode == 200) {
          final myTeamData = jsonDecode(myTeamResponse.body);
          final myTeamMembers = (myTeamData['members'] as List<dynamic>)
              .map((m) => (m['user']['username'] as String).toLowerCase())
              .toSet();

          // Récupérer les joueurs adverses et trouver les doublons
          final opponentMembers = (data as List<dynamic>)
              .map((m) => (m['user']['username'] as String).toLowerCase())
              .toSet();

          final commonPlayers = myTeamMembers
              .intersection(opponentMembers)
              .toList();
          commonPlayers.sort();

          return commonPlayers;
        }
      }
      // Si l'endpoint n'existe pas (404) ou pas d'accès (403), retourner liste vide
      return [];
    } catch (e) {
      debugPrint('Erreur getCommonPlayers: $e');
      return [];
    }
  }

  /// Annule un défi (même accepté)
  Future<bool> cancelChallenge(int challengeId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/challenges/$challengeId/cancel'),
        headers: await _headers,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Erreur cancelChallenge: $e');
      return false;
    }
  }

  // ============================================================
  // Match Chat - Messagerie de match
  // ============================================================

  // WebSocket pour le chat de match
  WebSocketChannel? _matchChatChannel;
  StreamSubscription? _matchChatSubscription;
  bool _isMatchChatConnected = false;
  int? _connectedChallengeId;
  Timer? _matchChatPingTimer;

  // Callbacks pour le chat de match
  void Function(MatchChatMessage message)? onNewMatchMessage;
  VoidCallback? onMatchChatConnected;
  VoidCallback? onMatchChatDisconnected;

  bool get isMatchChatConnected => _isMatchChatConnected;
  int? get connectedChallengeId => _connectedChallengeId;

  /// Connecte au WebSocket du chat de match
  Future<bool> connectToMatchChat(int challengeId) async {
    // Déjà connecté à ce chat
    if (_isMatchChatConnected && _connectedChallengeId == challengeId) {
      return true;
    }

    // Déconnecter de l'ancien chat si nécessaire
    await disconnectFromMatchChat();

    try {
      final token = await AuthService.instance.getAccessToken();
      if (token == null) {
        debugPrint('Pas de token pour le match chat');
        return false;
      }

      final wsUri = Uri.parse('$wsUrl/ws/match-chat/$challengeId/$token');
      debugPrint('Connexion au match chat: $wsUri');

      _matchChatChannel = WebSocketChannel.connect(wsUri);
      _connectedChallengeId = challengeId;

      _matchChatSubscription = _matchChatChannel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String);
            final message = MatchChatMessage.fromJson(json);
            onNewMatchMessage?.call(message);
          } catch (e) {
            debugPrint('Erreur parsing match message: $e');
          }
        },
        onDone: () {
          debugPrint('Match chat WebSocket fermé');
          _handleMatchChatDisconnect();
        },
        onError: (error) {
          debugPrint('Erreur Match chat WebSocket: $error');
          _handleMatchChatDisconnect();
        },
      );

      _isMatchChatConnected = true;
      onMatchChatConnected?.call();

      // Ping pour garder la connexion active
      _matchChatPingTimer?.cancel();
      _matchChatPingTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _sendMatchChatPing(),
      );

      return true;
    } catch (e) {
      debugPrint('Erreur connexion match chat: $e');
      _handleMatchChatDisconnect();
      return false;
    }
  }

  void _sendMatchChatPing() {
    if (_isMatchChatConnected && _matchChatChannel != null) {
      try {
        _matchChatChannel!.sink.add(jsonEncode({'type': 'ping'}));
      } catch (e) {
        debugPrint('Erreur ping match chat: $e');
      }
    }
  }

  void _handleMatchChatDisconnect() {
    _isMatchChatConnected = false;
    _connectedChallengeId = null;
    _matchChatPingTimer?.cancel();
    _matchChatSubscription?.cancel();
    onMatchChatDisconnected?.call();
  }

  /// Déconnecte du WebSocket du chat de match
  Future<void> disconnectFromMatchChat() async {
    _matchChatPingTimer?.cancel();
    _matchChatSubscription?.cancel();

    if (_matchChatChannel != null) {
      try {
        await _matchChatChannel!.sink.close();
      } catch (e) {
        debugPrint('Erreur fermeture match chat: $e');
      }
    }

    _matchChatChannel = null;
    _isMatchChatConnected = false;
    _connectedChallengeId = null;
  }

  /// Envoie un message via WebSocket
  void sendMatchMessageWs(String content) {
    if (_isMatchChatConnected && _matchChatChannel != null) {
      _matchChatChannel!.sink.add(jsonEncode({'content': content}));
    }
  }

  /// Récupère les messages d'un match (REST)
  Future<List<MatchChatMessage>> getMatchMessages(int challengeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/challenges/$challengeId/messages'),
        headers: await _headers,
      );

      debugPrint('getMatchMessages status: ${response.statusCode}');
      debugPrint('getMatchMessages body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => MatchChatMessage.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getMatchMessages: $e');
      return [];
    }
  }

  /// Envoie un message (REST, alternative au WebSocket)
  Future<MatchChatMessage?> sendMatchMessage(
    int challengeId,
    String content,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges/$challengeId/messages'),
        headers: await _headers,
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 200) {
        return MatchChatMessage.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('Erreur sendMatchMessage: $e');
      return null;
    }
  }

  /// Marque les messages comme lus
  Future<void> markMatchMessagesAsRead(int challengeId) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/challenges/$challengeId/messages/read'),
        headers: await _headers,
      );
    } catch (e) {
      debugPrint('Erreur markMatchMessagesAsRead: $e');
    }
  }

  /// Récupère le nombre de messages non lus pour un match
  Future<int> getUnreadMessagesCount(int challengeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/challenges/$challengeId/messages/unread-count'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unread_count'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Erreur getUnreadMessagesCount: $e');
      return 0;
    }
  }

  /// Récupère les messages non lus pour tous les matchs
  Future<Map<int, int>> getAllUnreadCounts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my-matches/unread-counts'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final matchesUnread = data['matches_unread'] as Map<String, dynamic>;
        return matchesUnread.map(
          (key, value) => MapEntry(int.parse(key), value as int),
        );
      }
      return {};
    } catch (e) {
      debugPrint('Erreur getAllUnreadCounts: $e');
      return {};
    }
  }
}

// ============================================================
// Modèles
// ============================================================

/// Position d'un joueur sur le terrain
enum PlayerPosition {
  goalkeeper('goalkeeper'),
  defender('defender'),
  midfielder('midfielder'),
  forward('forward'),
  substitute('substitute');

  final String value;
  const PlayerPosition(this.value);

  static PlayerPosition fromString(String value) {
    return PlayerPosition.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PlayerPosition.substitute,
    );
  }

  String get displayName {
    switch (this) {
      case PlayerPosition.goalkeeper:
        return 'Gardien';
      case PlayerPosition.defender:
        return 'Défenseur';
      case PlayerPosition.midfielder:
        return 'Milieu';
      case PlayerPosition.forward:
        return 'Attaquant';
      case PlayerPosition.substitute:
        return 'Remplaçant';
    }
  }

  String get shortName {
    switch (this) {
      case PlayerPosition.goalkeeper:
        return 'G';
      case PlayerPosition.defender:
        return 'D';
      case PlayerPosition.midfielder:
        return 'D';
      case PlayerPosition.forward:
        return 'A';
      case PlayerPosition.substitute:
        return 'A';
    }
  }
}

/// Infos basiques d'un utilisateur
class TeamUserInfo {
  final int id;
  final String username;
  final String? avatarUrl;
  final String? preferredPosition;
  final double? rating;

  TeamUserInfo({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.preferredPosition,
    this.rating,
  });

  factory TeamUserInfo.fromJson(Map<String, dynamic> json) {
    return TeamUserInfo(
      id: json['id'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      preferredPosition: json['preferred_position'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}

/// Membre d'une équipe
class TeamMember {
  final int id;
  final TeamUserInfo user;
  final PlayerPosition position;
  final int slotIndex;
  final bool isCaptain;
  final DateTime joinedAt;

  TeamMember({
    required this.id,
    required this.user,
    required this.position,
    required this.slotIndex,
    required this.isCaptain,
    required this.joinedAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'] as int,
      user: TeamUserInfo.fromJson(json['user']),
      position: PlayerPosition.fromString(json['position'] as String),
      slotIndex: json['slot_index'] as int,
      isCaptain: json['is_captain'] as bool,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}

/// Aperçu d'une équipe (liste)
class TeamPreview {
  final int id;
  final String name;
  final String? description;
  final String? logoUrl;
  final bool isDefault;
  final int membersCount;
  final DateTime createdAt;

  TeamPreview({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    required this.isDefault,
    required this.membersCount,
    required this.createdAt,
  });

  factory TeamPreview.fromJson(Map<String, dynamic> json) {
    return TeamPreview(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      isDefault: json['is_default'] as bool,
      membersCount: json['members_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Détail complet d'une équipe
class TeamDetail {
  final int id;
  final String name;
  final String? description;
  final String? logoUrl;
  final bool isDefault;
  final int ownerId;
  final List<TeamMember> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  TeamDetail({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    required this.isDefault,
    required this.ownerId,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeamDetail.fromJson(Map<String, dynamic> json) {
    return TeamDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      isDefault: json['is_default'] as bool,
      ownerId: json['owner_id'] as int,
      members: (json['members'] as List<dynamic>)
          .map((e) => TeamMember.fromJson(e))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Retourne les titulaires (slot 0-4)
  List<TeamMember> get starters =>
      members.where((m) => m.slotIndex < 5).toList()
        ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));

  /// Retourne les remplaçants (slot 5+)
  List<TeamMember> get substitutes =>
      members.where((m) => m.slotIndex >= 5).toList()
        ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
}

/// Input pour mettre à jour un membre de "Mon Équipe"
class MyTeamMemberInput {
  final int userId;
  final PlayerPosition position;
  final int slotIndex;

  MyTeamMemberInput({
    required this.userId,
    required this.position,
    required this.slotIndex,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'position': position.value,
    'slot_index': slotIndex,
  };
}

/// Statut d'une candidature
enum ApplicationStatus {
  pending,
  accepted,
  rejected;

  String get value => name;

  static ApplicationStatus fromString(String value) {
    return ApplicationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ApplicationStatus.pending,
    );
  }
}

/// Poste ouvert (recherche de joueur)
class OpenSlot {
  final int id;
  final int teamId;
  final String teamName;
  final String? teamLogoUrl;
  final String ownerUsername;
  final PlayerPosition position;
  final int slotIndex;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final int applicationsCount;

  OpenSlot({
    required this.id,
    required this.teamId,
    required this.teamName,
    this.teamLogoUrl,
    required this.ownerUsername,
    required this.position,
    required this.slotIndex,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.applicationsCount,
  });

  factory OpenSlot.fromJson(Map<String, dynamic> json) {
    return OpenSlot(
      id: json['id'] as int,
      teamId: json['team_id'] as int,
      teamName: json['team_name'] as String,
      teamLogoUrl: json['team_logo_url'] as String?,
      ownerUsername: json['owner_username'] as String,
      position: PlayerPosition.fromString(json['position'] as String),
      slotIndex: json['slot_index'] as int,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      applicationsCount: json['applications_count'] as int,
    );
  }
}

/// Candidature à un poste
class SlotApplication {
  final int id;
  final int openSlotId;
  final TeamUserInfo applicant;
  final String? message;
  final ApplicationStatus status;
  final DateTime appliedAt;
  final DateTime? respondedAt;

  SlotApplication({
    required this.id,
    required this.openSlotId,
    required this.applicant,
    this.message,
    required this.status,
    required this.appliedAt,
    this.respondedAt,
  });

  factory SlotApplication.fromJson(Map<String, dynamic> json) {
    return SlotApplication(
      id: json['id'] as int,
      openSlotId: json['open_slot_id'] as int,
      applicant: TeamUserInfo.fromJson(json['applicant']),
      message: json['message'] as String?,
      status: ApplicationStatus.fromString(json['status'] as String),
      appliedAt: DateTime.parse(json['applied_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
    );
  }
}

/// Candidature avec détails du poste (pour le candidat)
class SlotApplicationDetail {
  final int id;
  final OpenSlot openSlot;
  final String? message;
  final ApplicationStatus status;
  final DateTime appliedAt;
  final DateTime? respondedAt;

  SlotApplicationDetail({
    required this.id,
    required this.openSlot,
    this.message,
    required this.status,
    required this.appliedAt,
    this.respondedAt,
  });

  factory SlotApplicationDetail.fromJson(Map<String, dynamic> json) {
    return SlotApplicationDetail(
      id: json['id'] as int,
      openSlot: OpenSlot.fromJson(json['open_slot']),
      message: json['message'] as String?,
      status: ApplicationStatus.fromString(json['status'] as String),
      appliedAt: DateTime.parse(json['applied_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
    );
  }
}

/// Message dans le chat d'équipe
class TeamChatMessage {
  final int id;
  final int teamId;
  final TeamUserInfo sender;
  final String content;
  final DateTime createdAt;
  final bool isSystemMessage;

  TeamChatMessage({
    required this.id,
    required this.teamId,
    required this.sender,
    required this.content,
    required this.createdAt,
    required this.isSystemMessage,
  });

  factory TeamChatMessage.fromJson(Map<String, dynamic> json) {
    return TeamChatMessage(
      id: json['id'] as int,
      teamId: json['team_id'] as int,
      sender: TeamUserInfo.fromJson(json['sender']),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSystemMessage: json['is_system_message'] as bool,
    );
  }
}

/// Infos sur un chat d'équipe
class TeamChatInfo {
  final int teamId;
  final String teamName;
  final String? teamLogoUrl;
  final int membersCount;
  final TeamChatMessage? lastMessage;
  final int unreadCount;

  TeamChatInfo({
    required this.teamId,
    required this.teamName,
    this.teamLogoUrl,
    required this.membersCount,
    this.lastMessage,
    required this.unreadCount,
  });

  factory TeamChatInfo.fromJson(Map<String, dynamic> json) {
    return TeamChatInfo(
      teamId: json['team_id'] as int,
      teamName: json['team_name'] as String,
      teamLogoUrl: json['team_logo_url'] as String?,
      membersCount: json['members_count'] as int,
      lastMessage: json['last_message'] != null
          ? TeamChatMessage.fromJson(json['last_message'])
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}

/// Statut d'un défi
enum ChallengeStatus {
  pending,
  accepted,
  rejected,
  cancelled,
  expired,
  completed;

  String get displayName {
    switch (this) {
      case ChallengeStatus.pending:
        return 'En attente';
      case ChallengeStatus.accepted:
        return 'Accepté';
      case ChallengeStatus.rejected:
        return 'Refusé';
      case ChallengeStatus.cancelled:
        return 'Annulé';
      case ChallengeStatus.expired:
        return 'Expiré';
      case ChallengeStatus.completed:
        return 'Terminé';
    }
  }

  static ChallengeStatus fromString(String value) {
    return ChallengeStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ChallengeStatus.pending,
    );
  }
}

/// Préférences de recherche d'adversaire
class TeamSearchPreference {
  final int teamId;
  final bool isLookingForOpponent;
  final List<String>? preferredDays;
  final List<String>? preferredTimeSlots;
  final String? preferredLocations;
  final String? skillLevel;
  final String? description;
  final DateTime? updatedAt;

  TeamSearchPreference({
    required this.teamId,
    required this.isLookingForOpponent,
    this.preferredDays,
    this.preferredTimeSlots,
    this.preferredLocations,
    this.skillLevel,
    this.description,
    this.updatedAt,
  });

  factory TeamSearchPreference.fromJson(Map<String, dynamic> json) {
    return TeamSearchPreference(
      teamId: json['team_id'] as int,
      isLookingForOpponent: json['is_looking_for_opponent'] as bool? ?? false,
      preferredDays: (json['preferred_days'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      preferredTimeSlots: (json['preferred_time_slots'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      preferredLocations: json['preferred_locations'] as String?,
      skillLevel: json['skill_level'] as String?,
      description: json['description'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}

/// Équipe en recherche d'adversaire
class TeamSearchResult {
  final int teamId;
  final String teamName;
  final String? teamLogoUrl;
  final String ownerUsername;
  final int membersCount;
  final String? skillLevel;
  final List<String>? preferredDays;
  final List<String>? preferredTimeSlots;
  final String? preferredLocations;
  final String? description;

  TeamSearchResult({
    required this.teamId,
    required this.teamName,
    this.teamLogoUrl,
    required this.ownerUsername,
    required this.membersCount,
    this.skillLevel,
    this.preferredDays,
    this.preferredTimeSlots,
    this.preferredLocations,
    this.description,
  });

  factory TeamSearchResult.fromJson(Map<String, dynamic> json) {
    return TeamSearchResult(
      teamId: json['team_id'] as int,
      teamName: json['team_name'] as String,
      teamLogoUrl: json['team_logo_url'] as String?,
      ownerUsername: json['owner_username'] as String,
      membersCount: json['members_count'] as int? ?? 0,
      skillLevel: json['skill_level'] as String?,
      preferredDays: (json['preferred_days'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      preferredTimeSlots: (json['preferred_time_slots'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      preferredLocations: json['preferred_locations'] as String?,
      description: json['description'] as String?,
    );
  }
}

/// Défi de match entre deux équipes
class MatchChallenge {
  final int id;
  final int challengerTeamId;
  final String challengerTeamName;
  final String? challengerTeamLogoUrl;
  final String challengerOwnerUsername;
  final int challengedTeamId;
  final String challengedTeamName;
  final String? challengedTeamLogoUrl;
  final String challengedOwnerUsername;
  final ChallengeStatus status;
  final DateTime? proposedDate;
  final String? proposedLocation;
  final String? message;
  final String? responseMessage;
  final int? challengerScore;
  final int? challengedScore;
  // Validation mutuelle du score
  final bool challengerScoreSubmitted;
  final bool challengedScoreSubmitted;
  // Scores soumis par chaque équipe (visibles par l'autre)
  final int? challengerSubmittedChallengerScore;
  final int? challengerSubmittedChallengedScore;
  final int? challengedSubmittedChallengerScore;
  final int? challengedSubmittedChallengedScore;
  final bool scoreValidated;
  final bool scoreConflict;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime? matchPlayedAt;

  MatchChallenge({
    required this.id,
    required this.challengerTeamId,
    required this.challengerTeamName,
    this.challengerTeamLogoUrl,
    required this.challengerOwnerUsername,
    required this.challengedTeamId,
    required this.challengedTeamName,
    this.challengedTeamLogoUrl,
    required this.challengedOwnerUsername,
    required this.status,
    this.proposedDate,
    this.proposedLocation,
    this.message,
    this.responseMessage,
    this.challengerScore,
    this.challengedScore,
    this.challengerScoreSubmitted = false,
    this.challengedScoreSubmitted = false,
    this.challengerSubmittedChallengerScore,
    this.challengerSubmittedChallengedScore,
    this.challengedSubmittedChallengerScore,
    this.challengedSubmittedChallengedScore,
    this.scoreValidated = false,
    this.scoreConflict = false,
    required this.createdAt,
    this.respondedAt,
    this.matchPlayedAt,
  });

  /// Vérifie si l'équipe donnée a déjà soumis son score
  bool hasSubmittedScore(int teamId) {
    if (teamId == challengerTeamId) {
      return challengerScoreSubmitted;
    } else if (teamId == challengedTeamId) {
      return challengedScoreSubmitted;
    }
    return false;
  }

  /// Retourne le score soumis par l'adversaire (si disponible)
  /// Retourne une Map avec 'myScore' et 'opponentScore' du point de vue de l'adversaire
  Map<String, int>? getOpponentSubmittedScore(int myTeamId) {
    if (myTeamId == challengerTeamId && challengedScoreSubmitted) {
      // Je suis le challenger, l'adversaire (challenged) a soumis
      return {
        'challengerScore': challengedSubmittedChallengerScore ?? 0,
        'challengedScore': challengedSubmittedChallengedScore ?? 0,
      };
    } else if (myTeamId == challengedTeamId && challengerScoreSubmitted) {
      // Je suis le challenged, l'adversaire (challenger) a soumis
      return {
        'challengerScore': challengerSubmittedChallengerScore ?? 0,
        'challengedScore': challengerSubmittedChallengedScore ?? 0,
      };
    }
    return null;
  }

  /// Retourne le nom de l'équipe adverse
  String getOpponentName(int myTeamId) {
    if (myTeamId == challengerTeamId) {
      return challengedTeamName;
    }
    return challengerTeamName;
  }

  /// Retourne le logo de l'équipe adverse
  String? getOpponentLogoUrl(int myTeamId) {
    if (myTeamId == challengerTeamId) {
      return challengedTeamLogoUrl;
    }
    return challengerTeamLogoUrl;
  }

  factory MatchChallenge.fromJson(Map<String, dynamic> json) {
    return MatchChallenge(
      id: json['id'] as int,
      challengerTeamId: json['challenger_team_id'] as int,
      challengerTeamName: json['challenger_team_name'] as String,
      challengerTeamLogoUrl: json['challenger_team_logo_url'] as String?,
      challengerOwnerUsername: json['challenger_owner_username'] as String,
      challengedTeamId: json['challenged_team_id'] as int,
      challengedTeamName: json['challenged_team_name'] as String,
      challengedTeamLogoUrl: json['challenged_team_logo_url'] as String?,
      challengedOwnerUsername: json['challenged_owner_username'] as String,
      status: ChallengeStatus.fromString(json['status'] as String),
      proposedDate: json['proposed_date'] != null
          ? DateTime.parse(json['proposed_date'])
          : null,
      proposedLocation: json['proposed_location'] as String?,
      message: json['message'] as String?,
      responseMessage: json['response_message'] as String?,
      challengerScore: json['challenger_score'] as int?,
      challengedScore: json['challenged_score'] as int?,
      challengerScoreSubmitted:
          json['challenger_score_submitted'] as bool? ?? false,
      challengedScoreSubmitted:
          json['challenged_score_submitted'] as bool? ?? false,
      challengerSubmittedChallengerScore:
          json['challenger_submitted_challenger_score'] as int?,
      challengerSubmittedChallengedScore:
          json['challenger_submitted_challenged_score'] as int?,
      challengedSubmittedChallengerScore:
          json['challenged_submitted_challenger_score'] as int?,
      challengedSubmittedChallengedScore:
          json['challenged_submitted_challenged_score'] as int?,
      scoreValidated: json['score_validated'] as bool? ?? false,
      scoreConflict: json['score_conflict'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'])
          : null,
      matchPlayedAt: json['match_played_at'] != null
          ? DateTime.parse(json['match_played_at'])
          : null,
    );
  }
}

/// Modèle de message de chat de match
class MatchChatMessage {
  final int id;
  final int challengeId;
  final int senderTeamId;
  final String senderTeamName;
  final int senderUserId;
  final String senderUsername;
  final String? senderAvatarUrl;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  MatchChatMessage({
    required this.id,
    required this.challengeId,
    required this.senderTeamId,
    required this.senderTeamName,
    required this.senderUserId,
    required this.senderUsername,
    this.senderAvatarUrl,
    required this.content,
    required this.createdAt,
    required this.isRead,
  });

  factory MatchChatMessage.fromJson(Map<String, dynamic> json) {
    return MatchChatMessage(
      id: json['id'] as int,
      challengeId: json['challenge_id'] as int,
      senderTeamId: json['sender_team_id'] as int,
      senderTeamName: json['sender_team_name'] as String,
      senderUserId: json['sender_user_id'] as int,
      senderUsername: json['sender_username'] as String,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}
