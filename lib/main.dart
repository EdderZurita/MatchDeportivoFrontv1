import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/admin_usuarios_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/api_service.dart';
import 'screens/mapa_screen.dart';
import 'screens/mis_actividades_screen.dart';
import 'screens/crear_actividad_screen.dart';
import 'screens/recuperar_password_screen.dart';
import 'screens/amigos_screen.dart';
import 'screens/actividades_screen.dart';
import 'screens/suscripcion_premium_screen.dart';
import 'screens/admin_logs_screen.dart'; // RF-25: Pantalla de Auditoría

// Manejador de notificaciones cuando la app está cerrada o en segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (push) solo en Android/iOS. En web no hay FirebaseOptions
  // configuradas y la inicializacion rompia el arranque (pantalla en blanco).
  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  runApp(const MatchDeportivoApp());
}

class MatchDeportivoApp extends StatelessWidget {
  const MatchDeportivoApp({super.key});

  // Paleta Verde Césped Deportivo
  static const Color pastoVerdePrincipal = Color(0xFF2E7D32); // Verde pasto estándar
  static const Color pastoVerdeOscuro = Color(0xFF1B5E20);    // Verde césped profundo

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Match Deportivo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: pastoVerdePrincipal,
          primary: pastoVerdePrincipal,
          secondary: const Color(0xFF43A047),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _currentUser = '';

  final GlobalKey<MapaScreenState> _mapaKey = GlobalKey<MapaScreenState>();
  int _misPartidosVersion = 0;
  int _listaVersion = 0;

  @override
  void initState() {
    super.initState();
    _sincronizarUsuario();
  }

  Future<void> _sincronizarUsuario() async {
    final user = await ApiService.getUsername();
    if (mounted) {
      setState(() {
        _currentUser = user ?? '';
      });
      if (_currentUser.isNotEmpty) {
        _configurarNotificacionesPush();
      }
    }
  }

  // RF-17: Configuración de permisos, registro de token FCM y recepción de alertas
  Future<void> _configurarNotificacionesPush() async {
    if (kIsWeb) return; // push no disponible sin configuracion web de Firebase
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // ignore: deprecated_member_use
        final token = await messaging.getToken();
        if (token != null) {
          await ApiService.registrarTokenFCM(token);
        }

        // ignore: deprecated_member_use
        messaging.onTokenRefresh.listen((nuevoToken) async {
          await ApiService.registrarTokenFCM(nuevoToken);
        });

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.notification != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.notification!.title ?? 'Match Deportivo',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (message.notification!.body != null)
                            Text(
                              message.notification!.body!,
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF1B5E20),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error configurando Firebase Messaging: $e');
    }
  }

  void _refrescarPestana(int index, bool estaLogueado) {
    if (index == 0) {
      _mapaKey.currentState?.cargarDatos();
    } else if (estaLogueado && index == 1) {
      setState(() => _misPartidosVersion++);
    } else if ((estaLogueado && index == 2) || (!estaLogueado && index == 1)) {
      setState(() => _listaVersion++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool estaLogueado = _currentUser.isNotEmpty;

    final List<Widget> pages = estaLogueado
        ? [
      MapaScreen(key: _mapaKey),
      MisActividadesScreen(
        key: ValueKey('mis_partidos_$_misPartidosVersion'),
        miUsername: _currentUser,
      ),
      ActividadesScreen(
        key: ValueKey('lista_$_listaVersion'),
      ),
      AmigosScreen(
        key: ValueKey('amigos_$_currentUser'),
        miUsername: _currentUser,
      ),
      LoginScreen(
        onLoginSuccess: () {
          _sincronizarUsuario();
          setState(() {
            _misPartidosVersion++;
            _listaVersion++;
            _selectedIndex = 0;
          });
          _mapaKey.currentState?.cargarDatos();
        },
      ),
    ]
        : [
      MapaScreen(key: _mapaKey),
      ActividadesScreen(
        key: ValueKey('lista_$_listaVersion'),
      ),
      LoginScreen(
        onLoginSuccess: () {
          _sincronizarUsuario();
          setState(() {
            _misPartidosVersion++;
            _listaVersion++;
            _selectedIndex = 0;
          });
          _mapaKey.currentState?.cargarDatos();
        },
      ),
      const RegistroScreen(),
    ];

    final List<NavigationDestination> destinations = estaLogueado
        ? const [
      NavigationDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map),
        label: 'Mapa',
      ),
      NavigationDestination(
        icon: Icon(Icons.sports_outlined),
        selectedIcon: Icon(Icons.sports),
        label: 'Mis Partidos',
      ),
      NavigationDestination(
        icon: Icon(Icons.format_list_bulleted),
        selectedIcon: Icon(Icons.list_alt),
        label: 'Lista',
      ),
      NavigationDestination(
        icon: Icon(Icons.people_alt_outlined),
        selectedIcon: Icon(Icons.people_alt),
        label: 'Amigos',
      ),
      NavigationDestination(
        icon: Icon(Icons.account_circle_outlined),
        selectedIcon: Icon(Icons.account_circle),
        label: 'Mi Cuenta',
      ),
    ]
        : const [
      NavigationDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map),
        label: 'Mapa',
      ),
      NavigationDestination(
        icon: Icon(Icons.format_list_bulleted),
        selectedIcon: Icon(Icons.list_alt),
        label: 'Lista',
      ),
      NavigationDestination(
        icon: Icon(Icons.login),
        selectedIcon: Icon(Icons.verified_user),
        label: 'Sesión',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_add_outlined),
        selectedIcon: Icon(Icons.person_add),
        label: 'Registro',
      ),
    ];

    final int safeIndex = _selectedIndex < pages.length ? _selectedIndex : 0;

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton.extended(heroTag: 'fab_home_crear',
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        onPressed: () async {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          final token = await ApiService.getAccessToken();
          if (!mounted) return;

          if (token == null || token.isEmpty) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Debes iniciar sesión para publicar una actividad.'),
                backgroundColor: Colors.redAccent,
              ),
            );
            setState(() => _selectedIndex = estaLogueado ? 4 : 2);
            return;
          }

          final creada = await navigator.push(
            MaterialPageRoute(builder: (_) => const CrearActividadScreen()),
          );
          if (!mounted) return;

          if (creada == true) {
            _mapaKey.currentState?.cargarDatos();
            setState(() {
              _misPartidosVersion++;
              _listaVersion++;
            });
          }
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Crear Partido'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        indicatorColor: Colors.green.shade200,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _sincronizarUsuario();
          _refrescarPestana(index, estaLogueado);
        },
        destinations: destinations,
      ),
    );
  }
}

