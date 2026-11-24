import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import 'detalle_actividad_screen.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => MapaScreenState();
}

class MapaScreenState extends State<MapaScreen> {
  final MapController _mapController = MapController();
  List<dynamic> _actividades = [];
  bool _cargando = true;
  String? _error;

  LatLng? _miUbicacion;
  bool _obteniendoGps = false;
  final LatLng _centroInicial = const LatLng(-33.4489, -70.6693); // Santiago Centro por defecto

  // Nivel de zoom dinámico en tiempo real
  double _zoomActual = 13.0;

  @override
  void initState() {
    super.initState();
    cargarDatos();
    _determinarPosicionInicial();
  }

  // Selección de icono pixel art según el deporte de la actividad
  String _obtenerRutaIcono(String? deporte) {
    final dep = (deporte ?? '').toLowerCase().trim();

    if (dep.contains('fútbol') || dep.contains('futbol') || dep.contains('soccer')) {
      return 'assets/icons/marker_futbol.png';
    } else if (dep.contains('básquet') || dep.contains('basquet') || dep.contains('basket')) {
      return 'assets/icons/marker_basquet.png';
    } else if (dep.contains('tenis') || dep.contains('tennis')) {
      return 'assets/icons/marker_tenis.png';
    } else if (dep.contains('pádel') || dep.contains('padel')) {
      return 'assets/icons/marker_padel.png';
    } else if (dep.contains('voleibol') || dep.contains('voley') || dep.contains('vóley') || dep.contains('volleyball')) {
      return 'assets/icons/marker_voleibol.png';
    } else if (dep.contains('running') || dep.contains('correr') || dep.contains('trote')) {
      return 'assets/icons/marker_running.png';
    } else {
      return 'assets/icons/marker_default.png';
    }
  }

  // 1. Manejo de Permisos y lectura de GPS
  Future<void> _determinarPosicionInicial({bool centrarCamara = false}) async {
    setState(() => _obteniendoGps = true);
    try {
      bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        setState(() => _obteniendoGps = false);
        return;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) {
          setState(() => _obteniendoGps = false);
          return;
        }
      }

      if (permiso == LocationPermission.deniedForever) {
        setState(() => _obteniendoGps = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final nuevaUbicacion = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _miUbicacion = nuevaUbicacion;
          _obteniendoGps = false;
        });

