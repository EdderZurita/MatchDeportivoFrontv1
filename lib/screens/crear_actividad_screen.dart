import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import 'suscripcion_premium_screen.dart';

class CrearActividadScreen extends StatefulWidget {
  final Map<String, dynamic>? actividadExistente;

  const CrearActividadScreen({super.key, this.actividadExistente});

  @override
  State<CrearActividadScreen> createState() => _CrearActividadScreenState();
}

class _CrearActividadScreenState extends State<CrearActividadScreen> {
  final _formKey = GlobalKey<FormState>();
  final MapController _mapController = MapController();

  late TextEditingController _tituloCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _direccionCtrl;
  late TextEditingController _comunaCtrl;
  late TextEditingController _cuposCtrl;

  // Controlador para el campo de búsqueda predictiva
  TextEditingController? _autocompleteTextCtrl;

  String _deporte = 'FUTBOL';
  String _nivel = 'INTERMEDIO';
  DateTime _fechaHora = DateTime.now().add(const Duration(hours: 2));
  LatLng? _posicionElegida;
  bool _guardando = false;
  bool _obteniendoGps = false;

  final List<Map<String, String>> _deportes = [
    {'val': 'FUTBOL', 'label': 'Fútbol / Pichanga'},
    {'val': 'BASKETBOL', 'label': 'Básquetbol'},
    {'val': 'PADEL', 'label': 'Pádel'},
    {'val': 'TENIS', 'label': 'Tenis'},
    {'val': 'VOLEIBOL', 'label': 'Voleibol'},
    {'val': 'RUNNING', 'label': 'Running'},
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.actividadExistente;
    _tituloCtrl = TextEditingController(text: a?['titulo'] ?? '');
    _descCtrl = TextEditingController(text: a?['descripcion'] ?? '');
    _direccionCtrl = TextEditingController(text: a?['direccion'] ?? '');
    _comunaCtrl = TextEditingController(text: a?['comuna'] ?? '');
    _cuposCtrl = TextEditingController(text: a != null ? a['cupos_totales'].toString() : '10');

    if (a != null) {
      _deporte = a['deporte'] ?? 'FUTBOL';
      _nivel = a['nivel_esperado'] ?? 'INTERMEDIO';
      _fechaHora = DateTime.tryParse(a['fecha_hora'] ?? '') ?? DateTime.now().add(const Duration(hours: 2));
      _posicionElegida = LatLng(
        double.parse(a['latitud'].toString()),
        double.parse(a['longitud'].toString()),
      );
    } else {
      _posicionElegida = const LatLng(-33.4489, -70.6693);
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _direccionCtrl.dispose();
    _comunaCtrl.dispose();
    _cuposCtrl.dispose();
    super.dispose();
  }

  // 1. Geolocalización actual nativa (GPS) + Nominatim inverso
  Future<void> _usarUbicacionActual() async {
    setState(() => _obteniendoGps = true);
    try {
      final habilitado = await Geolocator.isLocationServiceEnabled();
      if (!habilitado) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, activa el GPS de tu teléfono.')),
        );
        return;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) return;
      }
      if (permiso == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permisos de GPS denegados en la configuración del teléfono.')),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final nuevoPunto = LatLng(pos.latitude, pos.longitude);

      String direccionDetectada = '';
      String comunaDetectada = '';

      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?'
              'lat=${pos.latitude}&lon=${pos.longitude}'
              '&format=json&addressdetails=1',
        );
        final resp = await http.get(
          url,
          headers: {'User-Agent': 'MatchDeportivo-App (contacto@matchdeportivo.cl)'},
        );

