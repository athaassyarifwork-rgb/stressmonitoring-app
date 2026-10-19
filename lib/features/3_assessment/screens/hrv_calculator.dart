import 'dart:math';

class HrvResult {
  final double stressIndex;
  final String stressCategory;
  final double avgRRInterval;

  HrvResult(this.stressIndex, this.stressCategory, this.avgRRInterval);
}

class HrvCalculator {
  static HrvResult calculateMetrics(List<int> rrIntervals) {

    if (rrIntervals.length < 10) {
      return HrvResult(0.0, "Data Kurang", 0.0);
    }

    double avgRR = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;

    var modeMap = <int, int>{};
    for (var interval in rrIntervals) {
      modeMap[interval] = (modeMap[interval] ?? 0) + 1;
    }
    var modusEntry = modeMap.entries.reduce((a, b) => a.value > b.value ? a : b);
    
    int modus = modusEntry.key;
    int amoCount = modusEntry.value;
    

    double amoPercent = (amoCount / rrIntervals.length) * 100;
    double moSeconds = modus / 1000.0;
    

    double variationRangeMs = (rrIntervals.reduce(max) - rrIntervals.reduce(min)).toDouble();

    if (variationRangeMs < 15) {
      return HrvResult(0.0, "Data Tidak Stabil", avgRR);
    }
    
    double variationRangeSeconds = variationRangeMs / 1000.0;

    double stressIndex = (moSeconds > 0 && variationRangeSeconds > 0) 
        ? amoPercent / (2 * moSeconds * variationRangeSeconds) 
        : 0.0;

    String stressCategory;
    if (stressIndex >= 500) {
      stressCategory = "Very High";
    } else if (stressIndex >= 300) {
      stressCategory = "High";
    } else if (stressIndex >= 150) {
      stressCategory = "Moderate";
    } else if (stressIndex >= 50) {
      stressCategory = "Normal";
    } else {
      stressCategory = "Low";
    }

    return HrvResult(stressIndex, stressCategory, avgRR);
  }
}