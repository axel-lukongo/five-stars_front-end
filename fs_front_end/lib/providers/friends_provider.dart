import 'package:flutter/foundation.dart';
import '../services/friends_service.dart';

/// État du provider pour la gestion des amis
enum FriendsLoadingState { idle, loading, loaded, error }

/// Provider pour gérer l'état des amis
class FriendsProvider with ChangeNotifier {
  final FriendsService _friendsService = FriendsService.instance;

  // État
  FriendsLoadingState _state = FriendsLoadingState.idle;
  String? _errorMessage;

  // Données
  List<FriendWithInfo> _friends = [];
  List<PendingRequest> _pendingReceived = [];
  List<FriendWithInfo> _pendingSent = [];
  List<SearchUserResult> _searchResults = [];
  bool _isSearching = false;

  // Getters
  FriendsLoadingState get state => _state;
  String? get errorMessage => _errorMessage;
  List<FriendWithInfo> get friends => _friends;
  List<PendingRequest> get pendingReceived => _pendingReceived;
  List<FriendWithInfo> get pendingSent => _pendingSent;
  List<SearchUserResult> get searchResults => _searchResults;
  bool get isSearching => _isSearching;

  int get totalPendingCount => _pendingReceived.length;
  int get friendsCount => _friends.length;

  /// Charge la liste des amis et demandes
  Future<void> loadFriends() async {
    _state = FriendsLoadingState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _friendsService.getFriendsList();

      if (response != null) {
        _friends = response.friends;
        _pendingReceived = response.pendingReceived;
        _pendingSent = response.pendingSent;
        _state = FriendsLoadingState.loaded;
      } else {
        _state = FriendsLoadingState.error;
        _errorMessage = 'Impossible de charger les amis';
      }
    } catch (e) {
      _state = FriendsLoadingState.error;
      _errorMessage = 'Erreur: $e';
    }

    notifyListeners();
  }

  /// Recherche des utilisateurs
  Future<void> searchUsers(String query) async {
    if (query.length < 2) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await _friendsService.searchUsers(query);
    } catch (e) {
      _searchResults = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  /// Efface les résultats de recherche
  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  /// Envoie une demande d'amitié
  Future<Map<String, dynamic>> sendFriendRequest(int addresseeId) async {
    final result = await _friendsService.sendFriendRequest(addresseeId);

    if (result['ok'] == true) {
      // Recharger la liste pour mettre à jour pendingSent
      await loadFriends();
      // Mettre à jour searchResults pour refléter le changement
      _searchResults = _searchResults.map((sr) {
        if (sr.user.id == addresseeId) {
          return SearchUserResult(user: sr.user, friendshipStatus: 'pending');
        }
        return sr;
      }).toList();
      notifyListeners();
    }

    return result;
  }

  /// Accepte une demande d'amitié
  Future<Map<String, dynamic>> acceptFriendRequest(int friendshipId) async {
    final result = await _friendsService.respondToRequest(friendshipId, true);

    if (result['ok'] == true) {
      await loadFriends();
    }

    return result;
  }

  /// Refuse une demande d'amitié
  Future<Map<String, dynamic>> rejectFriendRequest(int friendshipId) async {
    final result = await _friendsService.respondToRequest(friendshipId, false);

    if (result['ok'] == true) {
      // Retirer de la liste locale
      _pendingReceived.removeWhere((r) => r.friendshipId == friendshipId);
      notifyListeners();
    }

    return result;
  }

  /// Supprime un ami ou annule une demande
  Future<Map<String, dynamic>> removeFriend(int friendshipId) async {
    final result = await _friendsService.removeFriend(friendshipId);

    if (result['ok'] == true) {
      // Retirer de la liste locale
      _friends.removeWhere((f) => f.friendshipId == friendshipId);
      _pendingSent.removeWhere((f) => f.friendshipId == friendshipId);
      notifyListeners();
    }

    return result;
  }

  /// Réinitialise l'état (pour la déconnexion)
  void reset() {
    _state = FriendsLoadingState.idle;
    _errorMessage = null;
    _friends = [];
    _pendingReceived = [];
    _pendingSent = [];
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }
}
