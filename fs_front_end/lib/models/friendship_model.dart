/// Modèle représentant une relation d'amitié
class FriendshipModel {
  final int id;
  final int userId;
  final int friendId;
  final String status; // pending, accepted, rejected, blocked
  final DateTime createdAt;
  final DateTime? updatedAt;
  final FriendUserModel? friend; // Infos de l'ami

  FriendshipModel({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.friend,
  });

  factory FriendshipModel.fromJson(Map<String, dynamic> json) {
    return FriendshipModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      friendId: json['friend_id'] as int,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      friend: json['friend'] != null
          ? FriendUserModel.fromJson(json['friend'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'friend_id': friendId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'friend': friend?.toJson(),
    };
  }
}

/// Modèle simplifié pour les infos d'un ami
class FriendUserModel {
  final int id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? preferredPosition;
  final double rating;

  FriendUserModel({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.preferredPosition,
    required this.rating,
  });

  factory FriendUserModel.fromJson(Map<String, dynamic> json) {
    return FriendUserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      preferredPosition: json['preferred_position'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'preferred_position': preferredPosition,
      'rating': rating,
    };
  }
}
