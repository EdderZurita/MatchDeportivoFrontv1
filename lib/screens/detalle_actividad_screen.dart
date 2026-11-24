import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/calificar_dialog.dart';
import '../widgets/resena_actividad_dialog.dart';
import 'crear_actividad_screen.dart';
import 'chat_screen.dart';
import 'perfil_amigo_screen.dart';

class DetalleActividadScreen extends StatefulWidget {
  final Map<String, dynamic> actividad;

  const DetalleActividadScreen({super.key, required this.actividad});

  @override
  State<DetalleActividadScreen> createState() => _DetalleActividadScreenState();
}

class _DetalleActividadScreenState extends State<DetalleActividadScreen> {
  late Map<String, dynamic> _actividad;
  List<dynamic> _participantes = [];
  bool _cargando = true;
  bool _procesandoAccion = false;
  String? _miUsuario;

  @override
  void initState() {
    super.initState();
    _actividad = widget.actividad;
    _recargarDetalles();
  }

  Future<void> _recargarDetalles() async {
    setState(() => _cargando = true);
    final user = await ApiService.getUsername();
    final datosFrescos = await ApiService.getDetalleActividad(_actividad['id']);
    final inscritos = await ApiService.getParticipantesActividad(_actividad['id']);

    if (!mounted) return;
    setState(() {
      _miUsuario = user;
      if (datosFrescos != null) _actividad = datosFrescos;
      _participantes = inscritos;
      _cargando = false;
    });
  }

  bool get _esOrganizador =>
      _miUsuario != null && _actividad['organizador_nombre'] == _miUsuario;

  String? get _miEstadoInscripcion {
    if (_miUsuario == null) return null;
    final miInscripcion = _participantes.firstWhere(
          (p) {
        final username = p['usuario_nombre'] ??
            (p['usuario'] is Map ? p['usuario']['username'] : null);
        return username != null &&
            username.toString().toLowerCase() == _miUsuario!.toLowerCase();
      },
      orElse: () => null,
    );
    return miInscripcion != null ? miInscripcion['estado'] : null;
  }

  bool get _estoyConfirmado => _miEstadoInscripcion == 'CONFIRMADA';
  bool get _estoyPendiente => _miEstadoInscripcion == 'PENDIENTE';
  bool get _fuiExpulsado => _miEstadoInscripcion == 'EXPULSADA';

  bool get _puedeChatear => _esOrganizador || _estoyConfirmado;