        if (resp.statusCode == 200) {
          final data = jsonDecode(utf8.decode(resp.bodyBytes));
          final addr = data['address'] ?? {};
          final calle = addr['road'] ?? addr['pedestrian'] ?? '';
          final num = addr['house_number'] ?? '';
          direccionDetectada = '$calle $num'.trim();
          if (direccionDetectada.isEmpty) {
            direccionDetectada = data['name'] ?? '';
          }
          comunaDetectada = addr['suburb'] ??
              addr['city_district'] ??
              addr['town'] ??
              addr['city'] ??
              addr['municipality'] ??
              '';
        }
      } catch (e) {
        debugPrint('Error en geocodificación inversa: $e');
      }

      setState(() {
        _posicionElegida = nuevoPunto;
        if (direccionDetectada.isNotEmpty) _direccionCtrl.text = direccionDetectada;
        if (comunaDetectada.isNotEmpty) _comunaCtrl.text = comunaDetectada;

        // Sincronizar el texto del buscador arriba para evitar desfaces
        if (_autocompleteTextCtrl != null) {
          _autocompleteTextCtrl!.text = direccionDetectada.isNotEmpty
              ? '$direccionDetectada, $comunaDetectada'
              : 'Mi ubicación actual';
        }
      });

      _mapController.move(nuevoPunto, 15.5);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener GPS: $e')),
      );
    } finally {
      if (mounted) setState(() => _obteniendoGps = false);
    }
  }

  // Consulta limpia a OpenStreetMap con manejo seguro de errores
  Future<List<dynamic>> _fetchNominatim(String query) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
            'q=${Uri.encodeComponent(query)}'
            '&format=json'
            '&addressdetails=1'
            '&limit=6'
            '&countrycodes=cl',
      );

      final resp = await http.get(
        url,
        headers: {'User-Agent': 'MatchDeportivo-App (contacto@matchdeportivo.cl)'},
      );

      debugPrint('--> [Nominatim HTTP] Query: "$query" | Status: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is List) {
          return decoded;
        }
      }
      return [];
    } catch (e) {
      debugPrint('--> [Nominatim ERROR]: $e');
      return [];
    }
  }

  // Búsqueda tolerante a numeración y extracción segura de datos
  Future<List<Map<String, dynamic>>> _buscarEnNominatim(String query) async {
    final texto = query.trim();
    if (texto.length < 3) return [];

    try {
      final matchNumero = RegExp(r'\b\d+\b').firstMatch(texto);
      final numeroExtraido = matchNumero?.group(0);
      final textoSinNumero = texto
          .replaceAll(RegExp(r'\b\d+\b'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      List<dynamic> data = await _fetchNominatim(texto);

      // Si con el número no hubo resultados, busca el nombre de la calle
      if (data.isEmpty && numeroExtraido != null && textoSinNumero.length >= 3) {
        data = await _fetchNominatim(textoSinNumero);
      }

      return data.map<Map<String, dynamic>>((item) {
        final addr = (item['address'] is Map) ? item['address'] : {};

        final String comuna = (addr['suburb'] ??
            addr['city_district'] ??
            addr['town'] ??
            addr['city'] ??
            addr['municipality'] ??
            '')
            .toString();

        final String calle = (addr['road'] ??
            addr['pedestrian'] ??
            addr['street'] ??
            '')
            .toString();

        final String numEnOsm = (addr['house_number'] ?? '').toString();
        final String numFinal = (numeroExtraido != null && numeroExtraido.isNotEmpty)
            ? numeroExtraido
            : numEnOsm;

        final String nombre = (item['name'] ?? '').toString();

        String direccionFormateada = '';
        if (calle.isNotEmpty) {
          direccionFormateada = numFinal.isNotEmpty ? '$calle $numFinal' : calle;
        } else if (nombre.isNotEmpty) {
          direccionFormateada = numFinal.isNotEmpty ? '$nombre $numFinal' : nombre;
        } else {
          final primero = (item['display_name'] ?? '').toString().split(',').first.trim();
          direccionFormateada = numFinal.isNotEmpty ? '$primero $numFinal' : primero;
        }

        return {
          'display_name': item['display_name']?.toString() ?? '',
          'direccion': direccionFormateada,
          'comuna': comuna,
          'lat': double.tryParse(item['lat']?.toString() ?? '') ?? 0.0,
          'lon': double.tryParse(item['lon']?.toString() ?? '') ?? 0.0,
        };
      }).where((m) => (m['lat'] as double) != 0.0).toList();
    } catch (e) {
      debugPrint('--> [Error procesando resultados Nominatim]: $e');
      return [];
    }
  }

  Future<void> _seleccionarFechaHora() async {
    final ahora = DateTime.now();

    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaHora.isBefore(ahora) ? ahora : _fechaHora,
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 90)),
    );
    if (fecha == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaHora),
    );
    if (hora == null) return;

    final seleccion = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);

    if (seleccion.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La hora seleccionada ya pasó. Elige un horario futuro.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _fechaHora = seleccion;
    });
  }

  void _mostrarModalLimitePremium(String mensaje) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Límite Diario Alcanzado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          mensaje,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SuscripcionPremiumScreen()),
              );
            },
            icon: const Icon(Icons.star, size: 18),
            label: const Text('Ver Plan Premium'),
          ),
        ],
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_posicionElegida == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, indica una ubicación para el partido.')),
      );
      return;
    }

    if (_fechaHora.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes crear o editar partidos con fechas en el pasado.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    final payload = {
      'titulo': _tituloCtrl.text.trim(),
      'descripcion': _descCtrl.text.trim(),
      'deporte': _deporte,
      'nivel_esperado': _nivel,
      'fecha_hora': _fechaHora.toUtc().toIso8601String(),
      'direccion': _direccionCtrl.text.trim(),
      'comuna': _comunaCtrl.text.trim(),
      'latitud': double.parse(_posicionElegida!.latitude.toStringAsFixed(6)),
      'longitud': double.parse(_posicionElegida!.longitude.toStringAsFixed(6)),
      'cupos_totales': int.parse(_cuposCtrl.text.trim()),
      'estado': 'ABIERTA',
    };

    final esEdicion = widget.actividadExistente != null;
    final Map<String, dynamic> respuesta = esEdicion
        ? await ApiService.editarActividadConDetalle(widget.actividadExistente!['id'], payload)
        : await ApiService.crearActividadConDetalle(payload);

    setState(() => _guardando = false);

    if (!mounted) return;

    if (respuesta['exito'] == true) {
      Navigator.pop(context, true);
    } else {
      final String mensajeError = respuesta['detail'] ?? 'Error al procesar la solicitud.';
      final int codigo = respuesta['codigo'] ?? 0;

      if (codigo == 403 || mensajeError.contains('límite') || mensajeError.contains('Premium')) {
        _mostrarModalLimitePremium(mensajeError);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeError),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.actividadExistente != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar Actividad' : 'Nueva Convocatoria'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _tituloCtrl,
              decoration: const InputDecoration(labelText: 'Título del Partido *', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Ingresa un título' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _deporte,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Deporte *', border: OutlineInputBorder()),
              items: _deportes.map((d) => DropdownMenuItem(
                value: d['val'],
                child: Text(d['label']!, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) => setState(() => _deporte = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _nivel,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Nivel esperado *', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'PRINCIPIANTE', child: Text('Principiante')),
                DropdownMenuItem(value: 'INTERMEDIO', child: Text('Intermedio')),
                DropdownMenuItem(value: 'AVANZADO', child: Text('Avanzado')),
              ],
              onChanged: (v) => setState(() => _nivel = v!),
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.grey)),
              leading: const Icon(Icons.calendar_today),
              title: Text('Fecha y Hora: ${_fechaHora.day}/${_fechaHora.month} ${_fechaHora.hour.toString().padLeft(2, '0')}:${_fechaHora.minute.toString().padLeft(2, '0')} hrs'),
              trailing: const Icon(Icons.edit),
              onTap: _seleccionarFechaHora,
            ),
            const SizedBox(height: 16),

            // SECCIÓN: LOCALIZACIÓN DEL RECINTO
            const Text(
              'Ubicación del Encuentro',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Botón GPS actual
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _obteniendoGps
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: Colors.deepOrange),
              label: Text(_obteniendoGps ? 'Obteniendo GPS...' : 'Usar mi ubicación actual'),
              onPressed: _obteniendoGps ? null : _usarUbicacionActual,
            ),
            const SizedBox(height: 12),

            // Buscador predictivo sincronizado
            Autocomplete<Map<String, dynamic>>(
            displayStringForOption: (opt) => opt['direccion'] ?? '',
            optionsBuilder: (TextEditingValue textVal) async {
              return await _buscarEnNominatim(textVal.text);
            },
            onSelected: (seleccion) {
              final lat = seleccion['lat'] as double;
              final lon = seleccion['lon'] as double;
              final punto = LatLng(lat, lon);

              setState(() {
                _posicionElegida = punto;
                _direccionCtrl.text = seleccion['direccion'] ?? '';
                _comunaCtrl.text = seleccion['comuna'] ?? '';
              });

              _mapController.move(punto, 15.5);
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              // Guardar la referencia al controlador para sincronizarlo con el GPS
              _autocompleteTextCtrl = controller;

              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Buscar recinto o calle por nombre',
                  hintText: 'Ej: Santa Pilar 11091, Cancha San Miguel...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      setState(() {});
                    },
                  )
                      : null,
                  border: const OutlineInputBorder(),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250, maxWidth: 340),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (ctx, index) {
                        final opt = options.elementAt(index);
                        final comuna = opt['comuna'] ?? '';
                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.deepOrange),
                          title: Text(
                            opt['direccion'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            comuna.isNotEmpty ? '$comuna • ${opt['display_name']}' : opt['display_name'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () => onSelected(opt),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            ),
            const SizedBox(height: 12),

            // Campos de autocompletado ordenados verticalmente (evita cortes)
            TextFormField(
              controller: _direccionCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Dirección / Recinto asignado *',
                filled: true,
                fillColor: Colors.grey.shade100,
                prefixIcon: const Icon(Icons.place_outlined, color: Colors.grey),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Selecciona una ubicación arriba' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _comunaCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Comuna asignada *',
                filled: true,
                fillColor: Colors.grey.shade100,
                prefixIcon: const Icon(Icons.location_city_outlined, color: Colors.grey),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),

            // Previsualización en Minimapa (MapTiler Streets-v2)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Previsualización en mapa:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (_posicionElegida != null)
                  Text(
                    '${_posicionElegida!.latitude.toStringAsFixed(4)}, ${_posicionElegida!.longitude.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _posicionElegida ?? const LatLng(-33.4489, -70.6693),
                  initialZoom: 14.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://api.maptiler.com/maps/dataviz/{z}/{x}/{y}.png?key=e4xPAyc5rrsbCKddop5Z',
                    userAgentPackageName: 'com.example.matchdeportivo',
                    maxNativeZoom: 19,
                  ),
                  if (_posicionElegida != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _posicionElegida!,
                          width: 45,
                          height: 45,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 45),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            TextFormField(
              controller: _cuposCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cupos Totales de Jugadores *', border: OutlineInputBorder()),
              validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Mínimo 1 cupo' : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(esEdicion ? 'Actualizar Actividad' : 'Publicar Actividad'),
            ),
          ],
        ),
      ),
    );
  }
}