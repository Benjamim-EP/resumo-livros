// lib/utils/polygon_contains.dart
import 'package:latlong2/latlong.dart';

// Classe auxiliar interna para os cálculos matemáticos.
class _Point {
  final double x;
  final double y;
  const _Point(this.x, this.y);
}

class PolygonUtil {
  /// Verifica se um ponto [p] (LatLng) está dentro de um polígono [polygon] (List<LatLng>).
  /// Implementação do algoritmo Ray Casting.
  static bool contains(LatLng p, List<LatLng> polygon) {
    if (polygon.isEmpty) {
      return false;
    }

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
