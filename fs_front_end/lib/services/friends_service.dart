import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

/// Service pour gérer les amis
class FriendsService {
  FriendsService._privateConstructor();
  static final FriendsService instance = FriendsService._privateConstructor();

  // Le service friends tourne sur un port différent
  String get baseUrl => ApiConfig.friendsUrl;

  /// Récupère la liste complète des amis et demandes
  Future<FriendsListResponse?> getFriendsList() async {
    final authHeader = await AuthService.instance.getAuthHeader();
    if (authHeader == null) return null;

    final url = Uri.parse('$baseUrl');
    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return FriendsListResponse.fromJson(data);
    }
    return null;
  }

  /// Envoie une demande d'amitié
  Future<Map<String, dynamic>> sendFriendRequest(int addresseeId) async {
    final authHeader = await AuthService.instance.getAuthHeader();
    if (authHeader == null) {
      return {'ok': false, 'message': 'Non authentifié'};
    }

    final url = Uri.parse('$baseUrl/request');
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
      body: jsonEncode({'addressee_id': addresseeId}),
    );

    if (resp.statusCode == 201) {
      return {'ok': true};
    }

    try {
      final errorData = jsonDecode(resp.body);
      return {'ok': false, 'message': errorData['detail'] ?? resp.body};
    } catch (_) {
      return {'ok': false, 'message': resp.body};
    }
  }

  /// Accepte ou refuse une demande d'amitié
  Future<Map<String, dynamic>> respondToRequest(
    int friendshipId,
    bool accept,
  ) async {
    final authHeader = await AuthService.instance.getAuthHeader();
    if (authHeader == null) {
      return {'ok': false, 'message': 'Non authentifié'};
    }

    final url = Uri.parse('$baseUrl/$friendshipId/respond');
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
      body: jsonEncode({'accept': accept}),
    );

    if (resp.statusCode == 200) {
      return {'ok': true};
    }

    try {
      final errorData = jsonDecode(resp.body);
      return {'ok': false, 'message': errorData['detail'] ?? resp.body};
    } catch (_) {
      return {'ok': false, 'message': resp.body};
    }
  }

  /// Supprime un ami ou annule une demande
  Future<Map<String, dynamic>> removeFriend(int friendshipId) async {
    final authHeader = await AuthService.instance.getAuthHeader();
    if (authHeader == null) {
      return {'ok': false, 'message': 'Non authentifié'};
    }

    final url = Uri.parse('$baseUrl/$friendshipId');
    final resp = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
    );

    if (resp.statusCode == 204) {
      return {'ok': true};
    }

    try {
      final errorData = jsonDecode(resp.body);
      return {'ok': false, 'message': errorData['detail'] ?? resp.body};
    } catch (_) {
      return {'ok': false, 'message': resp.body};
    }
  }

  /// Recherche des utilisateurs
  Future<List<SearchUserResult>> searchUsers(String query) async {
    final authHeader = await AuthService.instance.getAuthHeader();
    if (authHeader == null) return [];

    final url = Uri.parse('$baseUrl/search?q=$query');
    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
    );

    if (resp.statusCode == 200) {
      final List<dynamic> data = jsonDecode(resp.body);
      return data.map((e) => SearchUserResult.fromJson(e)).toList();
    }
    return [];
  }
}

// ============ Modèles ============

class UserBasicInfo {
  final int id;
  final String username;
  final String? avatarUrl;
  final String? preferredPosition;
  final double? rating;

  UserBasicInfo({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.preferredPosition,
    this.rating,
  });

  factory UserBasicInfo.fromJson(Map<String, dynamic> json) {
    return UserBasicInfo(
      id: json['id'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      preferredPosition: json['preferred_position'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}

class FriendWithInfo {
  final int friendshipId;
  final UserBasicInfo user;
  final String status;
  final DateTime createdAt;

  FriendWithInfo({
    required this.friendshipId,
    required this.user,
    required this.status,
    required this.createdAt,
  });

  factory FriendWithInfo.fromJson(Map<String, dynamic> json) {
    return FriendWithInfo(
      friendshipId: json['friendship_id'] as int,
      user: UserBasicInfo.fromJson(json['user']),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PendingRequest {
  final int friendshipId;
  final UserBasicInfo fromUser;
  final DateTime createdAt;

  PendingRequest({
    required this.friendshipId,
    required this.fromUser,
    required this.createdAt,
  });

  factory PendingRequest.fromJson(Map<String, dynamic> json) {
    return PendingRequest(
      friendshipId: json['friendship_id'] as int,
      fromUser: UserBasicInfo.fromJson(json['from_user']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class FriendsListResponse {
  final List<FriendWithInfo> friends;
  final List<PendingRequest> pendingReceived;
  final List<FriendWithInfo> pendingSent;

  FriendsListResponse({
    required this.friends,
    required this.pendingReceived,
    required this.pendingSent,
  });

  factory FriendsListResponse.fromJson(Map<String, dynamic> json) {
    return FriendsListResponse(
      friends: (json['friends'] as List<dynamic>)
          .map((e) => FriendWithInfo.fromJson(e))
          .toList(),
      pendingReceived: (json['pending_received'] as List<dynamic>)
          .map((e) => PendingRequest.fromJson(e))
          .toList(),
      pendingSent: (json['pending_sent'] as List<dynamic>)
          .map((e) => FriendWithInfo.fromJson(e))
          .toList(),
    );
  }
}

class SearchUserResult {
  final UserBasicInfo user;
  final String? friendshipStatus;

  SearchUserResult({required this.user, this.friendshipStatus});

  factory SearchUserResult.fromJson(Map<String, dynamic> json) {
    return SearchUserResult(
      user: UserBasicInfo.fromJson(json['user']),
      friendshipStatus: json['friendship_status'] as String?,
    );
  }
}
