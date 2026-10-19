import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stressapp/features/0_welcome/welcome_screen.dart';
import 'package:stressapp/features/3_assessment/screens/assessment_selection.dart';
import 'package:stressapp/features/3_assessment/screens/hrv_screen.dart';

final supabase = Supabase.instance.client;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _namaPegawai;
  int? _skorStres;
  String? _kategoriStres;
  Map<String, dynamic>? _dataHrv;
  String? _hrvStressCategory;

  List<FlSpot> _stressSpots = [];
  List<FlSpot> _anxietySpots = [];
  List<FlSpot> _depressionSpots = [];

  int _totalStressTests = 0;
  int _totalAnxietyTests = 0;
  int _totalDepressionTests = 0;

  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  final List<String> _graphTitles = ['Stres', 'Anxiety', 'Depresi'];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final username = supabase.auth.currentUser!.userMetadata?['username'];
      if (username == null) throw Exception("User tidak ditemukan");

      final pegawaiData = await supabase
          .from('stress_pegawai')
          .select('id_pegawai, nama_pegawai')
          .eq('username', username)
          .single();
      final pegawaiIntegerId = pegawaiData['id_pegawai'];
      if (!mounted) return;
      setState(() {
        _namaPegawai = pegawaiData['nama_pegawai'];
      });

      final responses = await Future.wait([
        supabase
            .from('stress_subjektif')
            .select('skor')
            .eq('pegawai_id', pegawaiIntegerId)
            .not('skor', 'is', null)
            .order('tanggal_assesment', ascending: false)
            .limit(1)
            .maybeSingle(),
        supabase
            .from('stress_objektif')
            .select()
            .eq('pegawai_id', pegawaiIntegerId)
            .order('tanggal_assesment', ascending: false)
            .limit(1)
            .maybeSingle(),
        supabase
            .from('stress_subjektif')
            .select('skor, skor_anxiety, skor_depresi')
            .eq('pegawai_id', pegawaiIntegerId)
            .order('tanggal_assesment', ascending: true),
      ]);

      if (!mounted) return;

      final skorData = responses[0] as Map<String, dynamic>?;
      final hrvDataResponse = responses[1] as Map<String, dynamic>?;

      String? calculatedHrvCategory;
      if (hrvDataResponse != null && hrvDataResponse['index'] != null) {
        final double stressIndex = (hrvDataResponse['index'] as num).toDouble();
        if (stressIndex >= 500) {
          calculatedHrvCategory = "Very High";
        } else if (stressIndex >= 300)
          calculatedHrvCategory = "High";
        else if (stressIndex >= 150)
          calculatedHrvCategory = "Moderate";
        else if (stressIndex >= 50)
          calculatedHrvCategory = "Normal";
        else
          calculatedHrvCategory = "Low";
      }

      setState(() {
        _skorStres = skorData?['skor'];
        _kategoriStres = _getStressCategory(_skorStres);
        _dataHrv = hrvDataResponse;
        _hrvStressCategory = calculatedHrvCategory;
      });

      final chartDataList = responses[2] as List<dynamic>;

      final allStressScores = chartDataList
          .where((d) => d['skor'] != null)
          .map((d) => (d['skor'] as int).toDouble())
          .toList();
      final allAnxietyScores = chartDataList
          .where((d) => d['skor_anxiety'] != null)
          .map((d) => (d['skor_anxiety'] as int).toDouble())
          .toList();
      final allDepressionScores = chartDataList
          .where((d) => d['skor_depresi'] != null)
          .map((d) => (d['skor_depresi'] as int).toDouble())
          .toList();

      _totalStressTests = allStressScores.length;
      _totalAnxietyTests = allAnxietyScores.length;
      _totalDepressionTests = allDepressionScores.length;

      final last5Stress =
          allStressScores.sublist(max(0, allStressScores.length - 5));
      final last5Anxiety =
          allAnxietyScores.sublist(max(0, allAnxietyScores.length - 5));
      final last5Depression =
          allDepressionScores.sublist(max(0, allDepressionScores.length - 5));

      setState(() {
        _stressSpots = last5Stress
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value))
            .toList();
        _anxietySpots = last5Anxiety
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value))
            .toList();
        _depressionSpots = last5Depression
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Gagal mengambil data: $e"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getStressCategory(int? score) {
    if (score == null) return "N/A";
    if (score <= 14) return "normal";
    if (score <= 18) return "ringan";
    if (score <= 25) return "sedang";
    if (score <= 33) return "berat";
    return "sangat berat";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title:
            Text(_isLoading ? 'Memuat...' : 'Halo! ${_namaPegawai ?? 'User'}'),
        titleTextStyle: const TextStyle(
            color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1.0,
      ),
      drawer: _buildAppDrawer(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStressScoreSection(context),
                    const SizedBox(height: 16),
                    _buildSlidingChartCard(),
                    const SizedBox(height: 16),
                    _buildHrvCard(),
                    const SizedBox(height: 24),
                    _buildActionButtons(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSlidingChartCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Grafik Riwayat ${_graphTitles[_currentPageIndex]}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          size: 16, color: Colors.grey),
                      onPressed: _currentPageIndex == 0
                          ? null
                          : () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.grey),
                      onPressed: _currentPageIndex == _graphTitles.length - 1
                          ? null
                          : () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _currentPageIndex = index),
                children: [
                  _buildChart(_stressSpots, _totalStressTests),
                  _buildChart(_anxietySpots, _totalAnxietyTests),
                  _buildChart(_depressionSpots, _totalDepressionTests),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<FlSpot> spots, int totalCount) {
    if (spots.isEmpty) {
      return const Center(
          child: Text("Belum ada riwayat tes untuk kategori ini."));
    }

    return Padding(
      padding: const EdgeInsets.only(right: 22, top: 10, left: 6),
      child: LineChart(
        LineChartData(
          minY: -2,
          maxY: 45,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.teal.withOpacity(0.8),
              getTooltipItems: (touchedSpots) => touchedSpots
                  .map((barSpot) => LineTooltipItem(
                      barSpot.y.toStringAsFixed(0),
                      const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)))
                  .toList(),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 10,
                getTitlesWidget: (value, meta) {
                  if (value % 10 == 0) {
                    return Text(value.toInt().toString(),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.left);
                  }
                  return const Text('');
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final int startNumber = max(1, totalCount - spots.length + 1);
                  final int currentTestNumber = startNumber + value.toInt();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text('Tes $currentTestNumber',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10)),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.teal,
              barWidth: 4,
              belowBarData:
                  BarAreaData(show: true, color: Colors.teal.withOpacity(0.2)),
              dotData: const FlDotData(show: true),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                const FlLine(color: Colors.black12, strokeWidth: 1),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1.5),
              left: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStressScoreSection(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildMainScoreCard(_skorStres ?? 0)),
          const SizedBox(width: 16),
          Expanded(
              child: _kategoriStres != null
                  ? _buildStressCategoryCard(_kategoriStres!)
                  : const SizedBox()),
        ],
      ),
    );
  }

  Widget _buildMainScoreCard(int score) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.psychology_outlined,
                    color: Colors.teal, size: 35),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Skor stress anda',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('berdasarkan tes DASS-42 terakhir',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              ],
            ),
            const Spacer(),
            Align(
              alignment: Alignment.center,
              child: Text(score.toString(),
                  style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStressCategoryCard(String category) {
    Color cardColor;
    IconData icon;
    String titleText;
    String subText;
    switch (category.toLowerCase()) {
      case 'normal':
        cardColor = Colors.green;
        icon = Icons.sentiment_satisfied_alt;
        titleText = "Anda mengalami stress kategori normal";
        subText = "tetap pertahankan";
        break;
      case 'ringan':
        cardColor = Colors.yellow.shade700;
        icon = Icons.sentiment_neutral;
        titleText = "Anda mengalami stress kategori ringan";
        subText = "lebih rileks";
        break;
      case 'sedang':
        cardColor = Colors.orange;
        icon = Icons.sentiment_neutral;
        titleText = "Anda mengalami stress kategori sedang";
        subText = "perbanyak istirahat";
        break;
      case 'berat':
        cardColor = Colors.red.shade700;
        icon = Icons.sentiment_dissatisfied;
        titleText = "Anda mengalami stress kategori berat";
        subText = "kurangi aktivitas";
        break;
      case 'sangat berat':
        cardColor = Colors.purple.shade900;
        icon = Icons.sentiment_very_dissatisfied;
        titleText = "Anda mengalami stress kategori sangat berat";
        subText = "segera cari bantuan profesional";
        break;
      default:
        cardColor = Colors.grey;
        icon = Icons.help_outline;
        titleText = "Belum ada data";
        subText = "lakukan tes";
    }
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
                alignment: Alignment.topRight,
                child: Icon(icon, color: Colors.white, size: 34)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 4),
                Text(
                  subText,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 13),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.teal),
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text('Menu',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await supabase.auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const WelcomeScreen()),
                    (Route<dynamic> route) => false);
              }
            },
          ),
        ],
      ),
    );
  }

