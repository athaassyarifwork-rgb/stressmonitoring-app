import 'package:flutter/material.dart';
import 'package:stressapp/features/0_welcome/welcome_screen.dart';
import 'package:stressapp/features/1_auth/screens/update_password_screen.dart'; 
import 'package:stressapp/features/2_dashboard/screens/dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stress Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'League_Spartan',
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const WelcomeScreen(); 
          }

          final session = snapshot.data?.session;
          final event = snapshot.data?.event;


          if (event == AuthChangeEvent.passwordRecovery) {
            return const UpdatePasswordScreen();
          }

          if (session != null) {
            return const DashboardScreen();
          }


          return const WelcomeScreen();
        },
      ),
    );
  }
}





// import 'package:flutter/material.dart';
// import 'package:stressapp/features/0_welcome/welcome_screen.dart';
// import 'package:stressapp/features/2_dashboard/screens/dashboard_screen.dart'; // Pastikan import ini ada
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await dotenv.load(fileName: ".env");
//   await Supabase.initialize(
//     url: dotenv.env['SUPABASE_URL']!,
//     anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
//   );
//   runApp(const MyApp());
// }

// // MyApp sekarang bisa menjadi StatelessWidget lagi
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Stress Monitor',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         fontFamily: 'League_Spartan',
//         brightness: Brightness.light,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       // Gunakan StreamBuilder untuk secara otomatis mendeteksi login/logout
//       home: StreamBuilder<AuthState>(
//         stream: Supabase.instance.client.auth.onAuthStateChange,
//         builder: (context, snapshot) {
//           // Jika pengguna sudah login (termasuk setelah reset password),
//           // langsung arahkan ke Dashboard.
//           if (snapshot.hasData && snapshot.data?.session != null) {
//             return const DashboardScreen();
//           }
//           // Jika tidak, tampilkan halaman welcome/login.
//           return const WelcomeScreen();
//         },
//       ),
//     );
//   }
// }



