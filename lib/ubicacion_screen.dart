import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UbicacionScreen extends StatefulWidget {
  const UbicacionScreen({super.key});

  @override
  State<UbicacionScreen> createState() => _UbicacionScreenState();
}

class _UbicacionScreenState extends State<UbicacionScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _ubicacionActual;
  String _direccionActual = 'Obteniendo dirección...';
  String _distancia = 'Calculando...';
  String _tiempo = 'Calculando...';

  LatLng _ubicacionPanaderia = const LatLng(-12.058342, -75.212435);
  String _nombrePanaderia = "Panadería Delicia";
  String _direccionPanaderia = "Jr. Parra del Riego 164, Huancayo";

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  bool _isLoading = true;
  StreamSubscription<Position>? _positionStream;
  bool _isFollowingUser = false;

  static const String _apiKey = 'AIzaSyAXtdVLVebFjqi55QdbyztUfH7HkFu81FM';

  @override
  void initState() {
    super.initState();

    // CARGAR DATOS + SIMULAR UBICACIÓN (SIN GPS)
    _cargarDatosPanaderia().then((_) {
      final simulacionUsuario = LatLng(-12.0595, -75.2140); // Cerca de la panadería

      setState(() {
        _ubicacionActual = simulacionUsuario;
        _isLoading = false;
        _distancia = "1.2 km";
        _tiempo = "8 min";
        _direccionActual = "Jr. Real 456, Huancayo";
      });

      _actualizarMarcadores();
      _dibujarRutaSimulada(simulacionUsuario);
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // CARGAR PANADERÍA DESDE FIRESTORE
  Future<void> _cargarDatosPanaderia() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Tienda')
          .doc('SQWncTFFC6dTcFbNiuBq')
          .get();

      if (!doc.exists || !mounted) return;

      final data = doc.data()!;
      final geoPoint = data['ubicacion'] as GeoPoint;

      setState(() {
        _ubicacionPanaderia = LatLng(geoPoint.latitude, geoPoint.longitude);
        _nombrePanaderia = data['nombre'] ?? _nombrePanaderia;
        _direccionPanaderia = data['direccion'] ?? _direccionPanaderia;
      });

      _actualizarMarcadores();
    } catch (e) {
      if (mounted) _mostrarError('Error cargando panadería: $e');
    }
  }

  // RUTA SIMULADA (SIN GPS)
  Future<void> _dibujarRutaSimulada(LatLng origen) async {
    final destino = _ubicacionPanaderia;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origen.latitude},${origen.longitude}'
          '&destination=${destino.latitude},${destino.longitude}'
          '&key=$_apiKey&mode=driving',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final points = route['overview_polyline']['points'];
          final polylinePoints = _decodePoly(points);

          final leg = route['legs'][0];
          setState(() {
            _distancia = leg['distance']['text'];
            _tiempo = leg['duration']['text'];
            _polylines = {
              Polyline(
                polylineId: const PolylineId('ruta_simulada'),
                color: Colors.blue,
                width: 6,
                points: polylinePoints,
              ),
            };
          });
          _actualizarMarcadores();
        }
      }
    } catch (e) {
      debugPrint("Error simulación: $e");
    }
  }

  // ACTUALIZAR MARCADORES
  void _actualizarMarcadores() {
    if (!mounted) return;

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('panaderia'),
          position: _ubicacionPanaderia,
          infoWindow: InfoWindow(
            title: _nombrePanaderia,
            snippet: _direccionPanaderia,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
        if (_ubicacionActual != null)
          Marker(
            markerId: const MarkerId('usuario'),
            position: _ubicacionActual!,
            infoWindow: InfoWindow(
              title: 'Tú estás aquí',
              snippet: '$_distancia • $_tiempo',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
      };
    });
  }

  // DECODIFICAR POLYLINE
  List<LatLng> _decodePoly(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  // ERROR SNACKBAR
  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ABRIR RUTA EN GOOGLE MAPS
  Future<void> _abrirRutaEnGoogleMaps() async {
    if (_ubicacionActual == null) {
      _mostrarError('Esperando ubicación...');
      return;
    }

    final url = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${_ubicacionActual!.latitude},${_ubicacionActual!.longitude}'
        '&destination=${_ubicacionPanaderia.latitude},${_ubicacionPanaderia.longitude}'
        '&travelmode=driving';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _mostrarError('No se pudo abrir Google Maps');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      appBar: AppBar(
        title: const Text('GPS a Panadería', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // MAPA DE PREVIA (SIEMPRE VISIBLE)
          GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: false, // DESACTIVADO (sin GPS)
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            markers: _markers,
            polylines: _polylines,
            initialCameraPosition: CameraPosition(
              target: _ubicacionPanaderia,
              zoom: 16,
            ),
            onMapCreated: (controller) {
              _controller.complete(controller);
            },
          ),

          // LOADER SOLO AL INICIO
          if (_isLoading)
            Container(
              color: Colors.grey[100]!.withOpacity(0.95),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.orange),
                    const SizedBox(height: 16),
                    Text(
                      'Cargando mapa...',
                      style: TextStyle(color: Colors.brown[700], fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          // BOTÓN GPS (COMENTADO)
          /*
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: "gps_button",
              backgroundColor: _isFollowingUser ? Colors.blue : Colors.white,
              elevation: 6,
              mini: true,
              onPressed: () {
                if (_isFollowingUser) {
                  _detenerSeguimiento();
                } else {
                  _seguirUsuario();
                }
              },
              child: Icon(
                _isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed,
                color: _isFollowingUser ? Colors.white : Colors.blue,
              ),
            ),
          ),
          */

          // BOTÓN DIRECCIONES
          Positioned(
            bottom: 160,
            right: 16,
            child: FloatingActionButton(
              heroTag: "go",
              backgroundColor: Colors.orange,
              elevation: 6,
              onPressed: _abrirRutaEnGoogleMaps,
              child: const Icon(Icons.directions, color: Colors.white),
            ),
          ),

          // TARJETA INFERIOR
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          _nombrePanaderia,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$_distancia • $_tiempo',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_direccionPanaderia, style: const TextStyle(color: Colors.brown)),
                  const Divider(height: 20),
                  const Text('Tu ubicación actual:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    _direccionActual,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
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