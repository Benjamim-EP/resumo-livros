// lib/pages/bible_map_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:septima_biblia/models/themed_map_model.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:septima_biblia/utils/polygon_contains.dart';

// Modelo de dados unificado para qualquer item geográfico na página do mapa
class MapPlace {
  final String name;
  final String type;
  final String style;
  final List<LatLng> coordinates;
  final List<int> verses;
  final int confidence;
  final String? description;

  MapPlace({
    required this.name,
    required this.type,
    required this.style,
    required this.coordinates,
    required this.verses,
    required this.confidence,
    this.description,
  });

  // Construtor para dados vindos do Firestore (mapas por capítulo)
  factory MapPlace.fromFirestore(Map<String, dynamic> data) {
    final coordsList = (data['coordinates'] as List<dynamic>? ?? [])
        .map((coordMap) => LatLng(
              (coordMap['lat'] as num).toDouble(),
              (coordMap['lon'] as num).toDouble(),
            ))
        .toList();

    return MapPlace(
      name: data['name'] ?? 'Local Desconhecido',
      type: data['type'] ?? 'point',
      style: data['style'] ?? '',
      coordinates: coordsList,
      verses: (data['verses'] as List<dynamic>? ?? []).cast<int>().toList(),
      confidence: data['confidence'] as int? ?? 100,
      description: null, // Descrições vêm de mapas temáticos
    );
  }

  // Construtor para dados vindos de um mapa temático (viagens)
  factory MapPlace.fromJourneyLocation(JourneyLocation loc) {
    return MapPlace(
      name: loc.name,
      type: 'point', // Locais de viagem são sempre pontos
      style: 'path', // Estilo padrão para rotas
      coordinates: [loc.point],
      verses: [], // Rotas não são filtradas por versículo
      confidence: 100,
      description: loc.description,
    );
  }
}

class BibleMapPage extends StatefulWidget {
  final String? chapterId;
  final String? chapterTitle;
  final ThemedJourney? themedJourney;

  const BibleMapPage({
    super.key,
    this.chapterId,
    this.chapterTitle,
    this.themedJourney,
  }) : assert(chapterId != null || themedJourney != null,
            "É necessário fornecer um chapterId ou uma themedJourney.");

  @override
  State<BibleMapPage> createState() => _BibleMapPageState();
}

