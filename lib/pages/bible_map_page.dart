// lib/pages/bible_map_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:septima_biblia/utils/polygon_contains.dart'; // Import the new utility file

// Modelo de dados (sem alterações)
class MapPlace {
  final String name;
  final String type;
  final String style;
  final List<LatLng> coordinates;
  final List<int> verses;

  MapPlace({
    required this.name,
    required this.type,
    required this.style,
    required this.coordinates,
    required this.verses,
  });

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
    );
  }
}

class BibleMapPage extends StatefulWidget {
  final String chapterId;
  final String chapterTitle;

  const BibleMapPage({
    super.key,
    required this.chapterId,
    required this.chapterTitle,
  });

  @override
  State<BibleMapPage> createState() => _BibleMapPageState();
}

class _BibleMapPageState extends State<BibleMapPage> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<List<MapPlace>?> _mapDataFuture;
  final MapController _mapController = MapController();

  Set<String> _activeFilters = {'point', 'polygon', 'linestring'};
  int? _selectedVerse;
  bool _showLegend = true;

  @override
  void initState() {
    super.initState();
    _mapDataFuture = _loadMapData();
  }

  Future<List<MapPlace>?> _loadMapData() async {
    final rawData = await _firestoreService.getChapterMapData(widget.chapterId);
    if (rawData == null) return null;
    return rawData
        .map((placeData) => MapPlace.fromFirestore(placeData))
        .toList();
  }

  // --- Funções de Construção ---

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

  // <<< INÍCIO DA CORREÇÃO >>>
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
        // O parâmetro 'isTapable' foi removido.
      );
    }).toList();
  }
  // <<< FIM DA CORREÇÃO >>>

  List<Polyline> _buildPolylines(List<MapPlace> places) {
    return places
        .where((p) =>
            p.type == 'linestring' &&
            p.coordinates.length > 1 &&
            _activeFilters.contains('linestring') &&
            (_selectedVerse == null || p.verses.contains(_selectedVerse)))
        .map((place) {
      return Polyline(
        points: place.coordinates,
        color: _getColorForStyle(place.style),
        strokeWidth: 3,
      );
    }).toList();
  }

  // O resto do arquivo permanece o mesmo...

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
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text("Mencionada nos versículos: ${place.verses.join(', ')}"),
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
    if (place.type == 'point') {
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
        title: Text("Mapa: ${widget.chapterTitle}"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showLegend = !_showLegend;
          });
        },
        tooltip: _showLegend ? "Esconder Legenda" : "Mostrar Legenda",
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: Icon(
            _showLegend
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            key: ValueKey<bool>(_showLegend),
          ),
        ),
      ),
      body: FutureBuilder<List<MapPlace>?>(
        future: _mapDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child:
                    Text("Erro ao carregar dados do mapa: ${snapshot.error}"));
          }
          if (!snapshot.hasData ||
              snapshot.data == null ||
              snapshot.data!.isEmpty) {
            return const Center(
                child: Text(
                    "Nenhum dado geográfico encontrado para este capítulo."));
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
                  // <<< INÍCIO DA CORREÇÃO >>>
                  onTap: (tapPosition, point) {
                    // Itera sobre os polígonos visíveis (começando pelo que está no topo)
                    for (var p in polygons.reversed) {
                      // Verifica se o ponto do toque está dentro do polígono
                      if (PolygonUtil.contains(point, p.points)) {
                        final placeData = places.firstWhere(
                            (place) => place.coordinates == p.points,
                            orElse: () =>
                                places.first // Fallback, shouldn't happen
                            );
                        _showPlaceDetails(context, placeData);
                        break; // Para no primeiro polígono que encontrar
                      }
                    }
                  },
                  // <<< FIM DA CORREÇÃO >>>
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
            if (sortedVerses.length > 1) _buildVerseFilter(sortedVerses, theme),
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
                    subtitle: Text("V: ${place.verses.join(', ')}",
                        style: theme.textTheme.bodySmall),
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
                onSelected: (selected) {
                  setState(() {
                    _selectedVerse = null;
                  });
                },
              ),
            );
          }
          final verseNum = verses[index - 1];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text("V. $verseNum"),
              selected: _selectedVerse == verseNum,
              onSelected: (selected) {
                setState(() {
                  _selectedVerse = selected ? verseNum : null;
                });
              },
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

// <<< INÍCIO DA CORREÇÃO: ARQUIVO SEPARADO PARA A LÓGICA DE DETECÇÃO DE PONTO >>>
// Crie um novo arquivo em `lib/utils/polygon_contains.dart` e cole este código.

class PolygonUtil {
  // Converte um objeto LatLng para um Point simples para cálculo.
  static _Point _latLngToPoint(_Point p) => _Point(p.x, p.y);

  /// Verifica se um ponto [p] está dentro de um polígono [polygon].
  static bool contains(LatLng p, List<LatLng> polygon) {
    if (polygon.isEmpty) {
      return false;
    }

    // Converte a lista de LatLng para uma lista de _Point
    final List<_Point> points =
        polygon.map((e) => _Point(e.latitude, e.longitude)).toList();
    final _Point point = _Point(p.latitude, p.longitude);

    int i, j = polygon.length - 1;
    bool c = false;
    for (i = 0; i < polygon.length; j = i++) {
      if (((points[i].y > point.y) != (points[j].y > point.y)) &&
          (point.x <
              (points[j].x - points[i].x) *
                      (point.y - points[i].y) /
                      (points[j].y - points[i].y) +
                  points[i].x)) {
        c = !c;
      }
    }
    return c;
  }
}

// Classe auxiliar para os cálculos matemáticos.
class _Point {
  final double x;
  final double y;
  const _Point(this.x, this.y);
}
// <<< FIM DA CORREÇÃO >>>