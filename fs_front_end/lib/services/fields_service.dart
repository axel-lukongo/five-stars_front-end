import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// Service pour trouver les terrains de foot à proximité
/// Utilise Foursquare Places API + base de données locale
class FieldsService {
  FieldsService._privateConstructor();
  static final FieldsService instance = FieldsService._privateConstructor();

  // Clé API Foursquare
  static const String _foursquareApiKey =
      'WZAVZL2O0DRGZNOQWQRTGAF2DZLUBDEUMFPNAAPLLUHF3QEB';

  // Catégories Foursquare pour les terrains de foot
  // https://docs.foursquare.com/data-products/docs/categories
  static const List<String> _soccerCategories = [
    '18000', // Sports and Recreation
    '18021', // Soccer Field
    '18008', // Athletic Field
    '18039', // Sports Club
    '18020', // Recreation Center
  ];

  /// Base de données locale des centres de foot à 5 connus
  /// (pour compléter Foursquare si nécessaire)
  static final List<Map<String, dynamic>> _knownCenters = [
    // Urban Soccer - Île-de-France
    {
      'id': 'local_us_evry',
      'name': 'Urban Soccer Évry',
      'lat': 48.6289,
      'lon': 2.4301,
      'address': 'ZAC du Bois Briard, Évry-Courcouronnes',
      'phone': '+33 1 60 79 20 20',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_aubervilliers',
      'name': 'Urban Soccer Aubervilliers',
      'lat': 48.9075,
      'lon': 2.3743,
      'address': 'Rue des Gardinoux, Aubervilliers',
      'phone': '+33 1 84 03 00 20',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_puteaux',
      'name': 'Urban Soccer Puteaux (La Défense)',
      'lat': 48.8760,
      'lon': 2.2435,
      'address': '1 Allée des Sports, Puteaux',
      'phone': '+33 1 79 36 38 50',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_creteil',
      'name': 'Urban Soccer Créteil',
      'lat': 48.7775,
      'lon': 2.4628,
      'address': 'Créteil',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_torcy',
      'name': 'Urban Soccer Torcy',
      'lat': 48.8501,
      'lon': 2.6563,
      'address': 'Torcy',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_orsay',
      'name': 'Urban Soccer Orsay',
      'lat': 48.7084,
      'lon': 2.1782,
      'address': 'Rue Louis de Broglie, Campus Paris-Saclay, Orsay 91400',
      'phone': '+33 1 69 35 61 00',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_asnieres',
      'name': 'Urban Soccer Asnières',
      'lat': 48.9128,
      'lon': 2.2853,
      'address': '40 Rue du Ménil, Asnières-sur-Seine 92600',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_rungis',
      'name': 'Urban Soccer Rungis',
      'lat': 48.7486,
      'lon': 2.3611,
      'address': 'Rungis 94150',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_ivry',
      'name': 'Urban Soccer Ivry',
      'lat': 48.8150,
      'lon': 2.3920,
      'address': 'Ivry-sur-Seine 94200',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_velizy',
      'name': 'Urban Soccer Vélizy',
      'lat': 48.7810,
      'lon': 2.1910,
      'address': 'Vélizy-Villacoublay 78140',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    // Urban Soccer - Autres régions
    {
      'id': 'local_us_lyon',
      'name': 'Urban Soccer Lyon Saint-Priest',
      'lat': 45.7117,
      'lon': 4.9047,
      'address': 'Boulevard de Parilly, Saint-Priest',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_lille',
      'name': 'Urban Soccer Lille',
      'lat': 50.6167,
      'lon': 3.0995,
      'address': 'Rue Paul Langevin, Lezennes',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_nantes',
      'name': 'Urban Soccer Nantes',
      'lat': 47.1903,
      'lon': -1.4848,
      'address': 'Rue Marie Curie, Saint-Sébastien-sur-Loire',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_strasbourg',
      'name': 'Urban Soccer Strasbourg',
      'lat': 48.5935,
      'lon': 7.7316,
      'address': '48 Chemin Haut, Cronenbourg',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_montpellier',
      'name': 'Urban Soccer Montpellier',
      'lat': 43.6287,
      'lon': 3.9093,
      'address': 'Castelnau-le-Lez',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_clermont',
      'name': 'Urban Soccer Clermont-Ferrand',
      'lat': 45.7554,
      'lon': 3.1368,
      'address': '46 Rue des Varennes, Aubière',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_angers',
      'name': 'Urban Soccer Angers',
      'lat': 47.4724,
      'lon': -0.6047,
      'address': 'Avenue du Général Patton, Beaucouzé',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_lemans',
      'name': 'Urban Soccer Le Mans',
      'lat': 47.9627,
      'lon': 0.2188,
      'address': 'Voie de la Liberté, Le Tertre Rouge',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_us_dijon',
      'name': 'Urban Soccer Dijon',
      'lat': 47.3403,
      'lon': 5.0730,
      'address': '28 Rue de Cracovie, Cap Nord',
      'website': 'https://www.urbansoccer.fr',
      'type': 'fiveSide',
    },
    // B14
    {
      'id': 'local_b14_bondoufle',
      'name': 'B14 Bondoufle',
      'lat': 48.6225,
      'lon': 2.3806,
      'address': 'Bondoufle',
      'phone': '+33 1 81 85 05 60',
      'website': 'https://www.b-14.fr',
      'type': 'fiveSide',
    },
    // Le Five - Île-de-France
    {
      'id': 'local_five_paris18',
      'name': 'Le Five Paris 18',
      'lat': 48.8978,
      'lon': 2.3698,
      'address': '217 Rue d\'Aubervilliers, 75018 Paris',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_paris17',
      'name': 'Le Five Paris 17',
      'lat': 48.9004,
      'lon': 2.3221,
      'address': '26 Rue Hélène et François Missoffe, 75017 Paris',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_paris13',
      'name': 'Le Five Paris 13',
      'lat': 48.8180,
      'lon': 2.3655,
      'address': '9 Avenue de la Porte de Choisy, 75013 Paris',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_bobigny',
      'name': 'Le Five FC Bobigny',
      'lat': 48.9014,
      'lon': 2.4316,
      'address': 'Rue Arago, Bobigny',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_herblay',
      'name': 'Le Five Herblay / Carrières-sous-Poissy',
      'lat': 48.9470,
      'lon': 2.0228,
      'address': 'Rue Léonard de Vinci, Carrières-sous-Poissy',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_sarcelles',
      'name': 'Le Five Sarcelles',
      'lat': 48.9978,
      'lon': 2.3901,
      'address': '32 Rue de l\'Escouvrier, Sarcelles',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_villette',
      'name': 'Le Five Villette / Aubervilliers',
      'lat': 48.9067,
      'lon': 2.3856,
      'address': '25 Rue Sadi Carnot, Aubervilliers',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_creteil',
      'name': 'Le Five Créteil',
      'lat': 48.7639,
      'lon': 2.4705,
      'address': '1 Rue Édouard Le Corbusier, Europarc, Créteil',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    // Le Five - Autres régions
    {
      'id': 'local_five_lyon',
      'name': 'Le Five Lyon Gerland',
      'lat': 45.7275,
      'lon': 4.8320,
      'address': 'Lyon',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_bordeaux',
      'name': 'Le Five Bordeaux',
      'lat': 44.8799,
      'lon': -0.5594,
      'address': '9-13 Rue Dumont d\'Urville, Bordeaux Lac',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_strasbourg',
      'name': 'Le Five Strasbourg',
      'lat': 48.5900,
      'lon': 7.6805,
      'address': 'Rue Émile Mathis, Eckbolsheim',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_nancy',
      'name': 'Le Five Nancy',
      'lat': 48.6453,
      'lon': 6.1890,
      'address': 'Avenue des Érables, Heillecourt',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_metz',
      'name': 'Le Five Metz',
      'lat': 49.0862,
      'lon': 6.1182,
      'address': 'ZAC de la Rotonde, Moulins-lès-Metz',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_reims',
      'name': 'Le Five Reims',
      'lat': 49.2691,
      'lon': 4.0380,
      'address': '11 Rue du Commerce, Zone du Port Sec, Reims',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_rouen',
      'name': 'Le Five Rouen',
      'lat': 49.4275,
      'lon': 1.1044,
      'address': '181 Quai du Cours la Reine, Rouen',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_roubaix',
      'name': 'Le Five Roubaix / Lille',
      'lat': 50.6919,
      'lon': 3.1632,
      'address': 'Rue de l\'Épeule, Roubaix',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_limoges',
      'name': 'Le Five Limoges',
      'lat': 45.8708,
      'lon': 1.2626,
      'address': '16 Rue de Buxerolles, Limoges',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_orleans',
      'name': 'Le Five Orléans',
      'lat': 47.9414,
      'lon': 1.9360,
      'address': '113 Rue de Curembourg, Fleury-les-Aubrais',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_tours',
      'name': 'Le Five Tours',
      'lat': 47.3540,
      'lon': 0.6753,
      'address': 'Rue de Tailhar, Joué-lès-Tours',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_lunel',
      'name': 'Le Five Lunel / Montpellier',
      'lat': 43.6896,
      'lon': 4.1578,
      'address': 'Chemin du Pont de Lunel',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_mulhouse',
      'name': 'Le Five Mulhouse',
      'lat': 47.7958,
      'lon': 7.3048,
      'address': 'Cité Fernand Anna, Wittenheim',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_saint_louis',
      'name': 'Le Five Saint-Louis (Bâle)',
      'lat': 47.6021,
      'lon': 7.5447,
      'address': '160 Rue de Mulhouse, Saint-Louis',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_vitre',
      'name': 'Le Five Vitré',
      'lat': 48.1228,
      'lon': -1.2125,
      'address': 'Promenade Saint-Yves, Vitré',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_ville_la_grand',
      'name': 'Le Five Ville-la-Grand (Genève)',
      'lat': 46.2064,
      'lon': 6.2805,
      'address': '16 Rue de Deux Montagnes, Ville-la-Grand',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_five_reunion',
      'name': 'Le Five Saint-Pierre (La Réunion)',
      'lat': -21.3431,
      'lon': 55.4747,
      'address': '8 Rue François de Mahy, Saint-Pierre',
      'website': 'https://www.lefive.fr',
      'type': 'fiveSide',
    },
    // CR5
    {
      'id': 'local_cr5_villepinte',
      'name': 'CR5 Villepinte',
      'lat': 48.9567,
      'lon': 2.5456,
      'address': 'Villepinte',
      'website': 'https://www.cr5.fr',
      'type': 'fiveSide',
    },
    {
      'id': 'local_cr5_ormoy',
      'name': 'CR5 Ormoy',
      'lat': 48.5752,
      'lon': 2.4494,
      'address': 'Ormoy, 91540 Essonne',
      'website': 'https://www.cr5.fr',
      'type': 'fiveSide',
    },
    // Soccer Park
    {
      'id': 'local_sp_lieusaint',
      'name': 'Soccer Park Lieusaint',
      'lat': 48.6284,
      'lon': 2.5483,
      'address': 'Lieusaint',
      'website': 'https://www.soccerpark.fr',
      'type': 'fiveSide',
    },
    // Foot Indoor
    {
      'id': 'local_fi_marseille',
      'name': 'Foot Indoor Marseille',
      'lat': 43.3126,
      'lon': 5.3691,
      'address': 'Marseille',
      'type': 'fiveSide',
    },
  ];

  /// Vérifie et demande les permissions de localisation
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Vérifier si le service de localisation est activé
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied');
      return false;
    }

    return true;
  }