///////////////////////////////////////////////////////////////////////////////
  Widget _buildHrvCard() {
    final stressIndex = _dataHrv?['index']?.toStringAsFixed(2) ?? 'N/A';
    final avgRR = _dataHrv?['avg_rr_interval']?.toStringAsFixed(2) ?? 'N/A';
    final avgHR = _dataHrv?['avg_heart_rate']?.toStringAsFixed(2) ?? 'N/A';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.teal.shade300, size: 20),
                const SizedBox(width: 8),
                const Text('Hasil tes HRV terakhir',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(stressIndex,
                          style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87)),
                      const SizedBox(height: 3),
                      Text((_hrvStressCategory ?? 'N/A').toUpperCase(),
                          style: TextStyle(
                              color: Colors.teal.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 2),
                      const Text('Stress Index (SI)',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildRightHrvMetric(avgRR, 'ms', 'Avg RR Interval'),
                      const SizedBox(height: 20),
                      _buildRightHrvMetric(avgHR, 'BPM', 'Avg Heart Rate'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

/////////////////////////////////////////////////////////////////////////////
  Widget _buildRightHrvMetric(String value, String unit, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Text(unit,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AssessmentSelectionScreen())),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: const Text('TES TINGKAT STRESS ANDA',
              style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const HrvTestScreen())),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.teal,
            side: const BorderSide(color: Colors.teal),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: const Text('HRV TEST'),
        ),
      ],
    );
  }
}
