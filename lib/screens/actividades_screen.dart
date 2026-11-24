import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../utils/geo_utils.dart';
import 'detalle_actividad_screen.dart';
import 'suscripcion_premium_screen.dart';

class ActividadesScreen extends StatefulWidget {
  const ActividadesScreen({super.key});

  @override
  State<ActividadesScreen> createState() => _ActividadesScreenState();
}

class _ActividadesScreenState extends State<ActividadesScreen> {
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _todasActividades = [];
  List<dynamic> _actividadesRecomendadas = [];
  bool _cargando = true;
  bool _esPremium = true;
  Position? _miPosicion;

  // Filtros manuales de búsqueda
  String _busquedaTexto = '';
  String _deporteSeleccionado = 'TODOS';
  String _nivelSeleccionado = 'TODOS';
  double? _radioMaximoKm;
  bool _soloConCupos = false;

  final List<String> _deportes = [
    'TODOS',
    'Fútbol',
    'Básquetbol',
    'Pádel',
    'Tenis',
    'Voleibol',
    'Running',
  ];

  final List<String> _niveles = [
    'TODOS',
    'Principiante',
    'Intermedio',
    'Avanzado',
  ];

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _inicializarDatos() async {
    setState(() => _cargando = true);
    await _obtenerUbicacionActual();
    await Future.wait([
      _cargarActividades(),
      _cargarRecomendadas(),
    ]);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _obtenerUbicacionActual() async {
    try {
      final habilitado = await Geolocator.isLocationServiceEnabled();
      if (!habilitado) return;

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) return;
      }
      if (permiso == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) setState(() => _miPosicion = pos);
    } catch (_) {}
  }

  // Filtra solo actividades activas (no canceladas/finalizadas y con fecha futura)
  bool _esActividadActiva(Map<String, dynamic> act) {
    final estado = (act['estado'] ?? '').toString().toUpperCase();
    if (estado == 'CANCELADA' || estado == 'FINALIZADA') {
      return false;
    }

    final fecha = DateTime.tryParse(act['fecha_hora']?.toString() ?? '');
    if (fecha == null || !fecha.isAfter(DateTime.now())) {
      return false;
    }

    return true;
  }

  Future<void> _cargarActividades() async {
    final data = await ApiService.getActividades();
    if (!mounted) return;
    setState(() {
      _todasActividades = data
          .where((a) => a is Map && _esActividadActiva(Map<String, dynamic>.from(a)))
          .toList();
    });
  }

  // Carga y validación de acceso al motor de Matchmaking
  Future<void> _cargarRecomendadas() async {
    final dynamic resp = await ApiService.getActividadesRecomendadas();
    if (!mounted) return;

    bool esPrem = true;
    List<dynamic> data = [];

    // Compatibilidad tanto si devuelve Map (con es_premium) como List directa
    if (resp is Map) {
      esPrem = resp['es_premium'] ?? false;
      data = (resp['data'] as List<dynamic>?) ?? [];
    } else if (resp is List) {
      data = resp;
      esPrem = true;
    }

    final procesadas = data
        .whereType()
        .map((act) => Map<String, dynamic>.from(act))
        .where(_esActividadActiva)
        .map((actMap) {
      final latRaw = actMap['latitud'] ?? actMap['latitude'];
      final lngRaw = actMap['longitud'] ?? actMap['longitude'];
      final lat = double.tryParse(latRaw?.toString() ?? '');
      final lng = double.tryParse(lngRaw?.toString() ?? '');

      if (_miPosicion != null && lat != null && lng != null) {
        actMap['_distancia_calculada'] = GeoUtils.calcularDistanciaHaversine(
          _miPosicion!.latitude,
          _miPosicion!.longitude,
          lat,
          lng,
        );
      }
      return actMap;
    }).toList();

    setState(() {
      _esPremium = esPrem;
      _actividadesRecomendadas = procesadas;
    });
  }

  List<dynamic> _filtrarYOrdenar() {
    final resultado = <dynamic>[];

    for (final act in _todasActividades) {
      final actMap = Map<String, dynamic>.from(act);
      if (!_esActividadActiva(actMap)) continue;

      final titulo = (actMap['titulo'] ?? '').toString().toLowerCase();
      final comuna = (actMap['comuna'] ?? '').toString().toLowerCase();
      final direccion = (actMap['direccion'] ?? '').toString().toLowerCase();
      final deporte = (actMap['deporte_display'] ?? actMap['deporte'] ?? '').toString().toLowerCase();

      final nivelRaw = (actMap['nivel_esperado'] ??
          actMap['nivel_esperado_display'] ??
          actMap['nivel'] ??
          actMap['nivel_display'] ??
          '')
          .toString()
          .toLowerCase();

      final cupos = actMap['cupos_disponibles'] ?? 0;

      // 1. Filtro por búsqueda de texto
      if (_busquedaTexto.isNotEmpty) {
        final query = _busquedaTexto.toLowerCase();
        if (!titulo.contains(query) && !comuna.contains(query) && !direccion.contains(query)) {
          continue;
        }
      }

      // 2. Filtro por deporte
      if (_deporteSeleccionado != 'TODOS') {
        final depFiltro = _deporteSeleccionado.toLowerCase();
        if (!deporte.contains(depFiltro)) {
          continue;
        }
      }

      // 3. Filtro por Nivel de Juego
      if (_nivelSeleccionado != 'TODOS') {
        final nivFiltro = _nivelSeleccionado.toLowerCase();
        if (nivelRaw.isEmpty) continue;

        bool coincideNivel = false;
        if (nivFiltro.startsWith('princ') &&
            (nivelRaw.contains('princ') || nivelRaw == 'pr' || nivelRaw.contains('basic'))) {
          coincideNivel = true;
        } else if (nivFiltro.startsWith('inter') &&
            (nivelRaw.contains('inter') || nivelRaw == 'int' || nivelRaw.contains('medio'))) {
          coincideNivel = true;
        } else if (nivFiltro.startsWith('avan') &&
            (nivelRaw.contains('avan') || nivelRaw == 'av' || nivelRaw.contains('alto'))) {
          coincideNivel = true;
        } else if (nivelRaw.contains(nivFiltro)) {
          coincideNivel = true;
        }

        if (!coincideNivel) continue;
      }

      // 4. Filtro por cupos
      if (_soloConCupos && cupos <= 0) continue;

      // 5. Cálculo Haversine
      double? distanciaKm;
      final latRaw = actMap['latitud'] ?? actMap['latitude'];
      final lngRaw = actMap['longitud'] ?? actMap['longitude'];
      final lat = double.tryParse(latRaw?.toString() ?? '');
      final lng = double.tryParse(lngRaw?.toString() ?? '');

      if (_miPosicion != null && lat != null && lng != null) {
        distanciaKm = GeoUtils.calcularDistanciaHaversine(
          _miPosicion!.latitude,
          _miPosicion!.longitude,
          lat,
          lng,
        );
      }

      // 6. Filtro por radio de distancia
      if (_radioMaximoKm != null) {
        if (distanciaKm == null || distanciaKm > _radioMaximoKm!) {
          continue;
        }
      }

      actMap['_distancia_calculada'] = distanciaKm;
      resultado.add(actMap);
    }

    if (_miPosicion != null) {
      resultado.sort((a, b) {
        final distA = a['_distancia_calculada'] as double? ?? 999999.0;
        final distB = b['_distancia_calculada'] as double? ?? 999999.0;
        return distA.compareTo(distB);
      });
    } else {
      resultado.sort((a, b) {
        final fechaA = DateTime.tryParse(a['fecha_hora'] ?? '') ?? DateTime.now();
        final fechaB = DateTime.tryParse(b['fecha_hora'] ?? '') ?? DateTime.now();
        return fechaA.compareTo(fechaB);
      });
    }

    return resultado;
  }

  void _abrirModalFiltros() {
    FocusScope.of(context).unfocus();
    _searchFocusNode.unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filtros de Búsqueda',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _deporteSeleccionado = 'TODOS';
                              _nivelSeleccionado = 'TODOS';
                              _radioMaximoKm = null;
                              _soloConCupos = false;
                            });
                            setState(() {});
                          },
                          child: const Text('Restablecer'),
                        )
                      ],
                    ),
                    const Divider(),

                    const Text('Deporte:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: _deportes.map((dep) {
                        final sel = _deporteSeleccionado == dep;
                        return ChoiceChip(
                          label: Text(dep),
                          selected: sel,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _deporteSeleccionado = dep);
                              setState(() {});
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Radio Máximo de Distancia (Haversine):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Sin límite'),
                          selected: _radioMaximoKm == null,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _radioMaximoKm = null);
                              setState(() {});
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('< 5 km'),
                          selected: _radioMaximoKm == 5.0,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _radioMaximoKm = 5.0);
                              setState(() {});
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('< 10 km'),
                          selected: _radioMaximoKm == 10.0,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _radioMaximoKm = 10.0);
                              setState(() {});
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('< 25 km'),
                          selected: _radioMaximoKm == 25.0,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _radioMaximoKm = 25.0);
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const Text('Nivel de Juego:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: _niveles.map((niv) {
                        final sel = _nivelSeleccionado == niv;
                        return ChoiceChip(
                          label: Text(niv),
                          selected: sel,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _nivelSeleccionado = niv);
                              setState(() {});
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Solo partidos con cupos libres'),
                      value: _soloConCupos,
                      onChanged: (val) {
                        setModalState(() => _soloConCupos = val);
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _searchFocusNode.unfocus();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Ver Resultados'),
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

  // Componente reutilizable para tarjetas de partido activo
  Widget _buildTarjetaActividad(Map<String, dynamic> act, {bool destacarMatch = false}) {
    final estadoMostrar = act['estado'] ?? 'ABIERTA';
    final double? distKm = act['_distancia_calculada'];
    final int? matchPct = act['porcentaje_match'] is int
        ? act['porcentaje_match']
        : int.tryParse(act['porcentaje_match']?.toString() ?? '');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: destacarMatch && matchPct != null && matchPct >= 75
            ? BorderSide(color: Colors.green.shade400, width: 1.4)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleActividadScreen(actividad: act),
            ),
          );
          _cargarActividades();
          _cargarRecomendadas();
        },
        leading: CircleAvatar(
          backgroundColor: Colors.deepOrange.shade100,
          child: Text(
            act['deporte'] != null && act['deporte'].toString().isNotEmpty
                ? act['deporte'][0].toUpperCase()
                : 'D',
            style: TextStyle(
              color: Colors.deepOrange.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                act['titulo'] ?? 'Sin título',
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (matchPct != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: matchPct >= 75
                      ? const Color(0xFF2E7D32)
                      : (matchPct >= 50 ? Colors.deepOrange : Colors.blueGrey),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, color: Colors.amberAccent, size: 13),
                    const SizedBox(width: 2),
                    Text(
                      '$matchPct% Match',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${act['deporte_display'] ?? act['deporte'] ?? 'Deporte'} • ${act['comuna'] ?? ''} ${act['direccion'] ?? ''}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Cupos: ${act['cupos_disponibles'] ?? 0}/${act['cupos_totales'] ?? 0}',
                  style: TextStyle(
                    color: (act['cupos_disponibles'] ?? 0) > 0
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (distKm != null) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.location_on, size: 12, color: Colors.blue.shade700),
                  const SizedBox(width: 2),
                  Text(
                    GeoUtils.formatearDistancia(distKm),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: estadoMostrar == 'ABIERTA'
                ? Colors.green.shade100
                : Colors.red.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            estadoMostrar,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: estadoMostrar == 'ABIERTA'
                  ? Colors.green.shade900
                  : Colors.red.shade900,
            ),
          ),
        ),
      ),
    );
  }

  // Pestaña 1: Partidos Recomendados por Matchmaking (Protegida)
  Widget _buildTabMatchmaking() {
    // Si la cuenta no es Premium, muestra la vista promocional de bloqueo
    if (!_esPremium) {
      return RefreshIndicator(
        onRefresh: _inicializarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: _buildVistaBloqueoPremium(),
        ),
      );
    }

    if (_actividadesRecomendadas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'No hay partidos compatibles por ahora',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Asegúrate de configurar tus deportes preferidos, comuna y nivel de juego en tu perfil.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _inicializarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _actividadesRecomendadas.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.deepOrange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.deepOrange, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Partidos ordenados por afinidad según tus deportes favoritos, comuna, nivel y reputación.',
                      style: TextStyle(fontSize: 12, color: Colors.deepOrange.shade900),
                    ),
                  ),
                ],
              ),
            );
          }

          final act = _actividadesRecomendadas[index - 1];
          return _buildTarjetaActividad(act, destacarMatch: true);
        },
      ),
    );
  }

  // Vista promocional de conversión para usuarios no Premium
  Widget _buildVistaBloqueoPremium() {
    return Center(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium, size: 50, color: Colors.deepOrange),
              ),
              const SizedBox(height: 16),
              const Text(
                'Matchmaking Inteligente',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'EXCLUSIVO PREMIUM',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Nuestro motor de compatibilidad analiza en tiempo real tu deporte favorito, nivel de habilidad, cercanía GPS y reputación para sugerirte los partidos ideales para ti.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildBeneficioItem(Icons.bolt, 'Porcentaje de compatibilidad en vivo (% Match)'),
                    const SizedBox(height: 10),
                    _buildBeneficioItem(Icons.near_me, 'Priorización por proximidad GPS y comuna'),
                    const SizedBox(height: 10),
                    _buildBeneficioItem(Icons.sports_soccer, 'Filtro por nivel de juego equilibrado'),
                    const SizedBox(height: 10),
                    _buildBeneficioItem(Icons.verified_user_outlined, 'Evaluación de reputación de jugadores'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SuscripcionPremiumScreen()),
                    );
                    _inicializarDatos();
                  },
                  icon: const Icon(Icons.star, size: 20),
                  label: const Text(
                    'Pasar a MatchDeportivo Premium',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBeneficioItem(IconData icono, String texto) {
    return Row(
      children: [
        Icon(icono, size: 18, color: Colors.deepOrange),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  // Pestaña 2: Explorador general con buscador y filtros
  Widget _buildTabExplorar(List<dynamic> actividadesFiltradas) {
    return Column(
      children: [
        // Buscador y botón de filtros
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  focusNode: _searchFocusNode,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Buscar por comuna o partido...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _busquedaTexto = val.trim()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.tune),
                tooltip: 'Filtros avanzados',
                onPressed: _abrirModalFiltros,
              ),
            ],
          ),
        ),

        // Indicador de proximidad GPS
        if (_miPosicion != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.near_me, size: 14, color: Colors.blueAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ordenado por proximidad GPS',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Listado filtrado
        Expanded(
          child: actividadesFiltradas.isEmpty
              ? Center(
            child: Text(
              'No se encontraron partidos activos con los filtros seleccionados.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
              : RefreshIndicator(
            onRefresh: _inicializarDatos,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: actividadesFiltradas.length,
              itemBuilder: (context, index) {
                final act = actividadesFiltradas[index];
                return _buildTarjetaActividad(act);
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final actividadesFiltradas = _filtrarYOrdenar();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Convocatorias Deportivas'),
          bottom: const TabBar(
            indicatorColor: Colors.deepOrange,
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.black54,
            tabs: [
              Tab(
                icon: Icon(Icons.bolt),
                text: 'Para ti (Match)',
              ),
              Tab(
                icon: Icon(Icons.explore_outlined),
                text: 'Explorar Todas',
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
              onPressed: _inicializarDatos,
            )
          ],
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            _buildTabMatchmaking(),
            _buildTabExplorar(actividadesFiltradas),
          ],
        ),
      ),
    );
  }
}