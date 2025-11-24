import 'package:flutter/material.dart';
import 'package:flutter_admin_scaffold/admin_scaffold.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _nombreController = TextEditingController();
  final _precioController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _categoriaController = TextEditingController();
  String? _editingId;

  void _guardarProducto() async {
    final nombre = _nombreController.text.trim();
    final precio = double.tryParse(_precioController.text) ?? 0.0;
    final descripcion = _descripcionController.text.trim();
    final categoria = _categoriaController.text.trim();
    
    if (nombre.isEmpty || categoria.isEmpty) return;
    
    final ref = FirebaseFirestore.instance.collection('ProductosPanaderia');
    
    final productoData = {
      'nombre': nombre, 
      'precio': precio,
      'descripcion': descripcion,
      'categoria': categoria,
      'fechaCreacion': FieldValue.serverTimestamp()
    };
    
    if (_editingId == null) {
      await ref.add(productoData);
    } else {
      await ref.doc(_editingId).update(productoData);
    }
    
    _limpiarFormulario();
  }

  void _limpiarFormulario() {
    _nombreController.clear();
    _precioController.clear();
    _descripcionController.clear();
    _categoriaController.clear();
    _editingId = null;
  }

  void _editarProducto(Map<String, dynamic> data, String id) {
    _nombreController.text = data['nombre'] ?? '';
    _precioController.text = data['precio']?.toString() ?? '';
    _descripcionController.text = data['descripcion'] ?? '';
    _categoriaController.text = data['categoria'] ?? '';
    _editingId = id;
  }

  void _eliminarProducto(String id) async {
    await FirebaseFirestore.instance
        .collection('ProductosPanaderia')
        .doc(id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      appBar: AppBar(
        title: const Text("Panel Administrativo - Panadería Delicia"),
        backgroundColor: Colors.amber[700],
        foregroundColor: Colors.white,
      ),
      sideBar: SideBar(
        items: const [
          AdminMenuItem(
            title: 'Gestión de Productos', 
            icon: Icons.inventory_2, 
            route: '/'
          ),
         
        ],
        selectedRoute: '/',
        onSelected: (item) {
          // Navegación entre secciones
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              'Gestión de Productos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.amber[800],
              ),
            ),
            const SizedBox(height: 16),
            
            // Formulario
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      _editingId == null ? 'Agregar Nuevo Producto' : 'Editar Producto',
                      style: const TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nombreController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del Producto',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.bakery_dining),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _precioController,
                            decoration: const InputDecoration(
                              labelText: 'Precio (S/)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _categoriaController,
                      decoration: const InputDecoration(
                        labelText: 'Categoría (Catering,Pasteleria,Panes)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _descripcionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción del Producto',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 2,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _guardarProducto,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber[700],
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: Text(
                              _editingId == null ? 'AGREGAR PRODUCTO' : 'ACTUALIZAR PRODUCTO',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ),
                        if (_editingId != null) ...[
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _limpiarFormulario,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Text('CANCELAR'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Lista de productos
            Expanded(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Productos Registrados',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('ProductosPanaderia')
                              .orderBy('fechaCreacion', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'No hay productos registrados',
                                      style: TextStyle(fontSize: 16, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              );
                            }
                            
                            final docs = snapshot.data!.docs;
                            
                            return SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 20,
                                  dataRowMinHeight: 60,
                                  dataRowMaxHeight: 80,
                                  columns: const [
                                    DataColumn(label: Text('Producto')),
                                    DataColumn(label: Text('Precio')),
                                    DataColumn(label: Text('Categoría')),
                                    DataColumn(label: Text('Descripción')),
                                    DataColumn(label: Text('Acciones')),
                                  ],
                                  rows: docs.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    return DataRow(cells: [
                                      DataCell(
                                        Text(
                                          data['nombre'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      DataCell(Text('S/ ${data['precio']?.toStringAsFixed(2) ?? '0.00'}')),
                                      DataCell(
                                        Chip(
                                          label: Text(
                                            data['categoria'] ?? 'General',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                          backgroundColor: Colors.amber[600],
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 200,
                                          child: Text(
                                            data['descripcion'] ?? 'Sin descripción',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            onPressed: () => _editarProducto(data, doc.id),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _eliminarProducto(doc.id),
                                          ),
                                        ],
                                      )),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}