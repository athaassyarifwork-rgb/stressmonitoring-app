import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import baru
import 'package:stressapp/features/2_dashboard/screens/dashboard_screen.dart';
import 'package:stressapp/features/1_auth/screens/forgot_password_screen.dart';

final supabase = Supabase.instance.client;

class LoginFormSheet extends StatefulWidget {
  const LoginFormSheet({super.key});
  @override
  State<LoginFormSheet> createState() => _LoginFormSheetState();
}

class _LoginFormSheetState extends State<LoginFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isFormValid = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false; // State untuk checkbox

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // Load data saat startup
    _usernameController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  // Memuat data dari Shared Preferences
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usernameController.text = prefs.getString('saved_username') ?? '';
      _passwordController.text = prefs.getString('saved_password') ?? '';
      _rememberMe = prefs.getBool('remember_me') ?? false;
      _validateForm();
    });
  }

  // Menyimpan atau menghapus data kredensial
  Future<void> _handleRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_username', _usernameController.text);
      await prefs.setString('saved_password', _passwordController.text);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_username');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final isValid = _usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty;
    if (_isFormValid != isValid) {
      setState(() => _isFormValid = isValid);
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      final data = await supabase
          .from('stress_pegawai')
          .select('email')
          .eq('username', username)
          .single();

      final email = data['email'] as String;

      await supabase.auth.signInWithPassword(email: email, password: password);

      // JIKA BERHASIL: Proses Remember Me
      await _handleRememberMe();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } on PostgrestException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Username tidak terdaftar. Hubungi Admin.'),
            backgroundColor: Colors.red));
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Login gagal: ${e.message}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Colors.grey.shade400;
    final primaryColor = const Color(0xFF00897B);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 32),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                    hintText: 'Masukkan username',
                    suffixIcon:
                        Icon(Icons.person_outline, color: inactiveColor)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'Masukkan password',
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),

              // --- TAMBAHAN FITUR REMEMBER ME ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: primaryColor,
                          onChanged: (value) {
                            setState(() => _rememberMe = value ?? false);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Ingat Saya', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const ForgotPasswordScreen())),
                    child: const Text('Lupa password?',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _isFormValid ? _signIn : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      child: const Text('LOGIN',
                          style: TextStyle(color: Colors.white)),
                    ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:stressapp/features/1_auth/screens/sign_up_screen.dart';
// import 'package:stressapp/features/2_dashboard/screens/dashboard_screen.dart';

// // Variabel global supabase dari main.dart
// final supabase = Supabase.instance.client;

// // 1. Diubah kembali menjadi StatefulWidget
// class LoginFormSheet extends StatefulWidget {
//   const LoginFormSheet({super.key});

//   @override
//   State<LoginFormSheet> createState() => _LoginFormSheetState();
// }

// class _LoginFormSheetState extends State<LoginFormSheet> {
//   // 2. Semua state dan controller dipindahkan ke sini
//   final _formKey = GlobalKey<FormState>();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();

//   bool _isLoading = false;
//   bool _isFormValid = false;

//   // 3. Pindahkan logika dari Notifier ke dalam State class
//   @override
//   void initState() {
//     super.initState();
//     // Tambahkan listener untuk validasi tombol real-time
//     _emailController.addListener(_validateForm);
//     _passwordController.addListener(_validateForm);
//   }

//   @override
//   void dispose() {
//     // Hapus listener dan dispose controller
//     _emailController.removeListener(_validateForm);
//     _passwordController.removeListener(_validateForm);
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   void _validateForm() {
//     final isValid = _emailController.text.isNotEmpty && _passwordController.text.isNotEmpty;
//     // Panggil setState agar UI tahu ada perubahan
//     if (_isFormValid != isValid) {
//       setState(() {
//         _isFormValid = isValid;
//       });
//     }
//   }

// //   // TESTING
// //   Future<void> _signIn() async {
// //   print('1. Tombol LOGIN ditekan.'); // CHECKPOINT 1

// //   if (!_formKey.currentState!.validate()) {
// //     print('Proses berhenti: Validasi form GAGAL.'); // PESAN JIKA GAGAL VALIDASI
// //     return;
// //   }
  
// //   print('2. Validasi form berhasil.'); // CHECKPOINT 2
// //   setState(() { _isLoading = true; });

// //   try {
// //     print('3. Mencoba login ke Supabase...'); // CHECKPOINT 3
// //     await supabase.auth.signInWithPassword(
// //       email: _emailController.text.trim(),
// //       password: _passwordController.text.trim(),
// //     );

// //     print('4. Login BERHASIL.'); // CHECKPOINT 4
// //     if (mounted) {
// //       Navigator.pushReplacement(
// //         context,
// //         MaterialPageRoute(builder: (context) => const DashboardScreen()),
// //       );
// //     }
// //   } on AuthException catch (e) {
// //     print('ERROR: Terjadi AuthException - ${e.message}'); // ERROR AUTH
// //     if (mounted) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Login Gagal: ${e.message}'), backgroundColor: Colors.red),
// //       );
// //     }
// //   } catch (e) {
// //     print('ERROR: Terjadi kesalahan umum - $e'); // ERROR LAIN
// //     if (mounted) {
// //        ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
// //       );
// //     }
// //   }
// //   finally {
// //     if (mounted) {
// //       setState(() { _isLoading = false; });
// //     }
// //   }
// // }

// // Di dalam file login_form_sheet.dart -> class _LoginFormSheetState

// // testing 2

// // Future<void> _signIn() async {
// //   print('1. Tombol LOGIN ditekan.');

// //   if (!_formKey.currentState!.validate()) {
// //     print('Proses berhenti: Validasi form GAGAL.');
// //     return;
// //   }
  
// //   print('2. Validasi form berhasil.');
// //   setState(() { _isLoading = true; });

// //   try {
// //     print('3. Mencoba login ke Supabase...');
    
// //     // Panggil fungsi login
// //     await supabase.auth.signInWithPassword(
// //       email: _emailController.text.trim(),
// //       password: _passwordController.text.trim(),
// //     );

// //     print('4. Login di Supabase BERHASIL.'); // CHECKPOINT PENTING

// //     if (mounted) {
// //       print('5. Mencoba navigasi ke DashboardScreen...'); // CHECKPOINT NAVIGASI
// //       Navigator.pushReplacement(
// //         context,
// //         MaterialPageRoute(builder: (context) => const DashboardScreen()),
// //       );
// //       print('6. Perintah navigasi selesai dijalankan.');
// //     }
// //   } on AuthException catch (e) {
// //     print('ERROR: Terjadi AuthException - ${e.message}');
// //     if (mounted) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Login Gagal: ${e.message}'), backgroundColor: Colors.red),
// //       );
// //     }
// //   } catch (e) {
// //     print('ERROR: Terjadi kesalahan umum - $e');
// //     if (mounted) {
// //        ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
// //       );
// //     }
// //   } finally {
// //     if (mounted) {
// //       setState(() { _isLoading = false; });
// //     }
// //   }
// // }

// // USERNAME USED

// Future<void> _signIn() async {
//   if (!_formKey.currentState!.validate()) {
//     return;
//   }
//   setState(() { _isLoading = true; });

//   try {
//     // Ambil input dari pengguna
//     final username = _usernameController.text.trim(); // Ganti _emailController dengan _usernameController
//     final password = _passwordController.text.trim();

//     // LANGKAH 1: Cari email di tabel 'stress_pegawai' berdasarkan username
//     print('Mencari email untuk username: $username...');
//     final data = await supabase
//         .from('stress_pegawai')
//         .select('email') // Ambil kolom email
//         .eq('username', username) // Di mana username cocok
//         .single(); // Ambil satu baris saja, akan error jika tidak ketemu

//     final email = data['email'] as String;
//     print('Email ditemukan: $email');

//     // LANGKAH 2: Gunakan email yang ditemukan untuk otentikasi
//     print('Mencoba login dengan email: $email...');
//     await supabase.auth.signInWithPassword(
//       email: email, // Gunakan email dari hasil pencarian
//       password: password,
//     );

//     // Jika berhasil, navigasi ke Dashboard
//     if (mounted) {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const DashboardScreen()),
//       );
//     }
//   } on PostgrestException catch (e) {
//     // Error ini terjadi jika username tidak ditemukan
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Username tidak ditemukan.'), backgroundColor: Colors.red),
//       );
//     }
//   } on AuthException catch (e) {
//     // Error ini terjadi jika password salah setelah email ditemukan
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Password salah.'), backgroundColor: Colors.red),
//       );
//     }
//   } catch (e) {
//     // Error umum lainnya
//     if (mounted) {
//        ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
//       );
//     }
//   } finally {
//     if (mounted) {
//       setState(() { _isLoading = false; });
//     }
//   }
// }

//   // Future<void> _signIn() async {
//   //   if (!_formKey.currentState!.validate()) {
//   //     return;
//   //   }
//   //   setState(() { _isLoading = true; });

//   //   try {
//   //     await supabase.auth.signInWithPassword(
//   //       email: _emailController.text.trim(),
//   //       password: _passwordController.text.trim(),
//   //     );

//   //     if (mounted) {
//   //       Navigator.pushReplacement(
//   //         context,
//   //         MaterialPageRoute(builder: (context) => const DashboardScreen()),
//   //       );
//   //     }
//   //   } on AuthException catch (e) {
//   //     if (mounted) {
//   //       ScaffoldMessenger.of(context).showSnackBar(
//   //         SnackBar(content: Text('Login Gagal. Periksa kembali email & password Anda.'), backgroundColor: Colors.red),
//   //       );
//   //     }
//   //   } finally {
//   //     if (mounted) {
//   //       setState(() { _isLoading = false; });
//   //     }
//   //   }
//   // }

//   @override
//   Widget build(BuildContext context) {
//     final inactiveColor = Colors.grey.shade400;

//     return Padding(
//       padding: EdgeInsets.only(
//         bottom: MediaQuery.of(context).viewInsets.bottom,
//         left: 24, right: 24, top: 32,
//       ),
//       child: SingleChildScrollView(
//         child: Form(
//           key: _formKey,
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               TextFormField(
//                 controller: _emailController, // Gunakan controller lokal
//                 decoration: InputDecoration(
//                   hintText: 'Masukkan username',
//                   hintStyle: TextStyle(color: inactiveColor),
//                   suffixIcon: Icon(Icons.person_outline, color: inactiveColor),
//                 ),
//                 validator: (value) => value!.isEmpty ? 'Email tidak boleh kosong' : null,
//               ),
//               const SizedBox(height: 16),
//               TextFormField(
//                 controller: _passwordController, // Gunakan controller lokal
//                 obscureText: true,
//                 decoration: InputDecoration(
//                   hintText: 'Masukkan password',
//                   hintStyle: TextStyle(color: inactiveColor),
//                   suffixIcon: Icon(Icons.visibility_outlined, color: inactiveColor),
//                 ),
//                 validator: (value) => value!.isEmpty ? 'Password tidak boleh kosong' : null,
//               ),
//               const SizedBox(height: 8),
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: TextButton(onPressed: () {}, child: const Text('Lupa password?')),
//               ),
//               const SizedBox(height: 24),
              
//               _isLoading
//                   ? const Center(child: CircularProgressIndicator())
//                   : ElevatedButton(
//                       // 4. Gunakan state dan fungsi lokal
//                       onPressed: _isFormValid ? _signIn : null,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF00897B),
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
//                       ),
//                       child: const Text('LOGIN', style: TextStyle(color: Colors.white)),
//                     ),
//               const SizedBox(height: 20),
              
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Text("Belum punya akun?"),
//                   TextButton(
//                     onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
//                     child: const Text('Sign Up'),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }