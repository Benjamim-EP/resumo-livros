// lib/pages/bible_map_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:septima_biblia/services/firestore_service.dart';

// Modelo de dados (sem alterações)
class MapPlace {
  final String name;
  final String type;
  final String style;
  final List<LatLng> coordinates;

  MapPlace({
    required this.name,
    required this.type,
    required this.style,
    required this.coordinates,
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

  @override
  void initState() {
    super.initState();
    _mapDataFuture = _loadMapData();
  }

  Future<List<MapPlace>?> _loadMapData() async {
    final rawData = await _firestoreService.getChapterMapData(widget.chapterId);
    if (rawData == null) {
      return null;
    }
    return rawData
        .map((placeData) => MapPlace.fromFirestore(placeData))
        .toList();
  }

  List<Marker> _buildMarkers(List<MapPlace> places) {
    return places
        .where((p) => p.type == 'point' && p.coordinates.isNotEmpty)
        .map((place) {
      return Marker(
        width: 40.0,
        height: 40.0,
        point: place.coordinates.first,
        child: IconButton(
          icon: Icon(
            _getIconForStyle(place.style),
            color: _getColorForStyle(place.style),
            size: 30,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
          onPressed: () => _showPlaceDetails(context, place),
        ),
      );
    }).toList();
  }

  List<Polygon> _buildPolygons(List<MapPlace> places) {
    return places
        .where((p) => p.type == 'polygon' && p.coordinates.length > 2)
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
    return places
        .where((p) => p.type == 'linestring' && p.coordinates.length > 1)
        .map((place) {
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
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // <<< INÍCIO DA CORREÇÃO >>>
  // Calcula os limites do mapa para dar zoom automático
  LatLngBounds _calculateBounds(List<MapPlace> places) {
    // Se não houver lugares, retorna um limite padrão (ex: ao redor de Londres)
    if (places.isEmpty || places.every((p) => p.coordinates.isEmpty)) {
      return LatLngBounds(LatLng(51.5, -0.09), LatLng(51.5, -0.09));
    }

    // Pega a primeira coordenada válida como ponto de partida
    final firstValidCoord =
        places.firstWhere((p) => p.coordinates.isNotEmpty).coordinates.first;
    final bounds = LatLngBounds(firstValidCoord, firstValidCoord);

    // Itera por todos os lugares e todas as coordenadas para estender os limites
    for (var place in places) {
      for (var coord in place.coordinates) {
        bounds.extend(coord);
      }
    }
    return bounds;
  }
  // <<< FIM DA CORREÇÃO >>>

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Mapa: ${widget.chapterTitle}"),
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

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(50.0),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.septima.septimabiblia',
              ),
              if (polygons.isNotEmpty)
                PolygonLayer(
                  polygons: polygons,
                  polygonCulling: true,
                ),
              if (polylines.isNotEmpty)
                PolylineLayer(
                  polylines: polylines,
                ),
              if (markers.isNotEmpty)
                MarkerLayer(
                  markers: markers,
                ),
            ],
          );
        },
      ),
    );
  }
}
