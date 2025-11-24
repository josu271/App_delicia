import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Timer? _inactivityTimer;

  // 🟧 Timer de inactividad (5 minutos) - Solo para móvil
  void _startInactivityTimer() {
    if (kIsWeb) return; // No aplicar en web
    
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

  // 🟧 Detecta cuándo la app se pausa o vuelve - Solo para móvil
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return; // No aplicar en web
    
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
      // 🟧 DETECCIÓN WEB/MÓVIL: Web → AdminDashboard, Móvil → SplashScreen
      home: kIsWeb ? const AdminDashboard() : const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}

class MainApp extends StatefulWidget {
  final String userId;
  final String nombreUsuario;

  const MainApp({
    super.key,
    required this.userId,
    required this.nombreUsuario,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> carrito = [];
  Timer? _inactivityTimer;

  // 🟧 Timer de inactividad (5 minutos) - Solo para móvil
  void _startInactivityTimer() {
    if (kIsWeb) return; // No aplicar en web
    
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

  // 🟧 Detecta cuándo la app se pausa o vuelve - Solo para móvil
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return; // No aplicar en web
    
    if (state == AppLifecycleState.resumed) {
      _startInactivityTimer();
    } else if (state == AppLifecycleState.paused) {
      _inactivityTimer?.cancel();
    }
  }

  // 🟧 Función para agregar al carrito
  void _agregarAlCarrito(Map<String, dynamic> producto) {
    setState(() {
      final existente =
          carrito.indexWhere((p) => p['nombre'] == producto['nombre']);
      if (existente >= 0) {
        carrito[existente]['cantidad'] += producto['cantidad'];
        carrito[existente]['subtotal'] =
            carrito[existente]['cantidad'] * carrito[existente]['costo'];
      } else {
        carrito.add(producto);
      }
    });
  }

  // 🟧 Eliminar del carrito
  void _eliminarDelCarrito(String nombreProducto) {
    setState(() {
      carrito.removeWhere((p) => p['nombre'] == nombreProducto);
    });
  }

  // 🟧 Limpiar carrito
  void _limpiarCarrito() {
    setState(() {
      carrito.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🟧 En web, mostrar el panel administrativo directamente
    if (kIsWeb) {
      return const AdminDashboard();
    }

    // 🟧 En móvil, mostrar la app normal
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

        // 🟧 Logo + texto "Bienvenido"
        title: Row(
          children: [
            Image.asset(
              'assets/logo1.png',
              height: 35,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bienvenido ${widget.nombreUsuario}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        actions: [
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
                      carrito.fold<int>(
                        0,
                        (suma, item) => suma + (item['cantidad'] as int),
                      ).toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
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
          BottomNavigationBarItem(
              icon: Icon(Icons.location_on), label: 'Ubicación'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}