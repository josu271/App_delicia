import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistorialScreen extends StatefulWidget {
  final String userId; // ID del usuario actual

  const HistorialScreen({super.key, required this.userId});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  // 🔹 Controla qué tarjeta está expandida
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      appBar: AppBar(
        title: const Text('Historial de Compras'),
        backgroundColor: Colors.orange,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('UsuariosPanaderia')
            .doc(widget.userId)
            .collection('historial')
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Aún no hay compras registradas 🧁',
                style: TextStyle(fontSize: 16, color: Colors.brown),
              ),
            );
          }

          final historial = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: historial.length,
            itemBuilder: (context, index) {
              final compra = historial[index].data() as Map<String, dynamic>;
              final fecha = (compra['fecha'] as Timestamp).toDate();
              final total = compra['total'] ?? 0.0;
              final productos = compra['productos'] ?? [];

              final bool isExpanded = _expandedIndex == index;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.receipt_long,
                          color: Colors.brown, size: 32),
                      title: Text(
                        'Compra del ${fecha.day}/${fecha.month}/${fecha.year}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.brown),
                      ),
                      subtitle: Text(
                        'Total: S/. ${total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isExpanded
                              ? Icons.expand_less
                              : Icons.info_outline,
                          color: Colors.orange,
                        ),
                        onPressed: () {
                          setState(() {
                            _expandedIndex = isExpanded ? null : index;
                          });
                        },
                      ),
                    ),

                    // 🔹 Si está expandido, mostramos detalle de productos
                    if (isExpanded && productos.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(color: Colors.orange, thickness: 1),
                            const Text(
                              '🧺 Detalle de productos:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.brown,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...productos.map<Widget>((p) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        p['nombre'] ?? 'Producto',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'x${p['cantidad']}',
                                        textAlign: TextAlign.center,
                                        style:
                                            const TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'S/. ${(p['subtotal'] ?? 0).toStringAsFixed(2)}',
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                            color: Colors.brown,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
