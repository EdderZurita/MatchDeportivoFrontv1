import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'perfil_amigo_screen.dart';

class AmigosScreen extends StatefulWidget {
  final String miUsername;
  const AmigosScreen({super.key, required this.miUsername});

  @override
  State<AmigosScreen> createState() => _AmigosScreenState();
}

class _AmigosScreenState extends State<AmigosScreen> {
  List<dynamic> _amigos = [];
  List<dynamic> _amigosFiltrados = [];
  List<dynamic> _solicitudesPendientes = [];
  bool _cargando = true;
  final _busquedaLocalCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  @override
  void dispose() {
    _busquedaLocalCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    final amigosData = await ApiService.getMisAmigos();
    final solicitudesData = await ApiService.getSolicitudesRecibidas();

    if (mounted) {
      setState(() {
        _amigos = amigosData;
        _amigosFiltrados = amigosData;
        _solicitudesPendientes = solicitudesData;
        _cargando = false;
      });
    }
  }

  void _filtrarAmigos(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _amigosFiltrados = _amigos;
      } else {
        _amigosFiltrados = _amigos.where((amigo) {
          final username = (amigo['username'] ?? '').toString().toLowerCase();
          return username.contains(query.trim().toLowerCase());
        }).toList();
      }
    });
  }

  // --- BANDEJA DE SOLICITUDES PENDIENTES ---
  void _mostrarBandejaSolicitudes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> responder(int solicitudId, String accion) async {
              final res = await ApiService.responderSolicitud(solicitudId, accion);

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res['detail'] ?? 'Respuesta procesada'),
                  backgroundColor: res['exito'] == true ? Colors.green : Colors.redAccent,
                ),
              );

              if (res['exito'] == true) {
                setModalState(() {
                  _solicitudesPendientes.removeWhere((item) => item['id'] == solicitudId);
                });
                _cargarTodo();
              }
            }

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Solicitudes de Amistad',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_solicitudesPendientes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          'No tienes solicitudes pendientes.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _solicitudesPendientes.length,
                        itemBuilder: (context, i) {
                          final sol = _solicitudesPendientes[i];
                          final username = sol['username'] ?? 'Usuario';
                          final id = sol['id'];

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepOrange.shade100,
                              child: Text(
                                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                                style: TextStyle(
                                  color: Colors.deepOrange.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Te envió una solicitud'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                  tooltip: 'Aceptar',
                                  onPressed: () => responder(id, 'ACEPTAR'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 28),
                                  tooltip: 'Rechazar',
                                  onPressed: () => responder(id, 'RECHAZAR'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- AGREGAR NUEVO AMIGO ---
  void _mostrarDialogoAgregarAmigo() {
    final searchCtrl = TextEditingController();
    List<dynamic> resultados = [];
    bool buscando = false;
    String? feedback;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> buscar() async {
              final q = searchCtrl.text.trim();
              if (q.isEmpty) return;

              setModalState(() {
                buscando = true;
                feedback = null;
              });

              final res = await ApiService.buscarUsuarios(q);

              setModalState(() {
                buscando = false;
                resultados = res;
                if (res.isEmpty) feedback = 'No se encontró a nadie con ese nombre.';
              });
            }

            Future<void> agregar(String targetUser) async {
              final resp = await ApiService.enviarSolicitudAmistad(targetUser);
              setModalState(() {
                feedback = resp['detail'];
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 20,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Buscar nuevos amigos',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Nickname exacto o parcial...',
                            prefixIcon: Icon(Icons.person_search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => buscar(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: buscando ? null : buscar,
                        child: buscando
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text('Buscar'),
                      ),
                    ],
                  ),
                  if (feedback != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      feedback!,
                      style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: resultados.length,
                      itemBuilder: (context, i) {
                        final u = resultados[i];
                        final String username = u['username'] ?? '';
                        final bool esYo = username.toLowerCase() == widget.miUsername.toLowerCase();

                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(username),
                          trailing: esYo
                              ? const Chip(label: Text('Tú'))
                              : ElevatedButton(
                            onPressed: () => agregar(username),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Agregar'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- ELIMINAR AMIGO ---
  Future<void> _confirmarEliminarAmigo(int amigoId, String username) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar amigo'),
        content: Text('¿Seguro que deseas eliminar a $username de tu lista de amigos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final res = await ApiService.eliminarAmigo(amigoId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['detail'] ?? 'Acción realizada'),
          backgroundColor: res['exito'] == true ? Colors.green : Colors.redAccent,
        ),
      );

      if (res['exito'] == true) {
        _cargarTodo();
      }
    }
  }

  // --- RF-20: REPORTE DE CONDUCTA O CONTENIDO INAPROPIADO ---
  void _mostrarDialogoReporte(int usuarioId, String username) {
    String motivoSeleccionado = 'CONDUCTA_ANTIDEPORTIVA';
    final descripcionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Reportar a $username'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: motivoSeleccionado,
                  isExpanded: true, // <-- Evita el desbordamiento horizontal
                  decoration: const InputDecoration(
                    labelText: 'Motivo del reporte',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'CONDUCTA_ANTIDEPORTIVA',
                      child: Text('Conducta antideportiva', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'INASISTENCIA',
                      child: Text('Inasistencia / Ausencia', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'LENGUAJE_INAPROPIADO',
                      child: Text('Acoso o insultos', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'SPAM_FRAUDE',
                      child: Text('Spam o estafa', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'OTRO',
                      child: Text('Otro motivo', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => motivoSeleccionado = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descripcionCtrl,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    hintText: 'Describe el incidente para moderación...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final res = await ApiService.reportarUsuario(
                  reportadoId: usuarioId,
                  motivo: motivoSeleccionado,
                  descripcion: descripcionCtrl.text.trim(),
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['detail'] ?? 'Reporte procesado'),
                    backgroundColor: res['exito'] == true ? Colors.green : Colors.red,
                  ),
                );
              },
              child: const Text('Enviar Reporte'),
            ),
          ],
        ),
      ),
    );
  }

  // --- RF-21: BLOQUEO DE USUARIO ---
  Future<void> _confirmarBloqueo(int usuarioId, String username) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Bloquear a $username?'),
        content: const Text(
          'No podrá enviarte mensajes directos, solicitudes de amistad ni compartir partidos contigo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final exito = await ApiService.bloquearUsuario(usuarioId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exito ? 'Usuario bloqueado exitosamente.' : 'No se pudo bloquear al usuario.'),
          backgroundColor: exito ? Colors.black87 : Colors.red,
        ),
      );

      if (exito) {
        _cargarTodo();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigos'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.mail_outline),
                tooltip: 'Solicitudes recibidas',
                onPressed: _mostrarBandejaSolicitudes,
              ),
              if (_solicitudesPendientes.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${_solicitudesPendientes.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Agregar amigos',
            onPressed: _mostrarDialogoAgregarAmigo,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _busquedaLocalCtrl,
              onChanged: _filtrarAmigos,
              decoration: InputDecoration(
                hintText: 'Buscar entre mis amigos...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busquedaLocalCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _busquedaLocalCtrl.clear();
                    _filtrarAmigos('');
                  },
                )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _amigosFiltrados.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    _amigos.isEmpty
                        ? 'Aún no tienes amigos agregados.'
                        : 'No se encontraron resultados.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  if (_amigos.isEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _mostrarDialogoAgregarAmigo,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Buscar y agregar uno'),
                    ),
                  ],
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _cargarTodo,
              child: ListView.builder(
                itemCount: _amigosFiltrados.length,
                itemBuilder: (context, index) {
                  final amigo = _amigosFiltrados[index];
                  final String username = amigo['username'] ?? 'Usuario';
                  final int amigoId = amigo['id'] ?? 0;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    elevation: 1,
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PerfilAmigoScreen(
                              usuarioId: amigoId,
                              username: username,
                              miUsername: widget.miUsername,
                            ),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepOrange.shade100,
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : 'A',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange.shade900,
                          ),
                        ),
                      ),
                      title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text(
                        'Toca para ver perfil e historial',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, color: Colors.deepOrange),
                            tooltip: 'Enviar mensaje directo',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    titulo: 'Chat con $username',
                                    miUsername: widget.miUsername,
                                    amigoId: amigoId,
                                  ),
                                ),
                              );
                            },
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            tooltip: 'Opciones de amistad',
                            onSelected: (opcion) {
                              if (opcion == 'eliminar') {
                                _confirmarEliminarAmigo(amigoId, username);
                              } else if (opcion == 'reportar') {
                                _mostrarDialogoReporte(amigoId, username);
                              } else if (opcion == 'bloquear') {
                                _confirmarBloqueo(amigoId, username);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'eliminar',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_remove_outlined, color: Colors.redAccent, size: 20),
                                    SizedBox(width: 8),
                                    Text('Eliminar amigo'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'reportar',
                                child: Row(
                                  children: [
                                    Icon(Icons.flag_outlined, color: Colors.orange, size: 20),
                                    SizedBox(width: 8),
                                    Text('Reportar usuario'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'bloquear',
                                child: Row(
                                  children: [
                                    Icon(Icons.block, color: Colors.red, size: 20),
                                    SizedBox(width: 8),
                                    Text('Bloquear usuario', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}