  /// Obtient la position actuelle de l'utilisateur
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// Recherche les terrains de foot à proximité
  /// Utilise Foursquare API en priorité, puis fallback sur la base locale
  /// [lat] et [lon] sont les coordonnées du centre de recherche
  /// [radiusMeters] est le rayon de recherche en mètres (défaut: 5000m = 5km)
  Future<List<SoccerField>> searchNearbyFields({
    required double lat,
    required double lon,
    int radiusMeters = 5000,
  }) async {
    final fields = <SoccerField>[];

    // 1. Essayer Foursquare API si la clé est configurée
    if (_foursquareApiKey != 'YOUR_FOURSQUARE_API_KEY') {
      final foursquareFields = await _searchFoursquare(lat, lon, radiusMeters);
      fields.addAll(foursquareFields);
      debugPrint('✅ Found ${foursquareFields.length} fields from Foursquare');
    } else {
      debugPrint(
        '⚠️ Foursquare API key not configured, using local database only',
      );
    }

    // 2. Ajouter les centres de la base locale
    final localFields = _getLocalFieldsInRadius(lat, lon, radiusMeters, fields);
    fields.addAll(localFields);
    debugPrint('📍 Added ${localFields.length} fields from local database');

    // 3. Trier par distance
    fields.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    debugPrint('✅ Total: ${fields.length} soccer fields found');

    return fields;
  }