  void _abrirChat() {
    if (_miUsuario == null || _miUsuario!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para ingresar al chat.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          titulo: 'Chat: ${_actividad['titulo'] ?? 'Partido'}',
          miUsername: _miUsuario!,
          actividadId: _actividad['id'],
        ),
      ),
    );
  }

  void _abrirPerfilUsuario({required int usuarioId, required String username}) {
    if (username.toLowerCase() == (_miUsuario ?? '').toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este es tu propio perfil deportivo.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (usuarioId <= 0) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilAmigoScreen(
          usuarioId: usuarioId,
          username: username,
          miUsername: _miUsuario ?? '',
        ),
      ),
    );
  }

  Future<void> _abrirDialogoCalificacion({required int usuarioId, required String username}) async {
    final calificado = await showDialog<bool>(
      context: context,
      builder: (_) => CalificarJugadorDialog(
        actividadId: _actividad['id'],
        usuarioId: usuarioId,
        username: username,
      ),
    );
    if (calificado == true) {
      _recargarDetalles();
    }
  }

  // RF-27: Apertura y validación previa de reseña general
  Future<void> _abrirDialogoResenaActividad() async {
    final res = await ApiService.getMiResenaActividad(_actividad['id']);
    if (!mounted) return;

    if (res['existe'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya enviaste tu reseña general para este encuentro.'),
          backgroundColor: Colors.blueGrey,
        ),
      );
      return;
    }

    final evaluado = await showDialog<bool>(
      context: context,
      builder: (_) => ResenaActividadDialog(
        actividadId: _actividad['id'],
        tituloActividad: _actividad['titulo'] ?? 'Partido',
      ),
    );

    if (evaluado == true) {
      _recargarDetalles();
    }
  }

  Future<void> _inscribirme() async {
    setState(() => _procesandoAccion = true);
    final res = await ApiService.inscribirseActividad(_actividad['id']);
    setState(() => _procesandoAccion = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['detail']),
        backgroundColor: res['exito'] ? Colors.green : Colors.red,
      ),
    );
    if (res['exito']) _recargarDetalles();
  }

  Future<void> _abandonar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar solicitud / abandonar?'),
        content: const Text('Liberarás tu lugar en esta convocatoria.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _procesandoAccion = true);
    final res = await ApiService.abandonarActividad(_actividad['id']);
    setState(() => _procesandoAccion = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['detail']),
        backgroundColor: res['exito'] ? Colors.orange : Colors.red,
      ),
    );
    if (res['exito']) _recargarDetalles();
  }

  Future<void> _moderarParticipante(int usuarioId, String nombre, String nuevoEstado) async {
    String accionTexto = 'actualizar a este participante';
    if (nuevoEstado == 'CONFIRMADA') accionTexto = 'aceptar a $nombre en el partido';
    if (nuevoEstado == 'RECHAZADA') accionTexto = 'rechazar la solicitud de $nombre';
    if (nuevoEstado == 'EXPULSADA') accionTexto = 'expulsar a $nombre de la convocatoria';

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar acción'),
        content: Text('¿Estás seguro de que deseas $accionTexto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: nuevoEstado == 'CONFIRMADA' ? Colors.green : Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _procesandoAccion = true);
    final exito = await ApiService.gestionarParticipante(_actividad['id'], usuarioId, nuevoEstado);
    setState(() => _procesandoAccion = false);

    if (!mounted) return;
    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Participante actualizado: $nuevoEstado'),
          backgroundColor: nuevoEstado == 'CONFIRMADA' ? Colors.green : Colors.orange,
        ),
      );
      _recargarDetalles();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo modificar al participante o no quedan cupos libres.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fecha = DateTime.tryParse(_actividad['fecha_hora'] ?? '') ?? DateTime.now();
    final cuposLibres = _actividad['cupos_disponibles'] ?? 0;
    final cuposTotales = _actividad['cupos_totales'] ?? 0;
    final estado = _actividad['estado'] ?? 'ABIERTA';

    final esPasada = fecha.isBefore(DateTime.now()) || estado == 'FINALIZADA';
    final estadoVisual = esPasada ? 'REALIZADO' : estado;

    final int organizadorId = (_actividad['organizador'] is int)
        ? _actividad['organizador']
        : int.tryParse(_actividad['organizador']?.toString() ?? '') ?? 0;
    final String organizadorNombre = _actividad['organizador_nombre'] ?? 'Anónimo';

    final confirmados = _participantes.where((p) => p['estado'] == 'CONFIRMADA').toList();
    final pendientes = _participantes.where((p) => p['estado'] == 'PENDIENTE').toList();
    final bool yoParticipe = _esOrganizador || _estoyConfirmado;

    return Scaffold(
      appBar: AppBar(
        title: Text(_actividad['titulo'] ?? 'Detalle del Partido'),
        actions: [
          if (_puedeChatear)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Chat de la Convocatoria',
              onPressed: _abrirChat,
            ),
          if (_esOrganizador && !esPasada)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar Convocatoria',
              onPressed: () async {
                final editado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CrearActividadScreen(actividadExistente: _actividad),
                  ),
                );
                if (editado == true) _recargarDetalles();
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _recargarDetalles,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Tarjeta principal de la convocatoria
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Chip(
                          label: Text(
                            _actividad['deporte_display'] ?? _actividad['deporte'] ?? 'DEPORTE',
                            overflow: TextOverflow.ellipsis,
                          ),
                          backgroundColor: Colors.deepOrange.shade100,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: esPasada
                              ? Colors.blueGrey.shade100
                              : estado == 'ABIERTA'
                              ? Colors.green.shade100
                              : estado == 'LLENA'
                              ? Colors.amber.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          estadoVisual,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: esPasada
                                ? Colors.blueGrey.shade900
                                : estado == 'ABIERTA'
                                ? Colors.green.shade900
                                : estado == 'LLENA'
                                ? Colors.brown.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _actividad['titulo'] ?? '',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _actividad['descripcion'] ?? 'Sin descripción adicional.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.deepOrange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${fecha.day}/${fecha.month}/${fecha.year} a las ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')} hrs',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.deepOrange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${_actividad['direccion']}, ${_actividad['comuna']}')),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Fila del Organizador con opción de calificar si ya concluyó el partido
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _abrirPerfilUsuario(
                      usuarioId: organizadorId,
                      username: organizadorNombre,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Colors.deepOrange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: 'Organizador: ',
                                children: [
                                  TextSpan(
                                    text: organizadorNombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                      color: Colors.deepOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (esPasada && !_esOrganizador && _estoyConfirmado && organizadorId > 0)
                            IconButton(
                              icon: const Icon(Icons.star_rate, color: Colors.amber),
                              tooltip: 'Calificar organizador',
                              onPressed: () => _abrirDialogoCalificacion(
                                usuarioId: organizadorId,
                                username: organizadorNombre,
                              ),
                            ),
                          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.group, color: Colors.deepOrange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cupos Disponibles: $cuposLibres / $cuposTotales',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cuposLibres > 0 ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Botón de Chat del Partido (RF-16)
          if (_puedeChatear) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _abrirChat,
              icon: const Icon(Icons.forum_outlined),
              label: const Text(
                'Abrir Chat del Partido',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 3. Botones de acción del participante
          if (esPasada) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: null,
              icon: const Icon(Icons.event_available),
              label: const Text('Partido Concluido • Califica a tus compañeros abajo'),
            ),

            // RF-27: Botón para calificar y dejar reseña sobre el partido, recinto y organización
            if (yoParticipe) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text(
                  'Evaluar Encuentro y Recinto (RF-27)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: _abrirDialogoResenaActividad,
              ),
            ],
            const SizedBox(height: 20),
          ] else if (!_esOrganizador) ...[
            if (_estoyConfirmado)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _procesandoAccion ? null : _abandonar,
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Abandonar Partido (Liberar Cupo)'),
              )
            else if (_estoyPendiente)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_top, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tu solicitud fue enviada. Esperando aprobación del organizador.',
                            style: TextStyle(fontSize: 13, color: Colors.brown),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _procesandoAccion ? null : _abandonar,
                    child: const Text('Cancelar Solicitud de Cupo', style: TextStyle(color: Colors.red)),
                  ),
                ],
              )
            else if (_fuiExpulsado)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: const Text(
                    'Fuiste retirado de esta convocatoria por el organizador.',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (estado == 'ABIERTA' && cuposLibres > 0)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _procesandoAccion ? null : _inscribirme,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Solicitar Inscripción al Partido'),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: null,
                    child: Text(estado == 'LLENA' ? 'Cupos Agotados' : 'Convocatoria Finalizada'),
                  ),
            const SizedBox(height: 20),
          ],

          // 4. APARTADO RF-14: SOLICITUDES PENDIENTES (Solo para el Organizador)
          if (_esOrganizador && pendientes.isNotEmpty && !esPasada) ...[
            Card(
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.amber.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pending_actions, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Solicitudes Pendientes (${pendientes.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toca al jugador para revisar su perfil e historial antes de decidir.',
                      style: TextStyle(fontSize: 12, color: Colors.brown.shade700),
                    ),
                    const Divider(),
                    ...pendientes.map((p) {
                      final int uId = (p['usuario'] is int)
                          ? p['usuario']
                          : (p['usuario'] is Map ? p['usuario']['id'] : int.tryParse(p['usuario'].toString()) ?? 0);
                      final String nombre = p['usuario_nombre'] ??
                          (p['usuario'] is Map ? p['usuario']['username'] : 'Jugador');

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => _abrirPerfilUsuario(usuarioId: uId, username: nombre),
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.shade200,
                          child: Text(
                            nombre.isNotEmpty ? nombre[0].toUpperCase() : 'J',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown.shade900),
                          ),
                        ),
                        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Toca para ver perfil'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                              tooltip: 'Aceptar participante',
                              onPressed: () => _moderarParticipante(uId, nombre, 'CONFIRMADA'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 28),
                              tooltip: 'Rechazar solicitud',
                              onPressed: () => _moderarParticipante(uId, nombre, 'RECHAZADA'),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // 5. LISTA DE PARTICIPANTES CONFIRMADOS (RF-18: Calificaciones post-partido)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Jugadores Confirmados (${confirmados.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (_esOrganizador) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.deepOrange.shade200),
                  ),
                  child: Text(
                    'Organizador',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange.shade900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            esPasada
                ? 'Toca la estrella dorada para calificar a tus compañeros de juego'
                : 'Toca a cualquier jugador para ver su perfil e historial deportivo',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),

          if (confirmados.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text('Aún no hay jugadores confirmados en este partido.', textAlign: TextAlign.center),
            )
          else
            ...confirmados.map((p) {
              final int uId = (p['usuario'] is int)
                  ? p['usuario']
                  : (p['usuario'] is Map ? p['usuario']['id'] : int.tryParse(p['usuario'].toString()) ?? 0);
              final String nombre = p['usuario_nombre'] ??
                  (p['usuario'] is Map ? p['usuario']['username'] : 'Jugador');
              final bool soyYo = nombre.toLowerCase() == (_miUsuario ?? '').toLowerCase();

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                elevation: 1,
                child: ListTile(
                  onTap: () => _abrirPerfilUsuario(usuarioId: uId, username: nombre),
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepOrange.shade100,
                    child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : 'J'),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (soyYo) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Tú',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.deepOrange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: const Text('Confirmado • Toca para ver perfil'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (esPasada && !soyYo && yoParticipe)
                        IconButton(
                          icon: const Icon(Icons.star_rate, color: Colors.amber),
                          tooltip: 'Calificar jugador',
                          onPressed: () => _abrirDialogoCalificacion(
                            usuarioId: uId,
                            username: nombre,
                          ),
                        ),
                      if (_esOrganizador && !esPasada && !soyYo)
                        IconButton(
                          icon: const Icon(Icons.person_remove, color: Colors.red),
                          tooltip: 'Expulsar de la convocatoria',
                          onPressed: () => _moderarParticipante(uId, nombre, 'EXPULSADA'),
                        ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}