class _BibleMapPageState extends State<BibleMapPage> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<List<MapPlace>> _mapDataFuture;
  final MapController _mapController = MapController();

  Set<String> _activeFilters = {'point', 'polygon', 'linestring'};
  int? _selectedVerse;
  bool _showLegend = true;

  @override
  void initState() {
    super.initState();
    _mapDataFuture = _loadMapData();
  }

  Future<List<MapPlace>> _loadMapData() async {
    if (widget.themedJourney != null) {
      return widget.themedJourney!.locations
          .map((loc) => MapPlace.fromJourneyLocation(loc))
          .toList();
    } else {
      final rawData =
          await _firestoreService.getChapterMapData(widget.chapterId!);
      if (rawData == null) return [];
      return rawData.map((data) => MapPlace.fromFirestore(data)).toList();
    }
  }

  List<Marker> _buildMarkers(List<MapPlace> places) {
    return places
        .where((p) =>
            p.type == 'point' &&
            _activeFilters.contains('point') &&
            (_selectedVerse == null || p.verses.contains(_selectedVerse)))
        .map((place) {
      return Marker(
        width: 40.0,
        height: 40.0,
        point: place.coordinates.first,
        child: IconButton(
          icon: Icon(_getIconForStyle(place.style),
              color: _getColorForStyle(place.style),
              size: 30,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black54)]),
          onPressed: () => _showPlaceDetails(context, place),
        ),
      );
    }).toList();
  }

  List<Polygon> _buildPolygons(List<MapPlace> places) {
    return places
        .where((p) =>
            p.type == 'polygon' &&
            p.coordinates.length > 2 &&
            _activeFilters.contains('polygon') &&
            (_selectedVerse == null || p.verses.contains(_selectedVerse)))
        .map((place) {
      return Polygon(
        points: place.coordinates,
        color: _getColorForStyle(place.style).withOpacity(0.3),
        borderColor: _getColorForStyle(place.style),
        borderStrokeWidth: 2,
        isFilled: true,
      );
    }).toList();
  }

  List<Polyline> _buildPolylines(List<MapPlace> places) {
    // --- CENÁRIO 1: É UM MAPA TEMÁTICO (VIAGEM) ---
    if (widget.themedJourney != null) {
      // Sua lógica correta para a v7
      StrokePattern pattern;

      switch (widget.themedJourney!.style) {
        case 'dotted':
          pattern = const StrokePattern.dotted(spacingFactor: 2.0);
          break;
        case 'dashed':
          pattern = StrokePattern.dashed(segments: [12.0, 8.0]);
          break;
        default:
          pattern = const StrokePattern.solid();
      }

      return [
        Polyline(
          points: places.map((p) => p.coordinates.first).toList(),
          color: widget.themedJourney!.color,
          strokeWidth: 4,
          pattern: pattern,
        ),
      ];
    }

    // --- CENÁRIO 2: É UM MAPA DE CAPÍTULO (LÓGICA ORIGINAL RESTAURADA) ---
    // Se não for um mapa temático, executa a lógica de filtrar e desenhar
    // as linhas individuais do capítulo (rios, estradas, etc.).
    return places
        .where((p) =>
            p.type == 'linestring' &&
            p.coordinates.length > 1 &&
            _activeFilters.contains('linestring') &&
            (_selectedVerse == null || p.verses.contains(_selectedVerse)))
        .map((place) {
      // As linhas de capítulo serão sempre sólidas por padrão.
      return Polyline(
        points: place.coordinates,
        color: _getColorForStyle(place.style),
        strokeWidth: 3,
      );
    }).toList();
  }

  Color _getColorForStyle(String style) {
    if (style.contains('water')) return Colors.blue.shade700;
    if (style.contains('land')) return Colors.red.shade700;
    if (style.contains('path')) return Colors.brown.shade600;
    if (style.contains('region')) return Colors.green.shade800;
    return Colors.purple;
  }

  IconData _getIconForStyle(String style) {
    if (style.contains('water')) return Icons.water_drop;
    return Icons.location_on;
  }

  void _showPlaceDetails(BuildContext context, MapPlace place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            if (place.description != null && place.description!.isNotEmpty)
              Text(place.description!,
                  style: Theme.of(context).textTheme.bodyLarge),
            if (place.verses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                    "Mencionada nos versículos: ${place.verses.join(', ')}",
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  LatLngBounds _calculateBounds(List<MapPlace> places) {
    if (places.isEmpty || places.every((p) => p.coordinates.isEmpty)) {
      return LatLngBounds(LatLng(51.5, -0.09), LatLng(51.5, -0.09));
    }
    final firstValidCoord =
        places.firstWhere((p) => p.coordinates.isNotEmpty).coordinates.first;
    final bounds = LatLngBounds(firstValidCoord, firstValidCoord);
    for (var place in places) {
      for (var coord in place.coordinates) {
        bounds.extend(coord);
      }
    }
    return bounds;
  }

  void _moveToLocation(MapPlace place) {
    if (place.coordinates.isEmpty) return;
    if (place.type == 'point' || place.type == 'linestring') {
      _mapController.move(place.coordinates.first, 10.0);
    } else {
      final bounds = _calculateBounds([place]);
      _mapController.fitCamera(CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50.0),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.themedJourney?.title ?? "Mapa: ${widget.chapterTitle}"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _showLegend = !_showLegend),
        tooltip: _showLegend ? "Esconder Legenda" : "Mostrar Legenda",
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            _showLegend
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            key: ValueKey<bool>(_showLegend),
          ),
        ),
      ),
      body: FutureBuilder<List<MapPlace>>(
        future: _mapDataFuture.then((value) => value ?? []),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child:
                    Text("Erro ao carregar dados do mapa: ${snapshot.error}"));
          }
          if (snapshot.data!.isEmpty) {
            return const Center(
                child: Text("Nenhum dado geográfico encontrado."));
          }

          final places = snapshot.data!;
          final markers = _buildMarkers(places);
          final polygons = _buildPolygons(places);
          final polylines = _buildPolylines(places);
          final bounds = _calculateBounds(places);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(50.0),
                  ),
                  onTap: (tapPosition, point) {
                    final polygonsToTest = _buildPolygons(
                        places); // Pega os polígonos atualmente visíveis
                    for (var p in polygonsToTest.reversed) {
                      if (PolygonUtil.contains(point, p.points)) {
                        final placeData = places.firstWhere(
                            (place) => place.coordinates == p.points);
                        _showPlaceDetails(context, placeData);
                        break;
                      }
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.septima.septimabiblia',
                  ),
                  if (polygons.isNotEmpty)
                    PolygonLayer(polygons: polygons, polygonCulling: true),
                  if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                  if (markers.isNotEmpty) MarkerLayer(markers: markers),
                ],
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                bottom: _showLegend ? 80 : -400,
                left: 10,
                right: 10,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _showLegend ? 1.0 : 0.0,
                  child: _buildLegendWidget(places),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegendWidget(List<MapPlace> allPlaces) {
    final theme = Theme.of(context);
    final filteredPlaces = allPlaces.where((place) {
      return _activeFilters.contains(place.type) &&
          (_selectedVerse == null || place.verses.contains(_selectedVerse));
    }).toList();

    final hasPoints = allPlaces.any((p) => p.type == 'point');
    final hasPolygons = allPlaces.any((p) => p.type == 'polygon');
    final hasLinestrings = allPlaces.any((p) => p.type == 'linestring');

    final Set<int> uniqueVerses = {};
    for (var place in allPlaces) {
      uniqueVerses.addAll(place.verses);
    }
    final List<int> sortedVerses = uniqueVerses.toList()..sort();

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.chapterId !=
                null) // Só mostra filtros se for mapa de capítulo
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasPoints)
                        _buildFilterChip('point', Icons.location_on, "Locais"),
                      if (hasPolygons) const SizedBox(width: 8),
                      if (hasPolygons)
                        _buildFilterChip('polygon', Icons.layers, "Áreas"),
                      if (hasLinestrings) const SizedBox(width: 8),
                      if (hasLinestrings)
                        _buildFilterChip(
                            'linestring', Icons.timeline, "Rios/Rotas"),
                    ],
                  ),
                ),
              ),
            if (widget.chapterId != null && sortedVerses.length > 1)
              _buildVerseFilter(sortedVerses, theme),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredPlaces.length,
                itemBuilder: (context, index) {
                  final place = filteredPlaces[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(_getIconForStyle(place.style),
                        color: _getColorForStyle(place.style), size: 20),
                    title: Text(place.name,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: place.verses.isNotEmpty
                        ? Text("V: ${place.verses.join(', ')}",
                            style: theme.textTheme.bodySmall)
                        : null,
                    onTap: () => _moveToLocation(place),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ).animate(target: _showLegend ? 1 : 0).fade(begin: 0).slideY(begin: 0.2);
  }

  Widget _buildVerseFilter(List<int> verses, ThemeData theme) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: verses.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChip(
                label: const Text("Todos"),
                selected: _selectedVerse == null,
                onSelected: (selected) => setState(() => _selectedVerse = null),
              ),
            );
          }
          final verseNum = verses[index - 1];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text("V. $verseNum"),
              selected: _selectedVerse == verseNum,
              onSelected: (selected) =>
                  setState(() => _selectedVerse = selected ? verseNum : null),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String typeKey, IconData icon, String label) {
    final isSelected = _activeFilters.contains(typeKey);
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon,
          size: 16,
          color: isSelected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          if (selected) {
            _activeFilters.add(typeKey);
          } else {
            _activeFilters.remove(typeKey);
          }
        });
      },
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      labelStyle: TextStyle(
          fontSize: 12,
          color: isSelected
              ? theme.colorScheme.onPrimary
              : theme.textTheme.bodyLarge?.color),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      showCheckmark: true,
      selectedShadowColor: theme.colorScheme.primary.withOpacity(0.5),
    );
  }
}
