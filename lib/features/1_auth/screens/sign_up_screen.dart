import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stressapp/features/1_auth/models/divisi_model.dart';

final supabase = Supabase.instance.client;

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _posisiController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  List<Divisi> _divisiList = [];
  Divisi? _selectedDivisi;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _getDivisions();
  }

  Future<void> _getDivisions() async {
    try {
      final List<Map<String, dynamic>> data =
          await supabase.from('stress_divisi').select();
      if (mounted) {
        setState(() {
          _divisiList = data.map((item) => Divisi.fromJson(item)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Gagal memuat data divisi: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'username': _usernameController.text.trim(),
          'full_name': _namaController.text.trim(),
        },
      );

      if (res.user != null) {
        await supabase.from('stress_pegawai').insert({
          'nama_pegawai': _namaController.text.trim(),
          'posisi': _posisiController.text.trim(),
          'divisi_id': _selectedDivisi!.id,
          'email': _emailController.text.trim(),
          'username': _usernameController.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Pendaftaran Berhasil! Silakan cek email Anda untuk verifikasi.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.message}'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal menyimpan data pegawai: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _posisiController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Akun Baru')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _namaController,
                  decoration: const InputDecoration(labelText: 'Nama Pegawai'),
                  validator: (value) =>
                      value!.isEmpty ? 'Nama tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _posisiController,
                  decoration: const InputDecoration(labelText: 'Posisi'),
                  validator: (value) =>
                      value!.isEmpty ? 'Posisi tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                if (_divisiList.isNotEmpty)
                  DropdownButtonFormField<Divisi>(
                    initialValue: _selectedDivisi,
                    hint: const Text('Pilih Divisi'),
                    items: _divisiList.map((divisi) {
                      return DropdownMenuItem<Divisi>(
                          value: divisi, child: Text(divisi.nama));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDivisi = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Pilih divisi Anda' : null,
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value!.isEmpty || !value.contains('@')
                      ? 'Masukkan email yang valid'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) =>
                      value!.isEmpty ? 'Username tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: (value) =>
                      value!.length < 6 ? 'Password minimal 6 karakter' : null,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _signUp,
                        child: const Text('DAFTAR'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:stressapp/features/1_auth/models/divisi_model.dart';

// // Variabel global supabase dari main.dart
// final supabase = Supabase.instance.client;

// class SignUpScreen extends StatefulWidget {
//   const SignUpScreen({super.key});

//   @override
//   State<SignUpScreen> createState() => _SignUpScreenState();
// }

// class _SignUpScreenState extends State<SignUpScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _namaController = TextEditingController();
//   final _posisiController = TextEditingController(); // Controller baru
//   final _emailController = TextEditingController();
//   final _usernameController = TextEditingController();
//   final _passwordController = TextEditingController();

//   List<Divisi> _divisiList = [];
//   Divisi? _selectedDivisi; // Untuk menyimpan divisi yang dipilih
//   bool _isLoading = false;
//   bool _isPasswordVisible = false;

//   @override
//   void initState() {
//     super.initState();
//     _getDivisions(); // Ambil data divisi saat halaman dibuka
//   }

//   // Fungsi untuk mengambil daftar divisi dari Supabase
//   Future<void> _getDivisions() async {
//     try {
//       final List<Map<String, dynamic>> data = await supabase.from('stress_divisi').select();
//       if (mounted) {
//         setState(() {
//           _divisiList = data.map((item) => Divisi.fromJson(item)).toList();
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Gagal memuat data divisi: $e"), backgroundColor: Colors.red),
//         );
//       }
//     }
//   }

//   // Fungsi untuk menjalankan proses pendaftaran
//   Future<void> _signUp() async {
//   if (!_formKey.currentState!.validate()) {
//     return;
//   }
//   setState(() { _isLoading = true; });

//   try {
//     // Langkah 1: Mendaftarkan user ke Supabase Auth dengan email, password, dan username
//     final AuthResponse res = await supabase.auth.signUp(
//       email: _emailController.text.trim(),
//       password: _passwordController.text.trim(),
//       data: {
//         'username': _usernameController.text.trim(),
//         // Anda juga bisa menyimpan nama di sini jika mau
//         'full_name': _namaController.text.trim(),
//       },  
//     );
    
//     // Langkah 2: Menyisipkan data profil ke tabel 'stress_pegawai'
//     if (res.user != null) {
//       await supabase.from('stress_pegawai').insert({
//         'nama_pegawai': _namaController.text.trim(),
//         'posisi': _posisiController.text.trim(),
//         'divisi_id': _selectedDivisi!.id,
//         'email' : _emailController.text.trim(),
//         'username' : _emailController.text.trim(),
//       });

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Pendaftaran Berhasil! Silakan cek email Anda untuk verifikasi.'),
//             backgroundColor: Colors.green,
//           ),
//         );
//         Navigator.pop(context);
//       }
//     }
//   } on AuthException catch (e) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red),
//       );
//     }
//   } catch (e) {
//      if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Gagal menyimpan data pegawai: $e'), backgroundColor: Colors.red),
//       );
//     }
//   } finally {
//     if (mounted) {
//       setState(() { _isLoading = false; });
//     }
//   }
// }

//   @override
//   void dispose() {
//     _namaController.dispose();
//     _posisiController.dispose();
//     _usernameController.dispose();
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Buat Akun Baru')),
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24.0),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 TextFormField(
//                   controller: _namaController,
//                   decoration: const InputDecoration(labelText: 'Nama Pegawai'),
//                   validator: (value) => value!.isEmpty ? 'Nama tidak boleh kosong' : null,
//                 ),
//                 const SizedBox(height: 16),
//                 // Input Posisi
//                 TextFormField(
//                   controller: _posisiController,
//                   decoration: const InputDecoration(labelText: 'Posisi'),
//                   validator: (value) => value!.isEmpty ? 'Posisi tidak boleh kosong' : null,
//                 ),
//                 const SizedBox(height: 16),
//                 // Dropdown Divisi
//                 if (_divisiList.isNotEmpty)
//                   DropdownButtonFormField<Divisi>(
//                     value: _selectedDivisi,
//                     hint: const Text('Pilih Divisi'),
//                     items: _divisiList.map((divisi) {
//                       return DropdownMenuItem<Divisi>(
//                         value: divisi,
//                         child: Text(divisi.nama),
//                       );
//                     }).toList(),
//                     onChanged: (value) {
//                       setState(() {
//                         _selectedDivisi = value;
//                       });
//                     },
//                     validator: (value) => value == null ? 'Pilih divisi Anda' : null,
//                   ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: _emailController,
//                   decoration: const InputDecoration(labelText: 'Email'),
//                   keyboardType: TextInputType.emailAddress,
//                   validator: (value) => value!.isEmpty || !value.contains('@') ? 'Masukkan email yang valid' : null,
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: _usernameController,
//                   decoration: const InputDecoration(labelText: 'Username'),
//                   validator: (value) => value!.isEmpty ? 'Username tidak boleh kosong' : null,
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: _passwordController,
//                   obscureText: !_isPasswordVisible,
//                   decoration: InputDecoration(
//                     labelText: 'Password',
//                     suffixIcon: IconButton(
//                       icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
//                       onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
//                     ),
//                   ),
//                   validator: (value) => value!.length < 6 ? 'Password minimal 6 karakter' : null,
//                 ),
//                 const SizedBox(height: 24),
//                 _isLoading
//                     ? const Center(child: CircularProgressIndicator())
//                     : ElevatedButton(
//                         onPressed: _signUp,
//                         child: const Text('DAFTAR'),
//                       ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }