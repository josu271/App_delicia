import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'login_screen.dart';
import 'register_screen.dart';
import 'catalog_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'historial_screen.dart';
import 'ubicacion_screen.dart';
import 'splash_screen.dart';
import 'admin_dashboard.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print("Error inicializando Firebase: $e");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Timer? _inactivityTimer;

  void _startInactivityTimer() {
    if (kIsWeb) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 5), () {
      FirebaseAuth.instance.signOut();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startInactivityTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (state == AppLifecycleState.resumed) {
      _startInactivityTimer();
    } else if (state == AppLifecycleState.paused) {
      _inactivityTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delicia App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (kIsWeb) {
            return const AdminDashboard();
          }
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          
          // Usuario autenticado - ir a MainApp
          if (snapshot.hasData) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('UsuariosPanaderia')
                  .doc(snapshot.data!.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                }
                
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  return MainApp(
                    userId: snapshot.data!.uid,
                    nombreUsuario: userData['nombre'] ?? 'Usuario',
                  );
                } else {
                  // Si no encuentra datos, ir al catálogo público
                  return const PublicCatalogScreen();
                }
              },
            );
          }
          
          // Usuario no autenticado - ir al catálogo público
          return const PublicCatalogScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}

// 🟢 CATÁLOGO PÚBLICO - Para usuarios no autenticados
class PublicCatalogScreen extends StatefulWidget {
  const PublicCatalogScreen({super.key});

  @override
  State<PublicCatalogScreen> createState() => _PublicCatalogScreenState();
}

class _PublicCatalogScreenState extends State<PublicCatalogScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> carrito = [];

  // 🟢 Manejar agregar al carrito con verificación de login
  void _manejarAgregarAlCarrito(Map<String, dynamic> producto) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      _mostrarDialogoLogin();
    } else {
      // Si ya está autenticado, redirigir al MainApp con el producto
      _navegarAMainAppConProducto(producto);
    }
  }

  void _mostrarDialogoLogin() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar Sesión Requerido'),
        content: const Text('Debes iniciar sesión para agregar productos al carrito.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Iniciar Sesión'),
          ),
        ],
      ),
    );
  }

  void _navegarAMainAppConProducto(Map<String, dynamic> producto) {
    // Obtener datos del usuario para pasar a MainApp
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('UsuariosPanaderia')
          .doc(user.uid)
          .get()
          .then((doc) {
        if (doc.exists) {
          final userData = doc.data()!;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainApp(
                userId: user.uid,
                nombreUsuario: userData['nombre'] ?? 'Usuario',
                productoParaAgregar: producto, // 🟢 Pasar producto para agregar
              ),
            ),
          );
        }
      });
    }
  }

  // 🟢 Pantallas para usuarios no autenticados
  List<Widget> get _screens {
    return [
      CatalogScreen(
        onAddToCart: _manejarAgregarAlCarrito,
        carritoActual: carrito,
      ),
      const UbicacionScreen(),
      const PublicProfileScreen(), // 🟢 Perfil público
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Row(
          children: [
            Image.asset('assets/logo1.png', height: 35),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Panadería Delicia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          // 🟢 Carrito visible pero requiere login
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                _mostrarDialogoLogin();
              } else {
                _navegarAMainApp();
              }
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.cake), label: 'Catálogo'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Ubicación'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  void _navegarAMainApp() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('UsuariosPanaderia')
          .doc(user.uid)
          .get()
          .then((doc) {
        if (doc.exists) {
          final userData = doc.data()!;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainApp(
                userId: user.uid,
                nombreUsuario: userData['nombre'] ?? 'Usuario',
              ),
            ),
          );
        }
      });
    }
  }
}

// 🟢 PERFIL PÚBLICO
class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 60,
                backgroundColor: Colors.orange,
                child: Icon(Icons.person, size: 70, color: Colors.white),
              ),
              const SizedBox(height: 30),
              const Text(
                'Inicia sesión en tu cuenta',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              const Text(
                'Accede a tu perfil personalizado, historial de compras y gestiona tu información',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                child: const Text(
                  '¿No tienes cuenta? Regístrate aquí',
                  style: TextStyle(fontSize: 16, color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🟢 MAIN APP - Para usuarios autenticados
class MainApp extends StatefulWidget {
  final String userId;
  final String nombreUsuario;
  final Map<String, dynamic>? productoParaAgregar; // 🟢 Producto para agregar automáticamente

  const MainApp({
    super.key,
    required this.userId,
    required this.nombreUsuario,
    this.productoParaAgregar,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> carrito = [];
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startInactivityTimer();
    
    // 🟢 Si hay producto para agregar, agregarlo al carrito
    if (widget.productoParaAgregar != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _agregarAlCarrito(widget.productoParaAgregar!);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _startInactivityTimer() {
    if (kIsWeb) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 5), () {
      FirebaseAuth.instance.signOut();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (state == AppLifecycleState.resumed) {
      _startInactivityTimer();
    } else if (state == AppLifecycleState.paused) {
      _inactivityTimer?.cancel();
    }
  }

  // 🟢 Funciones del carrito
  void _agregarAlCarrito(Map<String, dynamic> producto) {
    setState(() {
      final existente = carrito.indexWhere((p) => p['nombre'] == producto['nombre']);
      if (existente >= 0) {
        carrito[existente]['cantidad'] += producto['cantidad'];
        carrito[existente]['subtotal'] = carrito[existente]['cantidad'] * carrito[existente]['costo'];
      } else {
        carrito.add(producto);
      }
    });
  }

  void _eliminarDelCarrito(String nombreProducto) {
    setState(() {
      carrito.removeWhere((p) => p['nombre'] == nombreProducto);
    });
  }

  void _limpiarCarrito() {
    setState(() {
      carrito.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const AdminDashboard();
    }

    final List<Widget> _screens = [
      CatalogScreen(
        onAddToCart: _agregarAlCarrito,
        carritoActual: carrito,
      ),
      const UbicacionScreen(),
      ProfileScreen(userId: widget.userId),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Row(
          children: [
            Image.asset('assets/logo1.png', height: 35),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bienvenido ${widget.nombreUsuario}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // 🟢 Carrito siempre visible con contador
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CartScreen(
                        carrito: carrito,
                        onClearCart: _limpiarCarrito,
                        onDeleteItem: _eliminarDelCarrito,
                        userId: widget.userId,
                      ),
                    ),
                  );
                },
              ),
              if (carrito.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.red,
                    child: Text(
                      carrito.fold<int>(0, (suma, item) => suma + (item['cantidad'] as int)).toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.cake), label: 'Catálogo'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Ubicación'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}