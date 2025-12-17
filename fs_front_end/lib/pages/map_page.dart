import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme_config/colors_config.dart';
import '../providers/fields_provider.dart';
import '../services/fields_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  SoccerField? _selectedField;
  bool _showList = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FieldsProvider>().initialize();
    });
  }

  void _centerOnUserLocation() {
    final provider = context.read<FieldsProvider>();
    if (provider.currentPosition != null) {
      _mapController.move(
        LatLng(
          provider.currentPosition!.latitude,
          provider.currentPosition!.longitude,
        ),
        14.0,
      );
    }
  }

  void _selectField(SoccerField field) {
    setState(() {
      _selectedField = field;
    });
    _mapController.move(LatLng(field.latitude, field.longitude), 16.0);
  }

  Future<void> _openInMaps(SoccerField field) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${field.latitude},${field.longitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _openWebsite(String website) async {
    var url = website;
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDarkMode ? myLightBackground : MyprimaryDark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Terrains à Proximité',
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Bouton pour basculer carte/liste
          IconButton(
            icon: Icon(
              _showList ? Icons.map : Icons.list,
              color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
            ),
            onPressed: () {
              setState(() {
                _showList = !_showList;
              });
            },
            tooltip: _showList ? 'Afficher la carte' : 'Afficher la liste',
          ),
          // Bouton filtre
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
            ),
            onPressed: () => _showFilterSheet(context),
            tooltip: 'Filtres',
          ),
        ],
      ),
      body: Consumer<FieldsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.fields.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Recherche des terrains...'),
                ],
              ),
            );
          }

          if (provider.error != null && provider.fields.isEmpty) {
            return _buildErrorView(provider, isDarkMode);
          }

          if (_showList) {
            return _buildListView(provider, isDarkMode);
          }

          return _buildMapView(provider, isDarkMode);
        },
      ),
      floatingActionButton: Consumer<FieldsProvider>(
        builder: (context, provider, _) {
          if (_showList || provider.currentPosition == null) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: _centerOnUserLocation,
            backgroundColor: myAccentVibrantBlue,
            child: const Icon(Icons.my_location, color: MyprimaryDark),
          );
        },
      ),
    );
  }

  Widget _buildErrorView(FieldsProvider provider, bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 80,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.initialize(),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: myAccentVibrantBlue,
                foregroundColor: MyprimaryDark,
              ),
            ),
            if (!provider.hasLocationPermission) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  // Ouvrir les paramètres de l'app
                  await launchUrl(
                    Uri.parse('app-settings:'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text('Ouvrir les paramètres'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(FieldsProvider provider, bool isDarkMode) {
    // Position par défaut : Paris
    final defaultCenter = LatLng(48.8566, 2.3522);
    final center = provider.currentPosition != null
        ? LatLng(
            provider.currentPosition!.latitude,
            provider.currentPosition!.longitude,
          )
        : defaultCenter;

    return Stack(
      children: [
        // Carte
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.0,
            onTap: (_, __) {
              setState(() {
                _selectedField = null;
              });
            },
          ),
          children: [
            // Tuiles de la carte (OpenStreetMap)
            TileLayer(
              urlTemplate: isDarkMode
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: isDarkMode ? ['a', 'b', 'c', 'd'] : [],
              userAgentPackageName: 'com.fivestar.app',
            ),
            // Marqueur de position utilisateur
            if (provider.currentPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      provider.currentPosition!.latitude,
                      provider.currentPosition!.longitude,
                    ),
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: myAccentVibrantBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        color: MyprimaryDark,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            // Marqueurs des terrains
            MarkerLayer(
              markers: provider.fields.map((field) {
                final isSelected = _selectedField?.id == field.id;
                return Marker(
                  point: LatLng(field.latitude, field.longitude),
                  width: isSelected ? 50 : 40,
                  height: isSelected ? 50 : 40,
                  child: GestureDetector(
                    onTap: () => _selectField(field),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? myAccentVibrantBlue
                            : (field.isFiveSide ? Colors.green : Colors.orange),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: isSelected ? 4 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: isSelected ? 10 : 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.sports_soccer,
                        color: Colors.white,
                        size: isSelected ? 28 : 22,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Indicateur de chargement
        if (provider.isLoading)
          const Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Recherche...'),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Compteur de terrains
        Positioned(
          top: 16,
          left: 16,
          child: Card(
            color: isDarkMode
                ? MyprimaryDark.withOpacity(0.9)
                : Colors.white.withOpacity(0.9),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                '${provider.fields.length} terrain${provider.fields.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? myLightBackground : MyprimaryDark,
                ),
              ),
            ),
          ),
        ),

        // Carte du terrain sélectionné
        if (_selectedField != null)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: _buildFieldCard(_selectedField!, isDarkMode),
          ),
      ],
    );
  }

  Widget _buildFieldCard(SoccerField field, bool isDarkMode) {
    return Card(
      elevation: 8,
      color: isDarkMode ? MyprimaryDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: field.isFiveSide
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.sports_soccer,
                      color: field.isFiveSide ? Colors.green : Colors.orange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? myLightBackground
                                : MyprimaryDark,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              field.formattedDistance,
                              style: TextStyle(
                                color: myAccentVibrantBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (field.isIndoor) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Indoor',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedField = null;
                      });
                    },
                  ),
                ],
              ),

              // Infos supplémentaires
              if (field.address != null) ...[
                const SizedBox(height: 12),
                Text(
                  field.address!,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],

              if (field.formattedSurface != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.grass, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      field.formattedSurface!,
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],

              if (field.openingHours != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        field.openingHours!,
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Boutons d'action
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openInMaps(field),
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Itinéraire'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: myAccentVibrantBlue,
                        foregroundColor: MyprimaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (field.phone != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _callPhone(field.phone!),
                      icon: const Icon(Icons.phone),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.2),
                        foregroundColor: Colors.green,
                      ),
                    ),
                  ],
                  if (field.website != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _openWebsite(field.website!),
                      icon: const Icon(Icons.language),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListView(FieldsProvider provider, bool isDarkMode) {
    if (provider.fields.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_soccer,
              size: 80,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun terrain trouvé',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez d\'élargir le rayon de recherche',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: provider.fields.length + 1,
        itemBuilder: (context, index) {
          if (index == provider.fields.length) {
            return const SizedBox(height: 80); // Espace pour la navbar
          }

          final field = provider.fields[index];
          return _buildListItem(field, isDarkMode);
        },
      ),
    );
  }

  Widget _buildListItem(SoccerField field, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _showList = false;
            _selectedField = field;
          });
          _mapController.move(LatLng(field.latitude, field.longitude), 16.0);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: field.isFiveSide
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sports_soccer,
                  color: field.isFiveSide ? Colors.green : Colors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? myLightBackground : MyprimaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          field.formattedDistance,
                          style: TextStyle(
                            color: myAccentVibrantBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (field.isIndoor) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Indoor',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (field.isFiveSide) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Foot 5',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (field.address != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        field.address!,
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _openInMaps(field),
                icon: const Icon(Icons.directions),
                style: IconButton.styleFrom(
                  backgroundColor: myAccentVibrantBlue.withOpacity(0.2),
                  foregroundColor: myAccentVibrantBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final provider = context.read<FieldsProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? MyprimaryDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 20.0,
                  bottom: 20.0 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filtres',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? myLightBackground
                                : MyprimaryDark,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            provider.clearFilters();
                            setModalState(() {});
                          },
                          child: const Text('Réinitialiser'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Rayon de recherche
                    Text(
                      'Rayon de recherche: ${(provider.searchRadiusMeters / 1000).toStringAsFixed(0)} km',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? myLightBackground : MyprimaryDark,
                      ),
                    ),
                    Slider(
                      value: provider.searchRadiusMeters.toDouble(),
                      min: 5000,
                      max: 60000,
                      divisions: 11,
                      activeColor: myAccentVibrantBlue,
                      label:
                          '${(provider.searchRadiusMeters / 1000).toStringAsFixed(0)} km',
                      onChanged: (value) {
                        provider.setSearchRadius(value.toInt());
                        setModalState(() {});
                      },
                    ),

                    const SizedBox(height: 16),

                    // Filtres
                    SwitchListTile(
                      title: const Text('Foot à 5 uniquement'),
                      subtitle: const Text('Urban Soccer, Le Five, etc.'),
                      value: provider.showOnlyFiveSide,
                      activeColor: myAccentVibrantBlue,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        provider.toggleFiveSideFilter();
                        setModalState(() {});
                      },
                    ),

                    SwitchListTile(
                      title: const Text('Indoor uniquement'),
                      subtitle: const Text('Terrains couverts'),
                      value: provider.showOnlyIndoor,
                      activeColor: myAccentVibrantBlue,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        provider.toggleIndoorFilter();
                        setModalState(() {});
                      },
                    ),

                    const SizedBox(height: 20),

                    // Bouton appliquer
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: myAccentVibrantBlue,
                          foregroundColor: MyprimaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Appliquer'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
