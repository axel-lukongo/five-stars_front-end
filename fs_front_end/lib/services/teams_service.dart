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
  String get baseUrl => '${ApiConfig.baseUrl.replaceAll(':8000', ':8003')}';

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
        Uri.parse('$baseUrl/teams/$teamId'),
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
        Uri.parse('$baseUrl/teams/$teamId'),
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
        Uri.parse('$baseUrl/teams/$teamId'),
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
        Uri.parse('$baseUrl/teams/$teamId/members'),
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
        Uri.parse('$baseUrl/teams/$teamId/members/$memberUserId/position'),
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
        Uri.parse('$baseUrl/teams/$teamId/members/$memberUserId'),
        headers: await _headers,
      );

      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Erreur removeMember: $e');
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
        Uri.parse('$baseUrl/teams/$teamId/slots/open'),
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
        Uri.parse('$baseUrl/teams/$teamId/open-slots'),
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
        Uri.parse('$baseUrl/teams/$teamId/applications'),
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
      var url = '$baseUrl/teams/$teamId/messages?limit=$limit';
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
        Uri.parse('$baseUrl/teams/$teamId/messages'),
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
      final response = await http.get(
        Uri.parse('$baseUrl/my-team-chats'),
        headers: await _headers,
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
        Uri.parse('$baseUrl/teams/$teamId/messages/read'),
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
        return 'M';
      case PlayerPosition.forward:
        return 'A';
      case PlayerPosition.substitute:
        return 'R';
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
