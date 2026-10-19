import 'package:flutter/material.dart';
import 'package:stressapp/features/2_dashboard/screens/dashboard_screen.dart';

class SubjektifResultScreen extends StatelessWidget {
  final int totalScore;
  final String severityLevel;
  final String testType; // Parameter baru untuk mengetahui jenis tes

  const SubjektifResultScreen({
    super.key,
    required this.totalScore,
    required this.severityLevel,
    required this.testType, // Wajib diisi saat navigasi
  });

  // ==========================================================
  // FUNGSI INI DIROMBAK TOTAL UNTUK DESKRIPSI SPESIFIK
  // ==========================================================
  Map<String, dynamic> _getDisplayData(String type, String level) {
    // Tentukan warna berdasarkan tingkat keparahan
    Color color;
    switch (level.toLowerCase()) {
      case 'normal':
        color = Colors.green;
        break;
      case 'ringan':
        color = Colors.yellow.shade700;
        break;
      case 'sedang':
        color = Colors.orange;
        break;
      case 'berat':
        color = Colors.red.shade700;
        break;
      case 'sangat berat':
        color = Colors.purple.shade900;
        break;
      default:
        color = Colors.grey;
    }

    String description;
    switch (type) {
      case 'Stress':
        switch (level.toLowerCase()) {
          case 'normal':
            description =
                "Selamat, tingkat stres Anda normal. Anda tampaknya mampu mengelola tekanan hidup dengan baik. Pertahankan gaya hidup seimbang.";
            break;
          case 'ringan':
            description =
                "Hasil menunjukkan tingkat stres ringan. Ini wajar terjadi. Cobalah luangkan waktu untuk relaksasi dan lakukan hobi yang Anda nikmati.";
            break;
          case 'sedang':
            description =
                "Anda berada pada kategori stres sedang. Penting untuk mulai lebih perhatian pada pemicu stres dan cari cara sehat untuk mengelolanya, seperti olahraga atau meditasi.";
            break;
          case 'berat':
            description =
                "Tingkat stres Anda berat. Kondisi ini dapat memengaruhi kesehatan. Pertimbangkan untuk berbicara dengan teman, keluarga, atau profesional untuk mendapatkan dukungan.";
            break;
          case 'sangat berat':
            description =
                "Hasil menunjukkan tingkat stres sangat berat. Kami sangat menyarankan Anda untuk segera mencari bantuan dari profesional (psikolog/konselor) untuk penanganan yang tepat.";
            break;
          default:
            description = "Tidak ada deskripsi untuk kategori ini.";
        }
        break;
      case 'Anxiety':
        switch (level.toLowerCase()) {
          case 'normal':
            description =
                "Tingkat kecemasan Anda berada dalam rentang normal. Anda menunjukkan ketenangan yang baik dalam menghadapi situasi sehari-hari.";
            break;
          case 'ringan':
            description =
                "Anda mengalami kecemasan ringan, seperti khawatir sesekali. Ini adalah bagian normal dari kehidupan. Teknik pernapasan dalam bisa membantu saat merasa cemas.";
            break;
          case 'sedang':
            description =
                "Kecemasan Anda berada di tingkat sedang. Anda mungkin sering merasa khawatir atau tegang. Cobalah identifikasi penyebabnya dan batasi paparan terhadap pemicu tersebut.";
            break;
          case 'berat':
            description =
                "Hasil tes menunjukkan tingkat kecemasan berat. Ini bisa sangat mengganggu aktivitas harian. Sangat disarankan untuk mencari dukungan dari profesional kesehatan mental.";
            break;
          case 'sangat berat':
            description =
                "Anda mengalami tingkat kecemasan sangat berat. Mohon jangan ragu untuk segera berkonsultasi dengan psikolog atau psikiater untuk mendapatkan bantuan yang efektif.";
            break;
          default:
            description = "Tidak ada deskripsi untuk kategori ini.";
        }
        break;
      case 'Depression':
        switch (level.toLowerCase()) {
          case 'normal':
            description =
                "Hasil Anda menunjukkan tidak ada gejala depresi yang signifikan. Anda memiliki semangat dan pandangan hidup yang positif.";
            break;
          case 'ringan':
            description =
                "Anda mungkin mengalami gejala depresi ringan, seperti perasaan sedih sesekali. Melakukan aktivitas yang Anda sukai dan tetap terhubung dengan orang lain dapat membantu.";
            break;
          case 'sedang':
            description =
                "Gejala depresi Anda berada pada tingkat sedang. Anda mungkin kehilangan minat pada banyak hal. Penting untuk tidak mengabaikan perasaan ini dan berbicara dengan seseorang yang Anda percaya.";
            break;
          case 'berat':
            description =
                "Hasil Anda menunjukkan gejala depresi berat. Ini adalah kondisi serius yang memerlukan perhatian. Mencari bantuan profesional adalah langkah yang sangat penting.";
            break;
          case 'sangat berat':
            description =
                "Anda menunjukkan gejala depresi yang sangat berat. Prioritaskan kesehatan mental Anda dengan segera mencari bantuan dari profesional seperti psikolog atau psikiater.";
            break;
          default:
            description = "Tidak ada deskripsi untuk kategori ini.";
        }
        break;
      default:
        description = "Jenis tes tidak diketahui.";
    }

    return {'color': color, 'description': description};
  }

  @override
  Widget build(BuildContext context) {
    // Panggil helper dengan parameter baru
    final displayData = _getDisplayData(testType, severityLevel);
    final Color themeColor = displayData['color'];
    final String descriptionText = displayData['description'];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 40),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [themeColor.withOpacity(0.8), themeColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hasil Tes',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: themeColor.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              // Judul skor disesuaikan dengan jenis tes
                              Text('Skor $testType Anda',
                                  textAlign: TextAlign.center,
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 8),
                              Text(
                                totalScore.toString(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                            width: 16,
                            height: 60,
                            child: VerticalDivider(color: Colors.white54)),
                        Expanded(
                          child: Column(
                            children: [
                              const Text('Kategori',
                                  style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 8),
                              Text(
                                severityLevel,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Konten Deskripsi
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    descriptionText,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                        fontSize: 16, color: Colors.grey[700], height: 1.8),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      // Kembali ke dashboard dan hapus semua halaman sebelumnya
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => const DashboardScreen()),
                        (Route<dynamic> route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('Kembali ke Beranda',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
