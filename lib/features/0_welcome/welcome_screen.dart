// DIPAKE

import 'package:flutter/material.dart';
// import 'package:stressapp/features/1_auth/screens/login_screen.dart';
import 'package:stressapp/features/1_auth/screens/login_form.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen ({super.key});

  @override
  Widget build (BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient : LinearGradient(
            colors: [Color(0xFF00AEEF), Color(0XFF00897B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical : 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Image.asset(
                    'assets/images/Layer 1.png',
                    height: 250,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                ],
              ),

//BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (){
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
                      ),
                      builder: (BuildContext context) {
                        return const LoginFormSheet();
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0XFF00897B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.circular(30),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('GET STARTED'),
                ),
              ),


//DESC
              const Text(
                'Stress Monitoring merupakan aplikasi inovatif untuk memantau tingkat stres Anda secara real-time. Ambil tindakan proaktif untuk pikiran yang lebih tenang dan kinerja yang optimal!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
  

// class WelcomeScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body : Container (
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors : [Color(0xFF00AEEF), Color(0xFF00C853)],
//             begin : Alignment.topCenter,
//             end : Alignment.bottomCenter
//           ),
//         ),
//         child: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Image.asset("assets/LOGO.png", height: 150),
//               const SizedBox(height : 20),
//               const Text(
//                 "STRESS MONITOR",
//                 style: TextStyle(
//                   fontSize : 24,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//               const SizedBox(height: 40),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.pushNamed(context, '/login');
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.white,
//                   foregroundColor: Colors.teal,
//                   shape : RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(30)),
//                   padding : const EdgeInsets.symmetric(
//                     horizontal : 40, vertical : 15),
//                 ),
//                 child : const Text('GET STARTED'),
//               )
//             ],
//           ),
//         ),
//       )
//     );
//   }
// }