import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Hapus import WelcomeScreen karena tidak lagi digunakan untuk navigasi
// import 'package:stressapp/features/0_welcome/welcome_screen.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      // 1. Perbarui password pengguna
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password berhasil diperbarui! Silakan login kembali.'),
            backgroundColor: Colors.green,
          ),
        );

        // ==========================================================
        // PERBAIKAN DI SINI:
        // Cukup panggil signOut(). StreamBuilder di main.dart akan
        // secara otomatis menangani navigasi ke halaman login.
        // ==========================================================
        await Supabase.instance.client.auth.signOut();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Password Baru'),
        backgroundColor: Colors.teal,
        automaticallyImplyLeading: false, 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Silakan masukkan password baru Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password Baru',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.length < 6 ? 'Password minimal 6 karakter' : null,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('SIMPAN PASSWORD BARU', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// // Import WelcomeScreen untuk navigasi
// import 'package:stressapp/features/0_welcome/welcome_screen.dart';

// class UpdatePasswordScreen extends StatefulWidget {
//   const UpdatePasswordScreen({super.key});

//   @override
//   State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
// }

// class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
//   final _passwordController = TextEditingController();
//   final _formKey = GlobalKey<FormState>();
//   bool _isLoading = false;

//   // ==========================================================
//   // PERUBAHAN UTAMA ADA DI FUNGSI DI BAWAH INI
//   // ==========================================================
//   Future<void> _updatePassword() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }
//     setState(() => _isLoading = true);

//     try {
//       // 1. Perbarui password pengguna
//       await Supabase.instance.client.auth.updateUser(
//         UserAttributes(password: _passwordController.text.trim()),
//       );
      
//       if (mounted) {
//         // 2. KELUAR (SIGN OUT) dari sesi sementara setelah password diperbarui
//         await Supabase.instance.client.auth.signOut();

//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Password berhasil diperbarui! Silakan login kembali.'),
//             backgroundColor: Colors.green,
//           ),
//         );
        
//         // 3. Arahkan pengguna kembali ke halaman Welcome/Login, bukan Dashboard
//         Navigator.of(context).pushAndRemoveUntil(
//           MaterialPageRoute(builder: (context) => const WelcomeScreen()),
//           (route) => false,
//         );
//       }
//     } on AuthException catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _passwordController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Buat Password Baru'),
//         backgroundColor: Colors.teal,
//         // Sembunyikan tombol kembali agar alur tidak membingungkan
//         automaticallyImplyLeading: false, 
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               const SizedBox(height: 20),
//               const Text(
//                 'Silakan masukkan password baru Anda.',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 16, color: Colors.black54),
//               ),
//               const SizedBox(height: 24),
//               TextFormField(
//                 controller: _passwordController,
//                 obscureText: true,
//                 decoration: const InputDecoration(
//                   labelText: 'Password Baru',
//                   prefixIcon: Icon(Icons.lock_outline),
//                   border: OutlineInputBorder(),
//                 ),
//                 validator: (value) => value!.length < 6 ? 'Password minimal 6 karakter' : null,
//               ),
//               const SizedBox(height: 24),
//               _isLoading
//                   ? const Center(child: CircularProgressIndicator())
//                   : ElevatedButton(
//                       onPressed: _updatePassword,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.teal,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                       ),
//                       child: const Text('SIMPAN PASSWORD BARU'),
//                     ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }