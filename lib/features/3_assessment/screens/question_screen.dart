import 'package:flutter/material.dart';
import 'package:stressapp/features/3_assessment/screens/subjektif_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class QuestionnaireScreen extends StatefulWidget {
  final String testType;
  final Color themeColor;

  const QuestionnaireScreen({
    super.key,
    required this.testType,
    required this.themeColor,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _questionsPerPage = 4;
  late int _totalPages;

  late List<String> _questions;
  final Map<int, double> _answers = {};
  int _selectedInstructionIndex = 1; // Default ke "Selesaikan kuesioner"

  @override
  void initState() {
    super.initState();
    _questions = _getQuestionsForTestType(widget.testType);
    _totalPages = (_questions.length / _questionsPerPage).ceil();
  }

  // (Pastikan semua pertanyaan sudah lengkap)
  List<String> _getQuestionsForTestType(String testType) {
    // ... (fungsi ini tetap sama)
    switch (testType) {
      case 'Stress':
        return [
          "Menjadi marah karena hal-hal kecil/sepele",
          "Cenderung bereaksi berlebihan terhadap suatu situasi",
          "Kesulitan untuk berelaksasi/bersantai",
          "Mudah merasa kesal",
          "Merasa banyak menghasilkan energi karena cemas",
          "Tidak sabaran",
          "Mudah tersinggung",
          "Sulit untuk beristirahat",
          "Mudah marah",
          "Kesulitan untuk tenang setelah sesuatu yang mengganggu",
          "Sulit menteloransi gangguan-gangguan terhadap hal-hal yang dilakukan",
          "Berada pada keadaan tegang",
          "Tidak dapat memaklumi hal apapun yang menghalangi untuk menyelesaikan hal yang sedang dilakukan",
          "Mudah gelisah"
        ];
      case 'Anxiety':
        return [
          "Mulut terasa kering",
          "Merasakan gangguan dalam bernafas (nafas cepat, sulit bernafas)",
          "Kelemahan pada anggota tubuh",
          "Cemas berlebihan dalam suatu situasi namun bisa lega bila situasi/hal itu berakhir",
          "Kelelahan",
          "Berkeringat",
          "Ketakutan tanpa alasan yang jelas",
          "Kesulitan dalam menelan",
          "Perubahan kegiatan jantung dan denyut nadi tanpa stimulasi oleh latihan fisik",
          "Mudah panik",
          "Takut diri terhambat oleh tugas -tugas yang tidak bisa dilakukan",
          "Ketakutan",
          "Khawatir dengan situasi saat diri anda mungkin menjadi panik dan mempermalukan diri anda sendiri",
          "Gemetar"
        ];
      case 'Depression':
        return [
          "Tidak dapat melihat hal yang positif dari suatu kejadian",
          "Merasa tidak kuat lagi untuk melakukan kegiatan",
          "Pesimis",
          "Merasa sedih dan depresi",
          "Kehilangan minat pada banyak hal (misal makan, ambulasi, sosialiasi)",
          "Merasa diri tidak layak",
          "Merasa hidup tidak berharga",
          "Tidak dapat menikmati hal-hal yang dilakukan",
          "Merasa hilang harapan dan putus asa",
          "Sulit untuk antusias pada banyak hal",
          "Berasa tidak berharga",
          "Tidak ada harapan untuk masa depan",
          "Merasa hidup tidak berarti",
          "Sulit untuk meningkatkan inisaitif dalam melakukan sesuatu"
        ];
      default:
        return [];
    }
  }

  Future<void> _processResults() async {
    if (_answers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Harap jawab semua pertanyaan terlebih dahulu.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    int totalScore = 0;
    for (final score in _answers.values) {
      totalScore += score.round();
    }

    String severityLevel;
    if (totalScore <= 14) {
      severityLevel = "Normal";
    } else if (totalScore <= 18)
      severityLevel = "Ringan";
    else if (totalScore <= 25)
      severityLevel = "Sedang";
    else if (totalScore <= 33)
      severityLevel = "Berat";
    else
      severityLevel = "Sangat Berat";

    try {
      final username = supabase.auth.currentUser!.userMetadata?['username'];
      if (username == null) {
        throw Exception('Username tidak ditemukan di sesi login.');
      }

      final pegawaiData = await supabase
          .from('stress_pegawai')
          .select('id_pegawai')
          .eq('username', username)
          .single();

      final pegawaiIntegerId = pegawaiData['id_pegawai'];
      final String todayDate = DateTime.now().toIso8601String().split('T')[0];

      Map<String, dynamic> dataToUpsert = {
        'pegawai_id': pegawaiIntegerId,
        'tanggal_assesment': todayDate, 
      };

      if (widget.testType == 'Stress') {
        dataToUpsert['skor'] = totalScore;
      } else if (widget.testType == 'Anxiety') {
        dataToUpsert['skor_anxiety'] = totalScore;
      } else if (widget.testType == 'Depression') {
        dataToUpsert['skor_depresi'] = totalScore;
      }

      await supabase
          .from('stress_subjektif')
          .upsert(dataToUpsert, onConflict: 'pegawai_id, tanggal_assesment');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Hasil tes berhasil disimpan!'),
              backgroundColor: Colors.green),
        );
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => SubjektifResultScreen(
                      totalScore: totalScore,
                      severityLevel: severityLevel,
                      testType: widget.testType,
                    )));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal menyimpan hasil: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onNextPressed() {
    // ... (fungsi ini tetap sama)
    bool allAnsweredOnPage = true;
    for (int i = _currentPage * _questionsPerPage;
        i < (_currentPage + 1) * _questionsPerPage && i < _questions.length;
        i++) {
      if (!_answers.containsKey(i)) {
        allAnsweredOnPage = false;
        break;
      }
    }

    if (!allAnsweredOnPage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Harap jawab semua pertanyaan di halaman ini.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      _processResults();
    }
  }

  // --- FUNGSI BARU UNTUK MENAMPILKAN POP-UP ---
  void _showFrequencyScaleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Skala Frekuensi"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScaleRow(
                "0", "Tidak sesuai dengan saya sama sekali, atau tidak pernah"),
            _buildScaleRow("1",
                "Sesuai dengan saya sampai tingkat tertentu, atau kadang-kadang"),
            _buildScaleRow("2",
                "Sesuai dengan saya sampai batas yang dapat dipertimbangkan, atau lumayan sering"),
            _buildScaleRow(
                "3", "Sangat sesuai dengan saya, atau sering sekali"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Tutup"),
          )
        ],
      ),
    );
  }

  Widget _buildScaleRow(String score, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$score: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('DASS-42: ${widget.testType} Test'),
        titleTextStyle: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        backgroundColor: widget.themeColor,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Column(
        children: [
          // PANDUAN BARU DITAMBAHKAN DI SINI
          _buildInstructionCard(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemCount: _totalPages,
              itemBuilder: (context, pageIndex) {
                final startIndex = pageIndex * _questionsPerPage;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _questionsPerPage,
                  itemBuilder: (context, itemIndex) {
                    final questionIndex = startIndex + itemIndex;
                    if (questionIndex >= _questions.length)
                      return const SizedBox.shrink();
                    return _buildQuestionItem(
                        questionIndex, _questions[questionIndex]);
                  },
                );
              },
            ),
          ),
          _buildNextButton(),
        ],
      ),
    );
  }

  // --- WIDGET UI YANG DIPERBARUI ---
  Widget _buildInstructionCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _instructionTile(
              0, Icons.info_outline, 'Lihat skala frekuensi di sini'),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _instructionTile(1, Icons.edit, 'Selesaikan kuesioner di bawah ini'),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _instructionTile(2, Icons.check_box, 'Lihat hasil tes DASS-42'),
        ],
      ),
    );
  }

  Widget _instructionTile(int index, IconData icon, String text) {
    bool isSelected = _selectedInstructionIndex == index;
    return InkWell(
      onTap: () {
        if (index == 0) {
          // Jika tile pertama ditekan, tampilkan pop-up
          _showFrequencyScaleDialog();
        } else {
          setState(() => _selectedInstructionIndex = index);
        }
      },
      borderRadius: index == 0
          ? const BorderRadius.only(
              topLeft: Radius.circular(12), topRight: Radius.circular(12))
          : index == 2
              ? const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12))
              : null,
      child: Container(
        color: isSelected
            ? widget.themeColor.withOpacity(0.1)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? widget.themeColor : Colors.grey),
            const SizedBox(width: 16),
            Text(text,
                style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionItem(int questionIndex, String questionText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(questionText,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),

          // GANTI BAGIAN UI OPSI DENGAN ROW BARU INI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Label Kiri
              const Text('Tidak\nPernah',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),

              // Tombol-tombol Opsi
              ...List.generate(4, (answerIndex) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _answers[questionIndex] = answerIndex.toDouble();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _answers[questionIndex]?.round() == answerIndex
                        ? 28
                        : 20,
                    width: _answers[questionIndex]?.round() == answerIndex
                        ? 28
                        : 20,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 4), // Beri sedikit jarak antar tombol
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _answers[questionIndex]?.round() == answerIndex
                          ? widget.themeColor
                          : Colors.grey.shade300,
                    ),
                  ),
                );
              }),

              // Label Kanan
              const Text('Sering\nSekali',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    // ... (fungsi ini tetap sama)
    final buttonText =
        _currentPage == _totalPages - 1 ? 'Selesai' : 'Selanjutnya';
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ElevatedButton(
        onPressed: _onNextPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003D35),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(buttonText,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