  /// Recherche via Foursquare Places API
  Future<List<SoccerField>> _searchFoursquare(
    double lat,
    double lon,
    int radiusMeters,
  ) async {
    final fields = <SoccerField>[];

    try {
      // Recherche par catégorie (Sports)
      final categoryUrl = Uri.parse(
        'https://api.foursquare.com/v3/places/search'
        '?ll=$lat,$lon'
        '&radius=$radiusMeters'
        '&categories=${_soccerCategories.join(",")}'
        '&limit=50'
        '&fields=fsq_id,name,geocodes,location,categories,tel,website,hours',
      );

      // Recherche par mot-clé (foot, soccer, five)
      final queryUrl = Uri.parse(
        'https://api.foursquare.com/v3/places/search'
        '?ll=$lat,$lon'
        '&radius=$radiusMeters'
        '&query=foot soccer five futsal'
        '&limit=50'
        '&fields=fsq_id,name,geocodes,location,categories,tel,website,hours',
      );

      final headers = {
        'Authorization': _foursquareApiKey,
        'Accept': 'application/json',
      };

      // Exécuter les deux requêtes en parallèle
      final responses = await Future.wait([
        http
            .get(categoryUrl, headers: headers)
            .timeout(const Duration(seconds: 10)),
        http
            .get(queryUrl, headers: headers)
            .timeout(const Duration(seconds: 10)),
      ]);

      final seenIds = <String>{};

      for (final response in responses) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List<dynamic>? ?? [];

          for (final place in results) {
            final fsqId = place['fsq_id'] as String;
            if (seenIds.contains(fsqId)) continue;
            seenIds.add(fsqId);

            final name = place['name'] as String? ?? '';

            // Filtrer pour garder uniquement les terrains de foot
            if (!_isSoccerRelated(name, place)) continue;

            final geocodes = place['geocodes']?['main'];
            if (geocodes == null) continue;

            final fieldLat = geocodes['latitude']?.toDouble();
            final fieldLon = geocodes['longitude']?.toDouble();
            if (fieldLat == null || fieldLon == null) continue;

            final location = place['location'] as Map<String, dynamic>?;
            final distance = Geolocator.distanceBetween(
              lat,
              lon,
              fieldLat,
              fieldLon,
            );

            fields.add(
              SoccerField(
                id: 'fsq_$fsqId',
                name: name,
                address: _buildFoursquareAddress(location),
                latitude: fieldLat,
                longitude: fieldLon,
                distanceMeters: distance,
                type: _determineFoursquareFieldType(name, place),
                phone: place['tel'] as String?,
                website: place['website'] as String?,
                openingHours: _parseFoursquareHours(place['hours']),
                operator: null,
                surface: null,
                isIndoor: _isIndoorFromName(name),
                isFiveSide: _isFiveSideFromName(name),
              ),
            );
          }
        } else {
          debugPrint('❌ Foursquare API error: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('❌ Foursquare search error: $e');
    }

    return fields;
  }

  /// Vérifie si le lieu est lié au football
  bool _isSoccerRelated(String name, Map<String, dynamic> place) {
    final nameLower = name.toLowerCase();

    // Mots-clés positifs
    final soccerKeywords = [
      'soccer',
      'foot',
      'futsal',
      'five',
      'terrain',
      'urban soccer',
      'le five',
      'b14',
      'cr5',
      'soccer park',
      'goal arena',
      'city foot',
      'foot indoor',
    ];

    for (final keyword in soccerKeywords) {
      if (nameLower.contains(keyword)) return true;
    }

    // Vérifier les catégories
    final categories = place['categories'] as List<dynamic>? ?? [];
    for (final cat in categories) {
      final catName = (cat['name'] as String? ?? '').toLowerCase();
      if (catName.contains('soccer') ||
          catName.contains('football') ||
          catName.contains('athletic')) {
        return true;
      }
    }

    return false;
  }

  /// Construit l'adresse depuis les données Foursquare
  String? _buildFoursquareAddress(Map<String, dynamic>? location) {
    if (location == null) return null;

    final parts = <String>[];
    if (location['address'] != null) parts.add(location['address'] as String);
    if (location['postcode'] != null) parts.add(location['postcode'] as String);
    if (location['locality'] != null) parts.add(location['locality'] as String);

    return parts.isNotEmpty ? parts.join(', ') : null;
  }

  /// Détermine le type de terrain depuis Foursquare
  FieldType _determineFoursquareFieldType(
    String name,
    Map<String, dynamic> place,
  ) {
    final nameLower = name.toLowerCase();

    if (nameLower.contains('urban soccer') ||
        nameLower.contains('le five') ||
        nameLower.contains('b14') ||
        nameLower.contains('cr5') ||
        nameLower.contains('soccer park') ||
        nameLower.contains('five') ||
        nameLower.contains('futsal')) {
      return FieldType.fiveSide;
    }

    if (nameLower.contains('stade')) return FieldType.stadium;
    if (nameLower.contains('centre') || nameLower.contains('complexe')) {
      return FieldType.sportsCentre;
    }

    return FieldType.pitch;
  }

  /// Parse les heures d'ouverture Foursquare
  String? _parseFoursquareHours(dynamic hours) {
    if (hours == null) return null;
    try {
      final display = hours['display'] as String?;
      return display;
    } catch (e) {
      return null;
    }
  }

  /// Vérifie si c'est un terrain indoor depuis le nom
  bool _isIndoorFromName(String name) {
    final nameLower = name.toLowerCase();
    return nameLower.contains('indoor') ||
        nameLower.contains('couvert') ||
        nameLower.contains('urban soccer') ||
        nameLower.contains('le five') ||
        nameLower.contains('b14');
  }

  /// Vérifie si c'est un foot à 5 depuis le nom
  bool _isFiveSideFromName(String name) {
    final nameLower = name.toLowerCase();
    return nameLower.contains('five') ||
        nameLower.contains('5') ||
        nameLower.contains('futsal') ||
        nameLower.contains('urban soccer') ||
        nameLower.contains('le five') ||
        nameLower.contains('b14') ||
        nameLower.contains('cr5') ||
        nameLower.contains('soccer park');
  }

  /// Récupère les centres de la base locale dans le rayon de recherche
  List<SoccerField> _getLocalFieldsInRadius(
    double lat,
    double lon,
    int radiusMeters,
    List<SoccerField> existingFields,
  ) {
    final localFields = <SoccerField>[];
    final existingNames = existingFields
        .map((f) => f.name.toLowerCase())
        .toSet();

    for (final center in _knownCenters) {
      final centerLat = center['lat'] as double;
      final centerLon = center['lon'] as double;

      final distance = Geolocator.distanceBetween(
        lat,
        lon,
        centerLat,
        centerLon,
      );

      // Vérifier si dans le rayon
      if (distance <= radiusMeters) {
        // Éviter les doublons (si déjà trouvé par l'API)
        final centerName = (center['name'] as String).toLowerCase();
        if (existingNames.any(
          (name) => name.contains(centerName) || centerName.contains(name),
        )) {
          debugPrint('⏭️ Skipping duplicate: ${center['name']}');
          continue;
        }

        debugPrint(
          '📍 Adding from local DB: ${center['name']} (${(distance / 1000).toStringAsFixed(1)}km)',
        );

        localFields.add(
          SoccerField(
            id: center['id'] as String,
            name: center['name'] as String,
            address: center['address'] as String?,
            latitude: centerLat,
            longitude: centerLon,
            distanceMeters: distance,
            type: FieldType.fiveSide,
            phone: center['phone'] as String?,
            website: center['website'] as String?,
            openingHours: null,
            operator: null,
            surface: 'synthetic',
            isIndoor: true,
            isFiveSide: true,
          ),
        );
      }
    }

    return localFields;
  }
}

/// Type de terrain
enum FieldType {
  pitch, // Terrain simple
  fiveSide, // Terrain de foot à 5
  sportsCentre, // Centre sportif
  stadium, // Stade
}

extension FieldTypeExtension on FieldType {
  String get displayName {
    switch (this) {
      case FieldType.pitch:
        return 'Terrain';
      case FieldType.fiveSide:
        return 'Foot à 5';
      case FieldType.sportsCentre:
        return 'Centre sportif';
      case FieldType.stadium:
        return 'Stade';
    }
  }

  String get icon {
    switch (this) {
      case FieldType.pitch:
        return '⚽';
      case FieldType.fiveSide:
        return '🥅';
      case FieldType.sportsCentre:
        return '🏟️';
      case FieldType.stadium:
        return '🏟️';
    }
  }
}

/// Modèle représentant un terrain de foot
class SoccerField {
  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final FieldType type;
  final String? phone;
  final String? website;
  final String? openingHours;
  final String? operator;
  final String? surface;
  final bool isIndoor;
  final bool isFiveSide;

  SoccerField({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.type,
    this.phone,
    this.website,
    this.openingHours,
    this.operator,
    this.surface,
    this.isIndoor = false,
    this.isFiveSide = false,
  });

  /// Distance formatée (ex: "1.2 km" ou "850 m")
  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  /// Surface formatée
  String? get formattedSurface {
    if (surface == null) return null;
    switch (surface) {
      case 'grass':
        return 'Pelouse naturelle';
      case 'artificial_turf':
        return 'Pelouse synthétique';
      case 'concrete':
        return 'Béton';
      case 'asphalt':
        return 'Asphalte';
      case 'tartan':
        return 'Tartan';
      default:
        return surface;
    }
  }
}