        if (centrarCamara) {
          _mapController.move(nuevaUbicacion, 15.0);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _obteniendoGps = false);
    }
  }

  Future<void> cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final data = await ApiService.getActividades();

    if (!mounted) return;

    if (data.isNotEmpty || data is List) {
      setState(() {
        _actividades = data;
        _cargando = false;
      });
    } else {
      setState(() {
        _error = 'No se pudieron cargar las actividades.';
        _cargando = false;
      });
    }
  }

  void _mostrarDetalle(Map<String, dynamic> actividad) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titulo = actividad['titulo'] ?? actividad['nombre'] ?? 'Actividad';
    final descripcion = actividad['descripcion'] ?? 'Sin descripción adicional.';
    final deporte = actividad['deporte_display'] ?? actividad['deporte'] ?? 'Deporte';
    final cupos = actividad['cupos_disponibles'] ?? 0;
    final totalCupos = actividad['cupos_totales'] ?? 0;
    final direccion = actividad['direccion'] ?? actividad['ubicacion'] ?? 'Santiago';
    final comuna = actividad['comuna'] ?? '';
    final bool esPremium = actividad['organizador_es_premium'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (esPremium) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.amber, Colors.deepOrange],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'ORGANIZADOR VIP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Chip(
                        label: Text(
                          deporte,
                          style: TextStyle(
                            color: Colors.deepOrange.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: Colors.deepOrange.shade100,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place, size: 18, color: Colors.deepOrange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      comuna.isNotEmpty ? '$direccion, $comuna' : direccion,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                descripcion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.group, size: 20, color: Colors.deepOrange),
                  const SizedBox(width: 6),
                  Text(
                    'Cupos disponibles: $cupos / $totalCupos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cupos > 0 ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetalleActividadScreen(actividad: actividad),
                      ),
                    );
                    cargarDatos();
                  },
                  icon: const Icon(Icons.sports_handball),
                  label: const Text('Ver Detalle e Inscribirme'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: cargarDatos,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final List<Marker> marcadores = [];

    // Marcadores de partidos con escalado dinámico por zoom
    for (final item in _actividades) {
      if (item is Map<String, dynamic>) {
        final estado = item['estado'];
        final fecha = DateTime.tryParse(item['fecha_hora'] ?? '');

        if (estado == 'CANCELADA' || estado == 'FINALIZADA') continue;
        if (fecha != null && fecha.isBefore(DateTime.now())) continue;

        final latRaw = item['latitud'] ?? item['latitude'];
        final lngRaw = item['longitud'] ?? item['longitude'];

        final lat = double.tryParse(latRaw?.toString() ?? '');
        final lng = double.tryParse(lngRaw?.toString() ?? '');

        if (lat != null && lng != null) {
          final deporte = item['deporte_display'] ?? item['deporte'];
          final rutaIcono = _obtenerRutaIcono(deporte);
          final bool esPremium = item['organizador_es_premium'] == true;

          // ========================================================
          // CÁLCULO DE ESCALA Y VISIBILIDAD SEGÚN ZOOM ACTUAL
          // ========================================================
          double tamanoMarcador;
          double tamanoIcono;
          bool mostrarEstrella;

          if (_zoomActual < 11.5) {
            // Vista muy lejana (región / varias comunas): iconos miniatura sin estrella
            tamanoMarcador = 26.0;
            tamanoIcono = 24.0;
            mostrarEstrella = false;
          } else if (_zoomActual < 13.5) {
            // Vista intermedia (comuna): tamaño mediano sin estrella
            tamanoMarcador = 46.0;
            tamanoIcono = 42.0;
            mostrarEstrella = false;
          } else {
            // Vista cercana (calles y recintos deportivos): tamaño completo con estrella VIP
            tamanoMarcador = 76.0;
            tamanoIcono = 70.0;
            mostrarEstrella = esPremium;
          }

          marcadores.add(
            Marker(
              point: LatLng(lat, lng),
              width: tamanoMarcador,
              height: tamanoMarcador,
              child: GestureDetector(
                onTap: () => _mostrarDetalle(item),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Icono Pixel Art dinámico
                    SizedBox(
                      width: tamanoIcono,
                      height: tamanoIcono,
                      child: Image.asset(
                        rutaIcono,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.sports_soccer,
                          color: Colors.deepOrange,
                          size: tamanoIcono * 0.7,
                        ),
                      ),
                    ),

                    // Estrella VIP: solo visible cuando el usuario se acerca al mapa
                    if (mostrarEstrella)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.amber, Colors.deepOrange],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 2.5,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }

    // Marcador de ubicación actual del usuario
    if (_miUbicacion != null) {
      marcadores.add(
        Marker(
          point: _miUbicacion!,
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(alpha: 0.25),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Actividades'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar actividades',
            onPressed: cargarDatos,
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _miUbicacion ?? (marcadores.isNotEmpty ? marcadores.first.point : _centroInicial),
          initialZoom: 13.0,
          minZoom: 5.0,
          maxZoom: 19.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
          ),
          // Detecta el zoom en tiempo real sin saturar el hilo de renderizado
          onPositionChanged: (camera, hasGesture) {
            if ((camera.zoom - _zoomActual).abs() > 0.25) {
              setState(() {
                _zoomActual = camera.zoom;
              });
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://api.maptiler.com/maps/dataviz/{z}/{x}/{y}.png?key=e4xPAyc5rrsbCKddop5Z',
            userAgentPackageName: 'com.example.matchdeportivo',
            maxNativeZoom: 18,
          ),
          MarkerLayer(markers: marcadores),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton.small(
          heroTag: 'btn_mi_gps',
          onPressed: _obteniendoGps ? null : () => _determinarPosicionInicial(centrarCamara: true),
          tooltip: 'Mi ubicación',
          backgroundColor: Colors.white,
          foregroundColor: Colors.blueAccent,
          child: _obteniendoGps
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.my_location),
        ),
      ),
    );
  }
}