import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen ({super.key});

  @override
  Widget build (BuildContext context) {
    return Scaffold(
      body: Stack (
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors : [Color (0xFF00AEEF), Color(0XFF00897B)],
                begin: Alignment.topLeft,
                end : Alignment.bottomRight,
            ),
          ),
        ),
        Center (
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/Layer 1.png',
                  height: 100,
                  color : Colors.white,
                ),
                const SizedBox(height: 40),

                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Masukkan Username',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Masukkan Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child : ElevatedButton(
                            onPressed: () {
                              //LOGIKA OTENTIKASI NNT DI SINI YH
                              print('button pressed');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00695C),
                              padding: const EdgeInsets.symmetric(vertical : 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)
                            ),
                            textStyle : const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child : const Text('LOGIN'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      //SIGN UP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Belum punya akun?'),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Sign Up'),
                          )
                        ],
                      )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        )
        ],
      ),
    );
  }
}

