import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _celularController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _registrarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('UsuariosPanaderia')
          .add({
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'correo': _correoController.text.trim(),
        'celular': _celularController.text.trim(),
        'password': _passwordController.text.trim(),
        'fechaRegistro': Timestamp.now(),
      });

      // Crear subcolección vacía "historial"
      await docRef.collection('historial').doc('init').set({
        'mensaje': 'Subcolección creada correctamente',
        'fecha': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario registrado correctamente')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      appBar: AppBar(
        title: const Text('Crear nuevo usuario'),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Logo igual que en login
                  Image.asset('assets/images/logo.png', height: 120),
                  const SizedBox(height: 20),
                  const Text(
                    'Registro de Usuario',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown),
                  ),
                  const SizedBox(height: 30),

                  // Campo Nombre
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                        labelText: 'Nombre', border: OutlineInputBorder()),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Ingrese su nombre' : null,
                  ),
                  const SizedBox(height: 16),

                  // Campo Apellido
                  TextFormField(
                    controller: _apellidoController,
                    decoration: const InputDecoration(
                        labelText: 'Apellido', border: OutlineInputBorder()),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Ingrese su apellido' : null,
                  ),
                  const SizedBox(height: 16),

                  // Campo Correo
                  TextFormField(
                    controller: _correoController,
                    decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        border: OutlineInputBorder()),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingrese su correo electrónico';
                      }
                      if (!value.contains('@')) {
                        return 'Correo inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo Celular
                  TextFormField(
                    controller: _celularController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Celular', border: OutlineInputBorder()),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingrese su número de celular';
                      }
                      if (value.length < 9) {
                        return 'Número de celular inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo Contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Contraseña', border: OutlineInputBorder()),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingrese una contraseña';
                      }
                      if (value.length < 6) {
                        return 'Debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Botón Registrar
                  ElevatedButton(
                    onPressed: _isLoading ? null : _registrarUsuario,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 60, vertical: 15),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Registrar',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),

                  const SizedBox(height: 20),

                  // Botón para volver al login
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '← Volver al inicio de sesión',
                      style: TextStyle(color: Colors.brown),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}