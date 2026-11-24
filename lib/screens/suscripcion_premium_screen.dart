import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class SuscripcionPremiumScreen extends StatefulWidget {
  const SuscripcionPremiumScreen({super.key});

  @override
  State<SuscripcionPremiumScreen> createState() => _SuscripcionPremiumScreenState();
}

class _SuscripcionPremiumScreenState extends State<SuscripcionPremiumScreen>
    with WidgetsBindingObserver {
  bool _cargando = true;
  bool _procesando = false;
  Map<String, dynamic>? _infoSuscripcion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarEstado();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Al volver del navegador tras pagar en Flow, refresca automáticamente el estado
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarEstado();
    }
  }

  Future<void> _cargarEstado() async {
    setState(() => _cargando = true);
    final data = await ApiService.getEstadoSuscripcion();
    if (!mounted) return;
    setState(() {
      _infoSuscripcion = data;
      _cargando = false;
    });
  }

  Future<void> _iniciarPagoFlow() async {
    setState(() => _procesando = true);
    final res = await ApiService.iniciarSuscripcionPremium();
    setState(() => _procesando = false);

    if (!mounted) return;

    if (res['exito'] == true && res['url'] != null) {
      final uri = Uri.parse(res['url']);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el navegador para completar el pago.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['detail'] ?? 'Error al conectar con Flow.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmarCancelacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar Suscripción Premium?'),
        content: const Text(
          'Se detendrán los cobros recurrentes de Flow y perderás los beneficios exclusivos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mantener Plan'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Cancelación', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _procesando = true);
    final res = await ApiService.cancelarSuscripcion();
    setState(() => _procesando = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['detail']),
        backgroundColor: res['exito'] ? Colors.green : Colors.red,
      ),
    );

    if (res['exito']) {
      _cargarEstado();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esPremium = _infoSuscripcion?['es_premium'] == true;
    final String estado = _infoSuscripcion?['estado'] ?? 'SIN_PLAN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('MatchDeportivo Premium'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarEstado,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tarjeta Estado Actual
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: esPremium
                      ? [Colors.deepOrange.shade600, Colors.amber.shade700]
                      : [Colors.grey.shade800, Colors.grey.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (esPremium ? Colors.deepOrange : Colors.black)
                        .withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        esPremium ? 'PLAN PREMIUM ACTIVO' : 'PLAN ESTÁNDAR (GRATUITO)',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        esPremium ? Icons.workspace_premium : Icons.person_outline,
                        color: Colors.amberAccent,
                        size: 28,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    esPremium ? 'Acceso Ilimitado' : 'Mejora tu Experiencia',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    esPremium
                        ? 'Tu suscripción se encuentra al día mediante Flow Sandbox.'
                        : 'Conéctate con más jugadores y organiza sin restricciones.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Beneficios del Plan Premium',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),

            _ItemBeneficio(
              icono: Icons.all_inclusive,
              titulo: 'Convocatorias Ilimitadas',
              subtitulo: 'Crea tantos partidos simultáneos como desees sin topes mensuales.',
            ),
            _ItemBeneficio(
              icono: Icons.star_half,
              titulo: 'Filtro por Reputación',
              subtitulo: 'Encuentra partidos con anfitriones y compañeros de alta calificación.',
            ),
            _ItemBeneficio(
              icono: Icons.verified,
              titulo: 'Insignia Deportiva Destacada',
              subtitulo: 'Distintivo Premium visible en tu perfil y listados de convocatorias.',
            ),
            _ItemBeneficio(
              icono: Icons.security,
              titulo: 'Pagos Seguros con Flow',
              subtitulo: 'Cobro automatizado mensual sin almacenar tarjetas en la aplicación.',
            ),

            const SizedBox(height: 28),

            if (!esPremium) ...[
              Card(
                elevation: 0,
                color: Colors.deepOrange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.deepOrange.shade200),
                ),
                child: const Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded( // <-- Envuelve la Column aquí
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Suscripción Mensual',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Renovación automática cancelable cuando quieras',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '\$4.990\nCLP/mes',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _procesando ? null : _iniciarPagoFlow,
                icon: _procesando
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.payment),
                label: Text(
                  _procesando ? 'Conectando con Flow...' : 'Suscribirme con Flow Sandbox',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _procesando ? null : _confirmarCancelacion,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text(
                  'Cancelar Suscripción Premium',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemBeneficio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;

  const _ItemBeneficio({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.deepOrange.shade100,
            child: Icon(icono, color: Colors.deepOrange, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}