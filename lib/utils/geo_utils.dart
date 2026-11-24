import 'dart:math' as math;

class GeoUtils {
  static const double radioTierraKm = 6371.0; // Radio medio de la Tierra en km

  /// Calcula la distancia ortodrómica en kilómetros usando la fórmula de Haversine
  static double calcularDistanciaHaversine(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    final double dLat = _gradosARadianes(lat2 - lat1);
    final double dLon = _gradosARadianes(lon2 - lon1);

    final double lat1Rad = _gradosARadianes(lat1);
    final double lat2Rad = _gradosARadianes(lat2);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
            math.sin(dLon / 2) * math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return radioTierraKm * c;
  }

  static double _gradosARadianes(double grados) {
    return grados * (math.pi / 180.0);
  }

  /// Formatea la distancia para la UI (ej. '850 m' o '2.4 km')
  static String formatearDistancia(double km) {
    if (km < 1.0) {
      final metros = (km * 1000).round();
      return '$metros m';
    } else {
      return '${km.toStringAsFixed(1)} km';
    }
  }
}