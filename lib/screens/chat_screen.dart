import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final String titulo;
  final String miUsername;
  final int? actividadId;
  final int? amigoId;

  const ChatScreen({
    super.key,
    required this.titulo,
    required this.miUsername,
    this.actividadId,
    this.amigoId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _mensajeCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<dynamic> _mensajes = [];
  bool _cargandoInicial = true;
  bool _enviando = false;
  Timer? _timerPolling;

  @override
  void initState() {
    super.initState();
    _cargarMensajes(esPrimeraVez: true);

    // Polling: consulta mensajes nuevos cada 3 segundos
    _timerPolling = Timer.periodic(const Duration(seconds: 3), (_) {
      _cargarMensajes(esPrimeraVez: false);
    });
  }

  @override
  void dispose() {
    _timerPolling?.cancel();
    _mensajeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarMensajes({bool esPrimeraVez = false}) async {
    final data = await ApiService.getMensajes(
      actividadId: widget.actividadId,
      amigoId: widget.amigoId,
    );

    if (!mounted) return;

    final int cantidadPrevia = _mensajes.length;

    setState(() {
      _mensajes = data;
      if (esPrimeraVez) _cargandoInicial = false;
    });

    // Baja automáticamente el scroll si llegaron mensajes nuevos
    if (data.length > cantidadPrevia) {
      _bajarScroll();
    }
  }

  void _bajarScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _mensajeCtrl.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() => _enviando = true);
    _mensajeCtrl.clear();

    final exito = await ApiService.enviarMensaje(
      actividadId: widget.actividadId,
      amigoId: widget.amigoId,
      contenido: texto,
    );

    if (mounted) {
      setState(() => _enviando = false);
      if (exito) {
        await _cargarMensajes();
        _bajarScroll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo enviar el mensaje.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
      ),
      body: Column(
        children: [
          Expanded(
            child: _cargandoInicial
                ? const Center(child: CircularProgressIndicator())
                : _mensajes.isEmpty
                ? Center(
              child: Text(
                'No hay mensajes aún.\n¡Sé el primero en escribir!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
                : ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _mensajes.length,
              itemBuilder: (context, index) {
                final msg = _mensajes[index];
                final emisor = msg['emisor_username'] ?? '';
                final bool esMio = emisor.toLowerCase() == widget.miUsername.toLowerCase();
                final contenido = msg['contenido'] ?? '';

                return Align(
                  alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: esMio ? Colors.deepOrange : Colors.grey.shade300,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(esMio ? 14 : 2),
                        bottomRight: Radius.circular(esMio ? 2 : 14),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!esMio && widget.actividadId != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              emisor,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        Text(
                          contenido,
                          style: TextStyle(
                            color: esMio ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mensajeCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: _enviando
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.send, color: Colors.deepOrange),
                    onPressed: _enviando ? null : _enviar,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}