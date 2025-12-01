import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  Set<Circle> _circles = {};
  bool _isLoading = true;

  static const String _apiKey = 'TU_API_KEY_AQUI'; // Reemplaza con tu API Key real

  @override
  void initState() {
    super.initState();
    _cargarDatosPanaderia().then((_) {
      final simulacionUsuario = LatLng(-12.0595, -75.2140); // Cerca de la panadería
      
      setState(() {
        _ubicacionActual = simulacionUsuario;
        _isLoading = false;
      });
      
      _actualizarMarcadores();
      _dibujarRutaSimulada(simulacionUsuario);
      _obtenerDireccionDesdeCoordenadas(simulacionUsuario);
    });
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

  // OBTENER DIRECCIÓN DESDE COORDENADAS
  Future<void> _obtenerDireccionDesdeCoordenadas(LatLng coordenadas) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?'
      'latlng=${coordenadas.latitude},${coordenadas.longitude}'
      '&key=$_apiKey&language=es',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['results'].isNotEmpty) {
          final direccion = data['results'][0]['formatted_address'];
          setState(() {
            _direccionActual = direccion;
          });
        }
      }
    } catch (e) {
      debugPrint("Error obteniendo dirección: $e");
      setState(() {
        _direccionActual = "Ubicación cercana a la panadería";
      });
    }
  }

  // RUTA SIMULADA
  Future<void> _dibujarRutaSimulada(LatLng origen) async {
    final destino = _ubicacionPanaderia;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?'
      'origin=${origen.latitude},${origen.longitude}'
      '&destination=${destino.latitude},${destino.longitude}'
      '&key=$_apiKey&mode=driving&language=es',
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
                polylineId: const PolylineId('ruta_principal'),
                color: Colors.blue,
                width: 5,
                points: polylinePoints,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            };
          });
          _actualizarMarcadores();
          
          // Agregar círculo para mostrar radio de aproximación
          setState(() {
            _circles = {
              Circle(
                circleId: const CircleId('area_panaderia'),
                center: _ubicacionPanaderia,
                radius: 50, // 50 metros
                fillColor: Colors.green.withOpacity(0.2),
                strokeColor: Colors.green,
                strokeWidth: 2,
              ),
            };
          });
        }
      }
    } catch (e) {
      debugPrint("Error simulación: $e");
      // Usar distancia estimada como fallback
      setState(() {
        _distancia = "1.2 km aprox.";
        _tiempo = "8 min aprox.";
      });
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
            onTap: () {
              _abrirRutaEnGoogleMaps();
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          consumeTapEvents: true,
        ),
        if (_ubicacionActual != null)
          Marker(
            markerId: const MarkerId('usuario'),
            position: _ubicacionActual!,
            infoWindow: InfoWindow(
              title: 'Tu ubicación',
              snippet: '$_distancia • $_tiempo',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
      };
    });
  }

  // DECODIFICAR POLYLINE (método existente)
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

  // CENTRAR MAPA EN LA RUTA
  Future<void> _centrarMapaEnRuta() async {
    if (_ubicacionActual == null) return;
    
    final controller = await _controller.future;
    
    // Calcular bounds para incluir ambos puntos
    final bounds = LatLngBounds(
      southwest: LatLng(
        _ubicacionActual!.latitude < _ubicacionPanaderia.latitude 
          ? _ubicacionActual!.latitude 
          : _ubicacionPanaderia.latitude,
        _ubicacionActual!.longitude < _ubicacionPanaderia.longitude 
          ? _ubicacionActual!.longitude 
          : _ubicacionPanaderia.longitude,
      ),
      northeast: LatLng(
        _ubicacionActual!.latitude > _ubicacionPanaderia.latitude 
          ? _ubicacionActual!.latitude 
          : _ubicacionPanaderia.latitude,
        _ubicacionActual!.longitude > _ubicacionPanaderia.longitude 
          ? _ubicacionActual!.longitude 
          : _ubicacionPanaderia.longitude,
      ),
    );

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      appBar: AppBar(
        title: const Text('Ubicación de Panadería', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _centrarMapaEnRuta,
            icon: const Icon(Icons.center_focus_strong, color: Colors.white),
            tooltip: 'Centrar en ruta',
          ),
        ],
      ),
      body: Stack(
        children: [
          // GOOGLE MAPS
          GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            compassEnabled: true,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            markers: _markers,
            polylines: _polylines,
            circles: _circles,
            initialCameraPosition: CameraPosition(
              target: _ubicacionPanaderia,
              zoom: 16,
              tilt: 45,
              bearing: 30,
            ),
            onMapCreated: (controller) {
              _controller.complete(controller);
            },
          ),

          // LOADER
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.9),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      'Cargando mapa...',
                      style: TextStyle(color: Colors.brown, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          // BOTÓN DIRECCIONES
          Positioned(
            bottom: 160,
            right: 16,
            child: FloatingActionButton(
              heroTag: "direcciones",
              backgroundColor: Colors.orange,
              elevation: 8,
              onPressed: _abrirRutaEnGoogleMaps,
              child: const Icon(Icons.directions, color: Colors.white, size: 28),
            ),
          ),

          // TARJETA INFERIOR
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          _nombrePanaderia,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.brown,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Text(
                          '$_distancia • $_tiempo',
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _direccionPanaderia,
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, thickness: 1),
                  const Text(
                    'Tu ubicación actual:',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.brown),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.my_location, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _direccionActual,
                          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _abrirRutaEnGoogleMaps,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.directions),
                      label: const Text('Abrir en Google Maps', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
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