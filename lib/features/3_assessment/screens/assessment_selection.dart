import 'package:flutter/material.dart';
import 'package:stressapp/features/3_assessment/screens/question_screen.dart';

class AssessmentSelectionScreen extends StatefulWidget {
  const AssessmentSelectionScreen({super.key});

  @override
  State<AssessmentSelectionScreen> createState() =>
      _AssessmentSelectionScreenState();
}

class _AssessmentSelectionScreenState extends State<AssessmentSelectionScreen> {
  // State untuk melacak kartu mana yang sedang dipilih/mengembang
  int? _selectedIndex;

  // Data kartu, termasuk deskripsi dan warna
  final List<Map<String, dynamic>> _testTypes = [
    {
      'title': 'Tes Tingkat Stres',
      'description':
          'Mengukur sejauh mana Anda merasa terbebani dan kewalahan oleh berbagai tekanan dalam hidup Anda baru-baru ini.',
      'icon': Icons.sentiment_very_dissatisfied_outlined,
      'color':  const Color(0xFFE59752),
      'testType': 'Stress',
    },
    {
      'title': 'Tes Tingkat Kecemasan',
      'description':
          'Mengidentifikasi gejala-gejala kecemasan fisiologis dan rasa takut yang mungkin Anda alami.',
      'icon': Icons.sentiment_neutral_outlined,
      'color': const Color(0xFF3B83A3),
      'testType': 'Anxiety',
    },
    {
      'title': 'Tes Tingkat Depresi',
      'description':
          'Mengevaluasi gejala-gejala yang berhubungan dengan perasaan sedih, kehilangan minat, dan pesimisme.',
      'icon': Icons.sentiment_satisfied_outlined,
      'color': const Color(0xFF24614A),
      'testType': 'Depression',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Latar belakang gradasi
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00B5AD), Color(0xFF008983)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // AppBar transparan
                AppBar(
                  title: const Text(
                    'Pilih Tipe Tes',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  centerTitle: true,
                ),
                // Expanded digunakan agar konten kartu mengisi sisa ruang
                Expanded(
                  // Center memastikan ListView berada di tengah secara vertikal
                  child: Center(
                    child: ListView.builder(
                      // shrinkWrap true agar ListView tidak memakan semua ruang vertikal
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      itemCount: _testTypes.length,
                      itemBuilder: (context, index) {
                        return _buildTestCard(index);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk kartu yang bisa mengembang dan menampilkan deskripsi
  Widget _buildTestCard(int index) {
    final cardData = _testTypes[index];
    final bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          // Jika kartu yang sama ditekan lagi, tutup. Jika beda, buka yang baru.
          _selectedIndex = isSelected ? null : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        // Tinggi kartu berubah saat dipilih untuk menampilkan deskripsi
        height: isSelected ? 250 : 100,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: cardData['color'],
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: isSelected
              ? _buildExpandedContent(cardData) // Tampilan saat terbuka
              : _buildCollapsedContent(cardData), // Tampilan saat tertutup
        ),
      ),
    );
  }

  // Konten saat kartu tertutup (hanya ikon dan judul)
  Widget _buildCollapsedContent(Map<String, dynamic> cardData) {
    return SizedBox(
      height: 68, // Sesuaikan tinggi agar konten pas di tengah
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(cardData['icon'], color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Text(
            cardData['title'],
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Konten saat kartu terbuka (dengan deskripsi dan tombol)
  Widget _buildExpandedContent(Map<String, dynamic> cardData) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(cardData['icon'], color: Colors.white, size: 36),
        const SizedBox(height: 12),
        Text(
          cardData['title'],
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          cardData['description'],
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuestionnaireScreen(
                  testType: cardData['testType'],
                  themeColor: cardData['color'],
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: cardData['color'],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          ),
          child: const Text('Ikuti Tes'),
        ),
      ],
    );
  }
}




// import 'package:flutter/material.dart';
// import 'package:stressapp/features/3_assessment/screens/question_screen.dart';

// class AssessmentSelectionScreen extends StatefulWidget {
//   const AssessmentSelectionScreen({super.key});

//   @override
//   State<AssessmentSelectionScreen> createState() => _AssessmentSelectionScreenState();
// }

// class _AssessmentSelectionScreenState extends State<AssessmentSelectionScreen> {
//   int? _selectedIndex;

//   // Data kartu diperbarui dengan ikon untuk semua dan deskripsi lebih panjang
//   final List<Map<String, dynamic>> _testTypes = [
//     {
//       'title': 'Tes Tingkat Stres',
//       'description': 'Mengukur sejauh mana Anda merasa terbebani dan kewalahan oleh berbagai tekanan dalam hidup Anda baru-baru ini.',
//       'icon': Icons.sentiment_very_dissatisfied_outlined,
//       'color': const Color(0xFFE59752),
//       'testType': 'Stress',
//     },
//     {
//       'title': 'Tes Tingkat Kecemasan',
//       'description': 'Mengidentifikasi gejala-gejala kecemasan fisiologis dan rasa takut yang mungkin Anda alami.',
//       'icon': Icons.sentiment_neutral_outlined,
//       'color': const Color(0xFF3B83A3),
//       'testType': 'Anxiety',
//     },
//     {
//       'title': 'Tes Tingkat Depresi',
//       'description': 'Mengevaluasi gejala-gejala yang berhubungan dengan perasaan sedih, kehilangan minat, dan pesimisme.',
//       'icon': Icons.sentiment_satisfied_outlined,
//       'color': const Color(0xFF24614A),
//       'testType': 'Depression',
//     },
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[200],
//       // Gunakan Stack untuk menumpuk header dan konten
//       body: Stack(
//         children: [
//           // Header Gradasi
//           Container(
//             height: 200,
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Color(0xFF00B5AD), Color(0xFF008983)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),
//           // AppBar Transparan
//           SafeArea(
//             child: AppBar(
//               title: const Text('Pilih tipe test', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),),
//               backgroundColor: Colors.transparent,
//               elevation: 0,
//               iconTheme: IconThemeData(
//                 color: Colors.white,
//               ),
//             ),
//           ),
//           // Konten Kartu
//           Padding(
//             padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 80),
//             child: ListView.builder(
//               padding: const EdgeInsets.symmetric(horizontal: 24.0),
//               itemCount: _testTypes.length,
//               itemBuilder: (context, index) {
//                 return _buildTestCard(index);
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTestCard(int index) {
//     final cardData = _testTypes[index];
//     final bool isSelected = _selectedIndex == index;

//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           _selectedIndex = isSelected ? null : index;
//         });
//       },
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeInOut,
//         // Ukuran kartu disesuaikan
//         height: isSelected ? 250 : 100,
//         margin: const EdgeInsets.only(bottom: 20),
//         decoration: BoxDecoration(
//           color: cardData['color'],
//           borderRadius: BorderRadius.circular(24),
//           boxShadow: const [
//             BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
//           ],
//         ),
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
//         child: SingleChildScrollView(
//           physics: const NeverScrollableScrollPhysics(),
//           child: isSelected
//               ? _buildExpandedContent(cardData)
//               : _buildCollapsedContent(cardData),
//         ),
//       ),
//     );
//   }

//   // Konten saat kartu tertutup (ikon di atas teks)
//   Widget _buildCollapsedContent(Map<String, dynamic> cardData) {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(cardData['icon'], color: Colors.white, size: 36),
//         const SizedBox(height: 8),
//         Text(
//           cardData['title'],
//           style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
//         ),
//       ],
//     );
//   }

//   // Konten saat kartu terbuka
//   Widget _buildExpandedContent(Map<String, dynamic> cardData) {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(cardData['icon'], color: Colors.white, size: 36),
//         const SizedBox(height: 12),
//         Text(
//           cardData['title'],
//           style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: 12),
//         Text(
//           cardData['description'],
//           textAlign: TextAlign.center,
//           style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
//         ),
//         const SizedBox(height: 16),
//         ElevatedButton(
//           onPressed: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => QuestionnaireScreen(
//                   testType: cardData['testType'],
//                   themeColor: cardData['color'],
//                 ),
//               ),
//             );
//           },
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.white,
//             foregroundColor: cardData['color'],
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//             padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
//           ),
//           child: const Text('Ikuti tes'),
//         ),
//       ],
//     );
//   }
// }



