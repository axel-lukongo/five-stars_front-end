import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/fields_service.dart';

/// Provider pour gérer l'état des terrains à proximité
class FieldsProvider extends ChangeNotifier {
  final FieldsService _fieldsService = FieldsService.instance;

  // État
  List<SoccerField> _fields = [];
  bool _isLoading = false;
  String? _error;
  Position? _currentPosition;
  bool _hasLocationPermission = false;
  int _searchRadiusMeters =
      20000; // 20km par défaut (les centres de foot5 sont souvent plus éloignés)

  // Filtres
  bool _showOnlyFiveSide = false;
  bool _showOnlyIndoor = false;
  FieldType? _filterType;

  // Getters
  List<SoccerField> get fields => _filteredFields;
  List<SoccerField> get allFields => _fields;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Position? get currentPosition => _currentPosition;
  bool get hasLocationPermission => _hasLocationPermission;
  int get searchRadiusMeters => _searchRadiusMeters;
  bool get showOnlyFiveSide => _showOnlyFiveSide;
  bool get showOnlyIndoor => _showOnlyIndoor;
  FieldType? get filterType => _filterType;

  /// Champs filtrés selon les critères
  List<SoccerField> get _filteredFields {
    var filtered = _fields;

    if (_showOnlyFiveSide) {
      filtered = filtered.where((f) => f.isFiveSide).toList();
    }

    if (_showOnlyIndoor) {
      filtered = filtered.where((f) => f.isIndoor).toList();
    }

    if (_filterType != null) {
      filtered = filtered.where((f) => f.type == _filterType).toList();
    }

    return filtered;
  }

  /// Nombre de terrains par type
  Map<FieldType, int> get fieldCountByType {
    final counts = <FieldType, int>{};
    for (final field in _fields) {
      counts[field.type] = (counts[field.type] ?? 0) + 1;
    }
    return counts;
  }

  /// Initialise la localisation et charge les terrains
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Vérifier les permissions
      _hasLocationPermission = await _fieldsService.checkLocationPermission();

      if (_hasLocationPermission) {
        // Obtenir la position actuelle
        _currentPosition = await _fieldsService.getCurrentPosition();

        if (_currentPosition != null) {
          // Charger les terrains à proximité
          await _loadNearbyFields();
        } else {
          _error = 'Impossible d\'obtenir votre position';
        }
      } else {
        _error = 'Permission de localisation refusée';
      }
    } catch (e) {
      debugPrint('Error initializing fields: $e');
      _error = 'Erreur lors de l\'initialisation';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Charge les terrains à proximité de la position actuelle
  Future<void> _loadNearbyFields() async {
    if (_currentPosition == null) return;

    try {
      _fields = await _fieldsService.searchNearbyFields(
        lat: _currentPosition!.latitude,
        lon: _currentPosition!.longitude,
        radiusMeters: _searchRadiusMeters,
      );
      _error = null;
    } catch (e) {
      debugPrint('Error loading nearby fields: $e');
      _error = 'Erreur lors de la recherche des terrains';
    }
  }

  /// Rafraîchit la liste des terrains
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Mettre à jour la position
      _currentPosition = await _fieldsService.getCurrentPosition();

      if (_currentPosition != null) {
        await _loadNearbyFields();
      } else {
        _error = 'Impossible d\'obtenir votre position';
      }
    } catch (e) {
      debugPrint('Error refreshing fields: $e');
      _error = 'Erreur lors du rafraîchissement';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Recherche autour d'une position spécifique
  Future<void> searchAroundPosition(double lat, double lon) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _fields = await _fieldsService.searchNearbyFields(
        lat: lat,
        lon: lon,
        radiusMeters: _searchRadiusMeters,
      );
      _error = null;
    } catch (e) {
      debugPrint('Error searching around position: $e');
      _error = 'Erreur lors de la recherche';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Change le rayon de recherche
  void setSearchRadius(int radiusMeters) {
    if (_searchRadiusMeters != radiusMeters) {
      _searchRadiusMeters = radiusMeters;
      notifyListeners();
      // Recharger avec le nouveau rayon
      if (_currentPosition != null) {
        refresh();
      }
    }
  }

  /// Active/désactive le filtre foot à 5 uniquement
  void toggleFiveSideFilter() {
    _showOnlyFiveSide = !_showOnlyFiveSide;
    notifyListeners();
  }

  /// Active/désactive le filtre indoor uniquement
  void toggleIndoorFilter() {
    _showOnlyIndoor = !_showOnlyIndoor;
    notifyListeners();
  }

  /// Définit le filtre par type
  void setTypeFilter(FieldType? type) {
    _filterType = type;
    notifyListeners();
  }

  /// Réinitialise tous les filtres
  void clearFilters() {
    _showOnlyFiveSide = false;
    _showOnlyIndoor = false;
    _filterType = null;
    notifyListeners();
  }

  /// Obtient un terrain par son ID
  SoccerField? getFieldById(String id) {
    try {
      return _fields.firstWhere((f) => f.id == id);
    } catch (e) {
      return null;
    }
  }
}