// ==========================================
// PANTALLA: REGISTRO DE USUARIOS
// ==========================================
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _cargando = false;
  bool _ocultarPassword = true;
  bool _ocultarConfirmPassword = true;
  String? _mensajeRespuesta;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _solicitarRegistro() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _mostrarTerminosYCondiciones();
  }

  void _mostrarTerminosYCondiciones() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.gavel_rounded, color: Color(0xFF2E7D32)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Términos y Condiciones',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenido a MatchDeportivo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Convivencia y Respeto:\n'
                        'Al registrarte, te comprometes a fomentar un ambiente deportivo, respetuoso y seguro tanto en la cancha como en los chats de equipo.\n\n'
                        '2. Asistencia y Compromiso:\n'
                        'La confirmación de asistencia a una actividad representa un compromiso con el organizador y el resto de los participantes. Las ausencias reiteradas sin aviso previo afectarán tu reputación.\n\n'
                        '3. Datos y Geolocalización (Ley N° 21.719):\n'
                        'Tus datos de comuna y ubicación se emplean únicamente para calcular la afinidad y distancia en el motor de matchmaking. No se compartirán públicamente con fines comerciales.\n\n'
                        '4. Responsabilidad:\n'
                        'MatchDeportivo actúa exclusivamente como plataforma de encuentro y coordinación comunitaria. La participación física en recintos deportivos es de carácter voluntario y bajo responsabilidad individual.\n\n'
                        '5. Contacto y Soporte:\n'
                        'Para dudas, reportes o solicitudes sobre tus datos personales, escríbenos a matchdeportivo2000@gmail.com.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Rechazar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _ejecutarRegistro();
              },
              child: const Text('Acepto y Registrarme'),
            ),
          ],
        );
      },
    );
  }

  String _formatearErroresRegistro(dynamic errores) {
    if (errores is Map) {
      final List<String> mensajes = [];
      errores.forEach((campo, valor) {
        final texto = (valor is List && valor.isNotEmpty)
            ? valor.join(' ')
            : valor.toString();

        if (campo == 'username') {
          mensajes.add('• Usuario: $texto');
        } else if (campo == 'email') {
          mensajes.add('• Correo: $texto');
        } else if (campo == 'password') {
          mensajes.add('• Contraseña: $texto');
        } else if (campo == 'detail') {
          mensajes.add(texto);
        } else {
          mensajes.add('• $texto');
        }
      });
      if (mensajes.isNotEmpty) return mensajes.join('\n');
    }
    return errores?.toString() ?? 'No se pudo completar el registro.';
  }

  Future<void> _ejecutarRegistro() async {
    setState(() {
      _cargando = true;
      _mensajeRespuesta = null;
    });

    final resultado = await ApiService.registrarUsuario({
      'username': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text,
    });

    if (!mounted) return;
    setState(() => _cargando = false);

    if (resultado['exito'] == true) {
      setState(() => _mensajeRespuesta = '¡Usuario registrado con éxito! Inicia sesión para continuar.');
      _usernameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    } else {
      setState(() => _mensajeRespuesta = _formatearErroresRegistro(resultado['errores']));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de Usuario')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Usuario *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico *',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Requerido';
                  if (!val.contains('@') || !val.contains('.')) return 'Ingresa un correo válido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _ocultarPassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña (mínimo 8 caracteres) *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_ocultarPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Requerido';
                  if (val.length < 8) return 'Mínimo 8 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _ocultarConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirmar Contraseña *',
                  prefixIcon: const Icon(Icons.lock_reset),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_ocultarConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _ocultarConfirmPassword = !_ocultarConfirmPassword),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Requerido';
                  if (val != _passwordController.text) return 'Las contraseñas no coinciden';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _cargando ? null : _solicitarRegistro,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _cargando
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Crear Cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              if (_mensajeRespuesta != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _mensajeRespuesta!.contains('éxito')
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _mensajeRespuesta!.contains('éxito')
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                    ),
                  ),
                  child: Text(
                    _mensajeRespuesta!,
                    style: TextStyle(
                      color: _mensajeRespuesta!.contains('éxito')
                          ? Colors.green.shade900
                          : Colors.red.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: _mensajeRespuesta!.contains('éxito')
                        ? TextAlign.center
                        : TextAlign.left,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA: LOGIN Y GESTIÓN DE PERFIL (RF-3, RF-25)
// ==========================================
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _correoSoporte = 'matchdeportivo2000@gmail.com';
  bool _modoEdicion = false;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _biografiaController = TextEditingController();
  String? _comunaSeleccionada;
  String _deporteFavorito = 'Fútbol';
  String _nivelHabilidad = 'PRINCIPIANTE';

  bool _cargando = false;
  bool _cargandoPerfil = false;
  bool _guardandoPerfil = false;
  String? _mensaje;
  String? _sesionActiva;
  Map<String, dynamic>? _datosPerfil;

  final List<String> _comunasSantiago = [
    'Cerrillos',
    'Cerro Navia',
    'Conchalí',
    'El Bosque',
    'Estación Central',
    'Huechuraba',
    'Independencia',
    'La Cisterna',
    'La Florida',
    'La Granja',
    'La Pintana',
    'La Reina',
    'Las Condes',
    'Lo Barnechea',
    'Lo Espejo',
    'Lo Prado',
    'Macul',
    'Maipú',
    'Ñuñoa',
    'Pedro Aguirre Cerda',
    'Peñalolén',
    'Providencia',
    'Pudahuel',
    'Puente Alto',
    'Quilicura',
    'Quinta Normal',
    'Recoleta',
    'Renca',
    'San Bernardo',
    'San Joaquín',
    'San Miguel',
    'San Ramón',
    'Santiago',
    'Vitacura',
  ]..sort();

  final List<String> _listaDeportes = [
    'Fútbol',
    'Básquetbol',
    'Pádel',
    'Tenis',
    'Voleibol',
    'Running',
    'Otro',
  ];

  final Map<String, String> _niveles = {
    'PRINCIPIANTE': 'Principiante',
    'INTERMEDIO': 'Intermedio',
    'AVANZADO': 'Avanzado',
  };

  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _biografiaController.dispose();
    super.dispose();
  }

  void _copiarCorreoSoporte() {
    Clipboard.setData(const ClipboardData(text: _correoSoporte));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Correo de soporte copiado: $_correoSoporte'),
        backgroundColor: Color(0xFF2E7D32),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _verificarSesion() async {
    final user = await ApiService.getUsername();
    if (mounted) {
      setState(() => _sesionActiva = user);
      if (user != null && user.isNotEmpty) {
        _cargarPerfil();
      }
    }
  }

  Future<void> _cargarPerfil() async {
    setState(() => _cargandoPerfil = true);
    final perfil = await ApiService.getMiPerfil();
    if (!mounted) return;

    if (perfil != null) {
      setState(() {
        _datosPerfil = perfil;
        _biografiaController.text = perfil['biografia'] ?? '';

        final comunaBackend = perfil['comuna'] ?? '';
        if (_comunasSantiago.contains(comunaBackend)) {
          _comunaSeleccionada = comunaBackend;
        } else {
          _comunaSeleccionada = _comunasSantiago.first;
        }

        final dep = perfil['deporte_favorito'] ?? '';
        if (_listaDeportes.contains(dep)) {
          _deporteFavorito = dep;
        }

        final niv = perfil['nivel_habilidad'] ?? 'PRINCIPIANTE';
        if (_niveles.containsKey(niv)) {
          _nivelHabilidad = niv;
        }

        _cargandoPerfil = false;
      });
    } else {
      setState(() => _cargandoPerfil = false);
    }
  }

  Future<void> _guardarPerfil() async {
    setState(() => _guardandoPerfil = true);

    final exito = await ApiService.actualizarMiPerfil({
      'comuna': _comunaSeleccionada ?? '',
      'deporte_favorito': _deporteFavorito,
      'nivel_habilidad': _nivelHabilidad,
      'biografia': _biografiaController.text.trim(),
    });

    if (!mounted) return;
    setState(() {
      _guardandoPerfil = false;
      if (exito) _modoEdicion = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(exito
            ? '¡Perfil deportivo actualizado con éxito!'
            : 'Error al actualizar el perfil.'),
        backgroundColor: exito ? const Color(0xFF2E7D32) : Colors.red,
      ),
    );

    if (exito) _cargarPerfil();
  }

  void _cancelarEdicion() {
    setState(() {
      _modoEdicion = false;
      if (_datosPerfil != null) {
        _biografiaController.text = _datosPerfil!['biografia'] ?? '';
        final comunaBackend = _datosPerfil!['comuna'] ?? '';
        if (_comunasSantiago.contains(comunaBackend)) {
          _comunaSeleccionada = comunaBackend;
        }
        final dep = _datosPerfil!['deporte_favorito'] ?? '';
        if (_listaDeportes.contains(dep)) {
          _deporteFavorito = dep;
        }
        final niv = _datosPerfil!['nivel_habilidad'] ?? 'PRINCIPIANTE';
        if (_niveles.containsKey(niv)) {
          _nivelHabilidad = niv;
        }
      }
    });
  }

  Future<void> _hacerLogin() async {
    setState(() {
      _cargando = true;
      _mensaje = null;
    });

    final user = _usernameController.text.trim();
    final pass = _passwordController.text;
    final exito = await ApiService.login(user, pass);

    setState(() {
      _cargando = false;
      if (exito) {
        _mensaje = '¡Inicio de sesión exitoso!';
        _sesionActiva = user;
        _modoEdicion = false;
        widget.onLoginSuccess();
        _cargarPerfil();
      } else {
        _mensaje = 'Credenciales inválidas o problema de conexión.';
      }
    });
  }

  Future<void> _cerrarSesion() async {
    await ApiService.logout();
    setState(() {
      _sesionActiva = null;
      _datosPerfil = null;
      _modoEdicion = false;
      _mensaje = 'Sesión cerrada.';
    });
    widget.onLoginSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_sesionActiva != null
            ? (_modoEdicion ? 'Editar Perfil' : 'Mi Perfil Deportivo')
            : 'Iniciar Sesión'),
        actions: [
          if (_sesionActiva != null && !_modoEdicion)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar perfil',
              onPressed: _cargarPerfil,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: _sesionActiva != null
            ? (_modoEdicion ? _buildFormularioEdicion() : _buildVistaLectura())
            : _buildLoginView(),
      ),
    );
  }

  Widget _buildVistaLectura() {
    if (_cargandoPerfil) {
      return const Padding(
        padding: EdgeInsets.only(top: 80.0),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
      );
    }

    final reputacion = _datosPerfil?['reputacion_promedio'] ?? '5.00';
    final esPremium = _datosPerfil?['es_premium'] ?? false;
    final bool esStaff = _datosPerfil?['is_staff'] == true || _datosPerfil?['is_superuser'] == true;
    final email = _datosPerfil?['email'] ?? '';
    final comuna = _datosPerfil?['comuna'] ?? 'Sin comuna asignada';
    final deporte = _datosPerfil?['deporte_favorito'] ?? 'No especificado';
    final nivelDisplay = _niveles[_datosPerfil?['nivel_habilidad']] ?? 'Principiante';
    final bio = (_datosPerfil?['biografia'] ?? '').toString().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              // Avatar con degradado de pasto
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: Colors.transparent,
                  child: Text(
                    _sesionActiva!.isNotEmpty ? _sesionActiva![0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _sesionActiva!,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '$reputacion',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: esPremium ? Colors.amber.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      esPremium ? 'Plan Premium' : 'Plan Gratuito',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: esPremium ? Colors.amber.shade900 : const Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ficha Deportiva',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on, color: Color(0xFF2E7D32)),
                  title: const Text('Comuna / Sector habitual', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  subtitle: Text(
                    comuna.isNotEmpty ? comuna : 'Sin comuna asignada',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sports_soccer, color: Color(0xFF2E7D32)),
                  title: const Text('Deporte Principal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  subtitle: Text(
                    deporte,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fitness_center, color: Color(0xFF2E7D32)),
                  title: const Text('Nivel de Habilidad', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  subtitle: Row(
                    children: [
                      Chip(
                        label: Text(nivelDisplay),
                        backgroundColor: Colors.green.shade50,
                        labelStyle: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Biografía Atlética:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  bio.isNotEmpty ? bio : 'No has agregado una descripción atlética aún.',
                  style: TextStyle(
                    fontSize: 14,
                    color: bio.isNotEmpty ? Colors.black87 : Colors.grey.shade500,
                    fontStyle: bio.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // RF-22, RF-23, RF-24: Acceso a Gestión de Suscripción Premium
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: esPremium ? Colors.amber.shade400 : Colors.green.shade300,
              width: 1.2,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: esPremium ? Colors.amber.shade100 : Colors.green.shade100,
              child: Icon(
                Icons.workspace_premium,
                color: esPremium ? Colors.amber.shade900 : const Color(0xFF2E7D32),
              ),
            ),
            title: Text(
              esPremium ? 'Membresía Premium Activa' : 'MatchDeportivo Premium',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              esPremium
                  ? 'Gestionar plan y facturación con Flow'
                  : 'Creación ilimitada y filtros avanzados por \$4.990/mes',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SuscripcionPremiumScreen()),
              );
              _cargarPerfil();
            },
          ),
        ),

        const SizedBox(height: 12),

        // Tarjeta de Contacto y Soporte
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade50,
              child: const Icon(Icons.support_agent, color: Color(0xFF2E7D32)),
            ),
            title: const Text(
              'Contacto y Soporte',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: const Text(
              _correoSoporte,
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
              tooltip: 'Copiar correo',
              onPressed: _copiarCorreoSoporte,
            ),
            onTap: _copiarCorreoSoporte,
          ),
        ),

        // PANEL EXCLUSIVO PARA ADMINISTRADORES / STAFF (RF-25 y RF-26)
        if (esStaff) ...[
          const SizedBox(height: 12),

          // RF-25: Auditoría y Logs
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF1B5E20), width: 1.2),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.admin_panel_settings, color: Color(0xFF1B5E20)),
              ),
              title: const Text(
                'Auditoría y Logs del Sistema (RF-25)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Supervisar registros de seguridad, cobros y actividad global',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminLogsScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // RF-26: Gestión y Suspensión de Cuentas
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF1B5E20), width: 1.2),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.manage_accounts, color: Color(0xFF1B5E20)),
              ),
              title: const Text(
                'Gestión de Cuentas de Usuario (RF-26)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Suspender o reactivar cuentas por infracciones comunitarias',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminUsuariosScreen()),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => setState(() => _modoEdicion = true),
          icon: const Icon(Icons.edit),
          label: const Text('Editar Perfil Deportivo', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _cerrarSesion,
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFormularioEdicion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Actualizar Información',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Selecciona tus preferencias oficiales para mejorar el matchmaking.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _comunaSeleccionada,
          decoration: const InputDecoration(
            labelText: 'Comuna Habitual',
            prefixIcon: Icon(Icons.location_on_outlined),
            border: OutlineInputBorder(),
          ),
          items: _comunasSantiago.map((com) {
            return DropdownMenuItem(value: com, child: Text(com));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _comunaSeleccionada = val);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _deporteFavorito,
          decoration: const InputDecoration(
            labelText: 'Deporte Principal',
            prefixIcon: Icon(Icons.sports_soccer),
            border: OutlineInputBorder(),
          ),
          items: _listaDeportes.map((dep) {
            return DropdownMenuItem(value: dep, child: Text(dep));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _deporteFavorito = val);
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Nivel de Habilidad:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _niveles.entries.map((entry) {
            final sel = _nivelHabilidad == entry.key;
            return ChoiceChip(
              label: Text(entry.value),
              selected: sel,
              selectedColor: Colors.green.shade200,
              onSelected: (val) {
                if (val) setState(() => _nivelHabilidad = entry.key);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _biografiaController,
          maxLines: 3,
          maxLength: 400,
          decoration: const InputDecoration(
            labelText: 'Biografía / Descripción atlética',
            hintText: 'Cuéntale a otros jugadores tu disponibilidad, posición o perfil deportivo...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _guardandoPerfil ? null : _guardarPerfil,
          icon: _guardandoPerfil
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Icon(Icons.save),
          label: const Text('Guardar Cambios', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _guardandoPerfil ? null : _cancelarEdicion,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLoginView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.sports_soccer, size: 70, color: Color(0xFF2E7D32)),
        const SizedBox(height: 16),
        const Text(
          'Bienvenido a MatchDeportivo',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa para gestionar tus partidos y tu perfil.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _usernameController,
          decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _cargando ? null : _hacerLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _cargando
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Iniciar Sesión'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RecuperarPasswordScreen(),
              ),
            );
          },
          child: const Text(
            '¿Olvidaste tu contraseña?',
            style: TextStyle(color: Color(0xFF2E7D32)),
          ),
        ),
        if (_mensaje != null) ...[
          const SizedBox(height: 16),
          Text(
            _mensaje!,
            style: TextStyle(
              color: _mensaje!.contains('exitoso') ? const Color(0xFF2E7D32) : Colors.red,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        InkWell(
          onTap: _copiarCorreoSoporte,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                Text(
                  '¿Necesitas ayuda con tu cuenta?',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email_outlined, size: 15, color: Color(0xFF2E7D32)),
                    SizedBox(width: 6),
                    Text(
                      _correoSoporte,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}