import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CatalogScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onAddToCart;
  final List<Map<String, dynamic>> carritoActual;

  const CatalogScreen({
    super.key,
    required this.onAddToCart,
    required this.carritoActual,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> productos = [];
  List<Map<String, dynamic>> filtrados = [];
  String categoriaSeleccionada = 'Todos';
  String query = "";

  late AnimationController _iconAnimationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    cargarProductos();

    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _iconAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    super.dispose();
  }

  // 🔹 Convierte enlaces de Google Drive en links directos
  String convertirEnlaceDriveADirecto(String enlaceDrive) {
    final regExp = RegExp(r'/d/([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(enlaceDrive);
    if (match != null && match.groupCount >= 1) {
      final id = match.group(1);
      return 'https://drive.google.com/uc?export=view&id=$id';
    } else {
      return enlaceDrive;
    }
  }

  // 🔸 Cargar productos desde Firestore
  Future<void> cargarProductos() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('ProductosPanaderia').get();

    setState(() {
      productos = snapshot.docs.map((doc) {
        final data = doc.data();
        final imagenUrl = data.containsKey('imagen')
            ? convertirEnlaceDriveADirecto(data['imagen'])
            : null;
        return {...data, 'imagen': imagenUrl};
      }).toList();
      filtrados = productos;
    });
  }

  // 🔸 Filtrar por texto
  void filtrarProductos(String texto) {
    setState(() {
      query = texto;
      aplicarFiltros();
    });
  }

  // 🔸 Filtrar por categoría
  void filtrarPorCategoria(String categoria) {
    setState(() {
      categoriaSeleccionada = categoria;
      aplicarFiltros();
    });
  }

  // 🔸 Aplica ambos filtros (texto y categoría)
  void aplicarFiltros() {
    List<Map<String, dynamic>> resultado = productos;

    if (categoriaSeleccionada != 'Todos') {
      resultado = resultado
          .where((p) =>
              (p['categoria']?.toString().toLowerCase() ?? '') ==
              categoriaSeleccionada.toLowerCase())
          .toList();
    }

    if (query.isNotEmpty) {
      resultado = resultado
          .where((p) =>
              (p['nombre']?.toLowerCase() ?? '').contains(query.toLowerCase()))
          .toList();
    }

    filtrados = resultado;
  }

  // 🔸 Diálogo con detalles del producto
  void mostrarFormularioProducto(Map<String, dynamic> producto) {
    int cantidad = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setLocalState) {
          return AlertDialog(
            title: Text(
              producto['nombre'],
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.brown),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (producto['imagen'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      producto['imagen'],
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  producto['descripcion'] ?? 'Sin descripción disponible.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 15),

                // 🔸 CONTADOR DE CANTIDAD
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        if (cantidad > 1) {
                          setLocalState(() {
                            cantidad--;
                          });
                        }
                      },
                    ),
                    Text(
                      '$cantidad',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () {
                        setLocalState(() {
                          cantidad++;
                        });
                      },
                    ),
                  ],
                ),

                // 🟧 NUEVO: TOTAL A PAGAR EN TIEMPO REAL
                const SizedBox(height: 10),
                Text(
                  'Total a pagar: S/. ${(cantidad * (producto["costo"] ?? 0)).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),

              // BOTÓN AGREGAR
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                ),
                onPressed: () {
                  _iconAnimationController.forward().then((_) {
                    _iconAnimationController.reverse();
                  });

                  widget.onAddToCart({
                    'nombre': producto['nombre'],
                    'descripcion': producto['descripcion'],
                    'costo': producto['costo'],
                    'cantidad': cantidad,
                    'subtotal': cantidad * producto['costo'],
                  });

                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '${producto['nombre']} x$cantidad agregado al carrito'),
                    duration: const Duration(seconds: 1),
                  ));

                  Navigator.pop(context);
                },
                child: const Text(
                  'Agregar al carrito',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      appBar: AppBar(
        title: const Text('Catálogo de Panadería Delicia'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),

          // 🔸 Campo de búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Buscar producto...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: filtrarProductos,
            ),
          ),

          // 🔸 Botones de categorías
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                categoriaBoton('Catering'),
                categoriaBoton('Pasteleria'),
                categoriaBoton('Panes'),
              ],
            ),
          ),

          // 🔸 Lista de productos
          Expanded(
            child: filtrados.isEmpty
                ? const Center(child: Text('No se encontraron productos'))
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: filtrados.length,
                    itemBuilder: (context, index) {
                      final producto = filtrados[index];
                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: producto['imagen'] != null
                                        ? Image.network(
                                            producto['imagen'],
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(
                                            Icons.image_not_supported,
                                            size: 60,
                                            color: Colors.grey,
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () =>
                                          mostrarFormularioProducto(producto),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          boxShadow: const [
                                            BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 4)
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: const Icon(
                                          Icons.add_shopping_cart,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Text(
                                producto['nombre'] ?? 'Sin nombre',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'S/. ${producto['costo']?.toStringAsFixed(2) ?? '0.00'}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
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
  }

  // 🔸 Botón de categoría personalizado
  Widget categoriaBoton(String nombre) {
    final bool seleccionado = categoriaSeleccionada == nombre;

    return ElevatedButton(
      onPressed: () => filtrarPorCategoria(nombre),
      style: ElevatedButton.styleFrom(
        backgroundColor: seleccionado ? Colors.orange : Colors.white,
        foregroundColor: seleccionado ? Colors.white : Colors.orange,
        side: const BorderSide(color: Colors.orange),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Text(
        nombre,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
