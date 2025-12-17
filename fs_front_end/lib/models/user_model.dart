/// Modèle représentant un utilisateur
class UserModel {
  final int id;
  final String username;
  final String? email;
  final String? phone;
  final String? bio;
  final String? preferredPosition;
  final String? avatarUrl;
  final double? rating;
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  final int matchesDrawn;

  UserModel({
    required this.id,
    required this.username,
    this.email,
    this.phone,
    this.bio,
    this.preferredPosition,
    this.avatarUrl,
    this.rating,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.matchesLost = 0,
    this.matchesDrawn = 0,
  });

  /// Crée un UserModel à partir d'un JSON (réponse API)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      preferredPosition: json['preferred_position'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      matchesPlayed: json['matches_played'] as int? ?? 0,
      matchesWon: json['matches_won'] as int? ?? 0,
      matchesLost: json['matches_lost'] as int? ?? 0,
      matchesDrawn: json['matches_drawn'] as int? ?? 0,
    );
  }

  /// Convertit le modèle en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'bio': bio,
      'preferred_position': preferredPosition,
      'avatar_url': avatarUrl,
      'rating': rating,
      'matches_played': matchesPlayed,
      'matches_won': matchesWon,
      'matches_lost': matchesLost,
      'matches_drawn': matchesDrawn,
    };
  }

  /// Calcule le pourcentage de victoires
  double get winRate {
    if (matchesPlayed == 0) return 0;
    return (matchesWon / matchesPlayed) * 100;
  }
}
