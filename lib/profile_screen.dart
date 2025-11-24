import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _celularController = TextEditingController();

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('UsuariosPanaderia')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nombreController.text = data['nombre'] ?? '';
          _apellidoController.text = data['apellido'] ?? '';
          _correoController.text = data['correo'] ?? '';
          _passwordController.text = data['password'] ?? '';
          _celularController.text = data['celular'] ?? '';
          _cargando = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar usuario: $e')),
      );
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseFirestore.instance
          .collection('UsuariosPanaderia')
          .doc(widget.userId)
          .update({
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'correo': _correoController.text.trim(),
        'password': _passwordController.text.trim(),
        'celular': _celularController.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Perfil actualizado con éxito')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar cambios: $e')),
      );
    }
  }

  void _cerrarSesion() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      appBar: AppBar(
        title: const Text('Perfil del Usuario'),
        backgroundColor: Colors.orange,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.person, size: 70, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Ingrese su nombre' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _apellidoController,
                      decoration: const InputDecoration(
                        labelText: 'Apellido',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Ingrese su apellido' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _correoController,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Ingrese su correo' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v != null && v.length < 6
                          ? 'Debe tener al menos 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _celularController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Celular',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v != null && v.length == 9 ? null : 'Debe tener 9 dígitos',
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _guardarCambios,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 60, vertical: 15),
                      ),
                      child: const Text('Guardar cambios',
                          style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _cerrarSesion,
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text('Cerrar sesión',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
