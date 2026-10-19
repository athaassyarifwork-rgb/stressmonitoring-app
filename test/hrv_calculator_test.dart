import 'package:flutter_test/flutter_test.dart';
import 'package:stressapp/features/3_assessment/screens/hrv_calculator.dart';
void main() {
  group('Pengujian Logika Perhitungan Baevsky Stress Index (HRV)', () {
    
    test('Harus mengembalikan "Data Kurang" jika data RR Interval di bawah 10', () {
      List<int> dataKurang = [800, 820, 810, 805]; 
      
      final result = HrvCalculator.calculateMetrics(dataKurang);
      
      expect(result.stressIndex, 0.0);
      expect(result.stressCategory, "Data Kurang");
    });

    test('Harus mengembalikan "Data Tidak Stabil" jika rentang variasi (Max-Min) di bawah 15ms', () {
      List<int> dataMonoton = [800, 800, 800, 805, 805, 800, 800, 800, 800, 800];
      
      final result = HrvCalculator.calculateMetrics(dataMonoton);
      
      expect(result.stressIndex, 0.0);
      expect(result.stressCategory, "Data Tidak Stabil");
    });

    test('Perhitungan Stress Index harus akurat dan menghasilkan kategori High (Simulasi Matematis)', () {
      List<int> dataNormal = [800, 800, 800, 800, 820, 820, 850, 750, 750, 800];
      
      final result = HrvCalculator.calculateMetrics(dataNormal);
      
      expect(result.avgRRInterval, 799.0); 
      expect(result.stressIndex, closeTo(312.5, 0.1));
      expect(result.stressCategory, "High"); 
    });

    test('Harus menghasilkan kategori Normal untuk data dengan variabilitas tinggi (rileks)', () {
      List<int> dataRileks = [650, 700, 800, 950, 800, 1000, 600, 800, 750, 850];
      
      final result = HrvCalculator.calculateMetrics(dataRileks);
      
      expect(result.stressIndex, lessThan(150.0));
    });

  });
}