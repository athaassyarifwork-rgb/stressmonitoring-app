import 'dart:async';
import 'dart:math';
import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

enum HrvScreenState { scanning, deviceList, testing, finished }

class HrvTestScreen extends StatefulWidget {
  const HrvTestScreen({super.key});

  @override
  State<HrvTestScreen> createState() => _HrvTestScreenState();
}

class _HrvTestScreenState extends State<HrvTestScreen> {
  HrvScreenState _currentScreenState = HrvScreenState.scanning;
  bool _isBluetoothOn = false;
  bool _isTesting = false;
  Timer? _testTimer;
  int _secondsRemaining = 180;
  final ScrollController _scrollController = ScrollController();
  final List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _valueSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  final List<int> _collectedRRIntervals = [];
  double _stressIndex = 0.0;
  double _avgRRInterval = 0.0;
  double _avgHeartRate = 0.0;
  String _stressCategory = "Normal";

  int _currentHeartRate = 0;
  int _latestRRInterval = 0;

  @override
  void initState() {
    super.initState();
    _initBluetoothAndPermissions();
  }

  @override
  void dispose() {
    _testTimer?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _valueSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _connectedDevice?.disconnect();
    _scrollController.dispose();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _initBluetoothAndPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && mounted && _currentScreenState == HrvScreenState.scanning) {
        setState(() => _currentScreenState = HrvScreenState.deviceList);
      }
    });

    FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() => _isBluetoothOn = state == BluetoothAdapterState.on);
        if (_isBluetoothOn) {
          _startScan();
        } 
      }
    });
  }

  void _startScan() async {
    if (mounted) {
      setState(() {
        _currentScreenState = HrvScreenState.scanning;
        _scanResults.clear();
      });
    }

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          for (var r in results) {
            // FILTER: Hanya masukkan perangkat yang punya nama
            // Serta pastikan belum ada di list agar tidak duplikat
            if (r.device.advName.isNotEmpty && r.device.advName != "Unknown Device") {
              if (!_scanResults.any((sr) => sr.device.remoteId == r.device.remoteId)) {
                _scanResults.add(r);
              }
            }
          }
        });
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Error startScan: $e");
    } finally {
      if (mounted && _currentScreenState == HrvScreenState.scanning) {
        setState(() => _currentScreenState = HrvScreenState.deviceList);
      }
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _connectedDevice = device;
    _connectionSubscription = _connectedDevice!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected && mounted) {
        setState(() => _currentScreenState = HrvScreenState.testing);
        _discoverServices();
      }
    });

    await _connectedDevice!.connect(
      autoConnect: false, 
      timeout: const Duration(seconds: 10),
      license: License.commercial // Tetap dipertahankan agar tidak error
    );
  }

  // ... (Fungsi _discoverServices, _subscribeToCharacteristic, _startTest, _finishTest, _calculateFinalMetrics TETAP SAMA) ...

  void _discoverServices() async {
    final services = await _connectedDevice!.discoverServices();
    for (var service in services) {
      if (service.uuid.toString().toUpperCase().contains("180D")) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().toUpperCase().contains("2A37")) {
            _subscribeToCharacteristic(char);
            return;
          }
        }
      }
    }
  }

  void _subscribeToCharacteristic(BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(true);
    _valueSubscription = characteristic.lastValueStream.listen((value) {
      if (value.isNotEmpty && mounted) {

        debugPrint('DATA SENSOR MASUK: $value');

        int newHeartRate = value[1];
        int newRRInterval = _latestRRInterval;
        if (_isTesting && value.length > 3) {
          int rr = value[2] | (value[3] << 8);
          double rrMs = rr * 0.625;
          newRRInterval = rrMs.toInt();
          _collectedRRIntervals.add(newRRInterval);
        }
        setState(() {
          _currentHeartRate = newHeartRate;
          _latestRRInterval = newRRInterval;
        });
      }
    });
  }

  void _startTest() {
    setState(() {
      _isTesting = true;
      _secondsRemaining = 180;
      _collectedRRIntervals.clear();
      _latestRRInterval = 0;
    });
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
          if (_collectedRRIntervals.isNotEmpty) {
            double meanRR = _collectedRRIntervals.reduce((a, b) => a + b) / _collectedRRIntervals.length;
            _avgHeartRate = 60000 / meanRR;
          }
        });
      } else {
        _finishTest();
      }
    });
  }

  void _finishTest() {
    _testTimer?.cancel();
    _calculateFinalMetrics();
    setState(() {
      _isTesting = false;
      _currentScreenState = HrvScreenState.finished;
    });
  }

  void _calculateFinalMetrics() {
    if (_collectedRRIntervals.length < 10) {
      setState(() { _stressIndex = 0; _stressCategory = "Data Kurang"; });
      return;
    }
    _avgRRInterval = _collectedRRIntervals.reduce((a, b) => a + b) / _collectedRRIntervals.length;
    var modeMap = <int, int>{};
    for (var interval in _collectedRRIntervals) {
      modeMap[interval] = (modeMap[interval] ?? 0) + 1;
    }
    var modusEntry = modeMap.entries.reduce((a, b) => a.value > b.value ? a : b);
    int modus = modusEntry.key;
    int amoCount = modusEntry.value;
    double amoPercent = (amoCount / _collectedRRIntervals.length) * 100;
    double moSeconds = modus / 1000.0;
    double variationRangeMs = (_collectedRRIntervals.reduce(max) - _collectedRRIntervals.reduce(min)).toDouble();

    if (variationRangeMs < 15) {
      setState(() { _stressIndex = 0; _stressCategory = "Data Tidak Stabil"; });
      return;
    }
    double variationRangeSeconds = variationRangeMs / 1000.0;
    _stressIndex = (moSeconds > 0 && variationRangeSeconds > 0) ? amoPercent / (2 * moSeconds * variationRangeSeconds) : 0;

    if (_stressIndex >= 500) { _stressCategory = "Very High"; } 
    else if (_stressIndex >= 300) { _stressCategory = "High"; } 
    else if (_stressIndex >= 150) { _stressCategory = "Moderate"; } 
    else if (_stressIndex >= 50) { _stressCategory = "Normal"; } 
    else { _stressCategory = "Low"; }

    _saveResultsToSupabase();
  }

  Future<void> _saveResultsToSupabase() async {
    try {
      final username = supabase.auth.currentUser!.userMetadata?['username'];
      final pegawaiData = await supabase.from('stress_pegawai').select('id_pegawai').eq('username', username).single();
      final pegawaiIntegerId = pegawaiData['id_pegawai'];
      final String todayDate = DateTime.now().toIso8601String().split('T')[0];

      await supabase.from('stress_objektif').upsert({
        'pegawai_id': pegawaiIntegerId,
        'tanggal_assesment': todayDate,
        'index': _stressIndex,
        'avg_rr_interval': _avgRRInterval,
        'avg_heart_rate': _avgHeartRate,
      }, onConflict: 'pegawai_id, tanggal_assesment');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hasil HRV berhasil disimpan!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan hasil: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- UI ORIGINAL ANDA ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
                _buildTopSection(),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildContentForState(),
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

  Widget _buildContentForState() {
    switch (_currentScreenState) {
      case HrvScreenState.scanning:
      case HrvScreenState.deviceList:
        return _buildDeviceListContent(); // Gunakan satu UI untuk list & scanning
      case HrvScreenState.testing:
        return _buildTimerContent();
      case HrvScreenState.finished:
        return _buildResultContent();
    }
  }

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBar(
            title: const Text('HRV TEST PAGE', style: TextStyle(color: Colors.white, fontSize: 14)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('HRV test', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildInfoCard(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceListContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Pilih Perangkat Anda", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isBluetoothOn ? _startScan : null,
              ),
            ],
          ),
        ),
        if (_currentScreenState == HrvScreenState.scanning)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Mencari perangkat..."),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _scanResults.length,
            itemBuilder: (context, index) {
              final result = _scanResults[index];
              final deviceName = result.device.advName;
              return ListTile(
                title: Text(deviceName),
                subtitle: Text(result.device.remoteId.toString()),
                onTap: () => _connectToDevice(result.device),
              );
            },
          ),
        ),
      ],
    );
  }

  // ... (Widget _buildTimerContent, _buildRealtimeMetric, _buildResultContent, _buildRightHrvMetric, _buildInfoCard TETAP SAMA) ...

  Widget _buildTimerContent() {
    if (!_isTesting) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.touch_app, color: Colors.teal, size: 80),
            const SizedBox(height: 24),
            const Text('Siap Memulai Tes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Detak Jantung Saat Ini: $_currentHeartRate BPM', style: const TextStyle(fontSize: 18, color: Colors.grey)),
            const Spacer(),
            ElevatedButton(
              onPressed: _connectedDevice != null ? _startTest : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('MULAI HRV TEST'),
            ),
          ],
        ),
      );
    }
    double progress = (180 - _secondsRemaining) / 180.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          _buildRealtimeMetric('Detak Jantung', _currentHeartRate.toString(), 'BPM'),
          const Divider(height: 40),
          _buildRealtimeMetric('Interval R-R', _latestRRInterval.toString(), 'ms'),
          const SizedBox(height: 60),
          LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.grey.shade200, color: Colors.teal, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 8),
          Text('Sisa Waktu: $_secondsRemaining detik', style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildRealtimeMetric(String title, String value, String unit) {
    return Column(children: [Text(title, style: const TextStyle(fontSize: 20, color: Colors.grey)), const SizedBox(height: 8), Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text(value, style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(width: 8), Text(unit, style: const TextStyle(fontSize: 20, color: Colors.black54))])]);
  }

  Widget _buildResultContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), color: Colors.grey.shade100, child: Padding(padding: const EdgeInsets.all(16.0), child: Column(children: [Row(children: [Icon(Icons.favorite, color: Colors.teal.shade300), const SizedBox(width: 8), const Text('Hasil tes HRV terakhir', style: TextStyle(fontWeight: FontWeight.bold))]), const SizedBox(height: 16), Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Text(_stressIndex.toStringAsFixed(2), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(_stressCategory.toUpperCase(), style: TextStyle(color: Colors.teal.shade400, fontWeight: FontWeight.bold)), const Text('Stress Index (SI)', style: TextStyle(color: Colors.grey))])), Expanded(flex: 2, child: Column(children: [_buildRightHrvMetric(_avgRRInterval.toStringAsFixed(1), 'ms', 'Avg RR Interval'), const SizedBox(height: 20), _buildRightHrvMetric(_avgHeartRate.toStringAsFixed(1), 'BPM', 'Avg Heart Rate')]))])]))),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Kembali ke Beranda', style: TextStyle(color: Colors.white)))
        ],
      ),
    );
  }

  Widget _buildRightHrvMetric(String value, String unit, String label) {
    return Column(children: [Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(width: 4), Text(unit, style: const TextStyle(color: Colors.grey))]), const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.grey))]);
  }

  Widget _buildInfoCard() {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.info_outline, color: Colors.white, size: 20), SizedBox(width: 12), Expanded(child: Text('Untuk memulai HRV test, pastikan koneksi bluethooth pada perangkat anda sudah aktif (Anda tidak perlu melakukan "pairing" dengan perangkat Coospo).', style: TextStyle(color: Colors.white70, fontSize: 13)))]));
  }
}

// import 'dart:async';
// import 'dart:math';
// import 'dart:io'; // Penting untuk mengecek Platform
// import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// final supabase = Supabase.instance.client;

// enum HrvScreenState { scanning, deviceList, testing, finished }

// class HrvTestScreen extends StatefulWidget {
//   const HrvTestScreen({super.key});

//   @override
//   State<HrvTestScreen> createState() => _HrvTestScreenState();
// }

// class _HrvTestScreenState extends State<HrvTestScreen> {
//   HrvScreenState _currentScreenState = HrvScreenState.scanning;
//   bool _isBluetoothOn = false;
//   bool _isTesting = false;
//   // Variabel _isTestFinished dihapus karena tidak digunakan
//   Timer? _testTimer;
//   int _secondsRemaining = 180;
//   final ScrollController _scrollController = ScrollController();
//   final List<ScanResult> _scanResults = [];
//   BluetoothDevice? _connectedDevice;
//   StreamSubscription<List<ScanResult>>? _scanSubscription;
//   StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
//   StreamSubscription<List<int>>? _valueSubscription;
//   StreamSubscription<bool>? _isScanningSubscription;

//   final List<int> _collectedRRIntervals = [];
//   double _stressIndex = 0.0;
//   double _avgRRInterval = 0.0;
//   double _avgHeartRate = 0.0;
//   String _stressCategory = "Normal";

//   int _currentHeartRate = 0;
//   int _latestRRInterval = 0;

//   @override
//   void initState() {
//     super.initState();
//     _initBluetoothAndPermissions();
//   }

//   @override
//   void dispose() {
//     _testTimer?.cancel();
//     _scanSubscription?.cancel();
//     _connectionSubscription?.cancel();
//     _valueSubscription?.cancel();
//     _isScanningSubscription?.cancel();
//     _connectedDevice?.disconnect();
//     _scrollController.dispose();
//     FlutterBluePlus.stopScan();
//     super.dispose();
//   }

//   Future<void> _initBluetoothAndPermissions() async {
//     if (Platform.isAndroid) {
//       await [
//         Permission.bluetoothScan,
//         Permission.bluetoothConnect,
//         Permission.location,
//       ].request();
//     }

//     _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
//       if (!scanning &&
//           mounted &&
//           _currentScreenState == HrvScreenState.scanning) {
//         setState(() => _currentScreenState = HrvScreenState.deviceList);
//       }
//     });

//     FlutterBluePlus.adapterState.listen((state) {
//       if (mounted) {
//         setState(() => _isBluetoothOn = state == BluetoothAdapterState.on);
//         if (_isBluetoothOn) {
//           _startScan();
//         }
//       }
//     });
//   }

//   void _startScan() async {
//     if (mounted) {
//       setState(() {
//         _currentScreenState = HrvScreenState.scanning;
//         _scanResults.clear();
//       });
//     }

//     _scanSubscription?.cancel();
//     _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
//       if (mounted) {
//         setState(() {
//           for (var r in results) {
//             if (r.device.advName.isNotEmpty &&
//                 r.device.advName != "Unknown Device") {
//               if (!_scanResults
//                   .any((sr) => sr.device.remoteId == r.device.remoteId)) {
//                 _scanResults.add(r);
//               }
//             }
//           }
//         });
//       }
//     });

//     try {
//       await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
//     } catch (e) {
//       debugPrint("Error startScan: $e");
//     } finally {
//       if (mounted && _currentScreenState == HrvScreenState.scanning) {
//         setState(() => _currentScreenState = HrvScreenState.deviceList);
//       }
//     }
//   }

//   void _connectToDevice(BluetoothDevice device) async {
//     await FlutterBluePlus.stopScan();
//     _scanSubscription?.cancel();
//     _connectedDevice = device;
//     _connectionSubscription = _connectedDevice!.connectionState.listen((state) {
//       if (state == BluetoothConnectionState.connected && mounted) {
//         setState(() => _currentScreenState = HrvScreenState.testing);
//         _discoverServices();
//       }
//     });

//     // Perbaikan: Menambahkan parameter license yang diwajibkan
//     await _connectedDevice!.connect(
//         autoConnect: false,
//         timeout: const Duration(seconds: 10),
//         license: License.commercial);
//   }

//   void _discoverServices() async {
//     final services = await _connectedDevice!.discoverServices();
//     for (var service in services) {
//       if (service.uuid.toString().toUpperCase().contains("180D")) {
//         for (var char in service.characteristics) {
//           if (char.uuid.toString().toUpperCase().contains("2A37")) {
//             _subscribeToCharacteristic(char);
//             return;
//           }
//         }
//       }
//     }
//   }

//   void _subscribeToCharacteristic(
//       BluetoothCharacteristic characteristic) async {
//     await characteristic.setNotifyValue(true);
//     _valueSubscription = characteristic.lastValueStream.listen((value) {
//       if (value.isNotEmpty && mounted) {
//         int newHeartRate = value[1];
//         int newRRInterval = _latestRRInterval;

//         if (_isTesting && value.length > 3) {
//           int rr = value[2] | (value[3] << 8);
//           double rrMs = rr * 0.625;
//           newRRInterval = rrMs.toInt();
//           _collectedRRIntervals.add(newRRInterval);
//         }

//         setState(() {
//           _currentHeartRate = newHeartRate;
//           _latestRRInterval = newRRInterval;
//         });
//       }
//     });
//   }

//   void _startTest() {
//     setState(() {
//       _isTesting = true;
//       _secondsRemaining = 180;
//       _collectedRRIntervals.clear();
//       _latestRRInterval = 0;
//     });
//     _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_secondsRemaining > 0) {
//         setState(() {
//           _secondsRemaining--;
//           if (_collectedRRIntervals.isNotEmpty) {
//             double meanRR = _collectedRRIntervals.reduce((a, b) => a + b) /
//                 _collectedRRIntervals.length;
//             _avgHeartRate = 60000 / meanRR;
//           }
//         });
//       } else {
//         _finishTest();
//       }
//     });
//   }

//   void _finishTest() {
//     _testTimer?.cancel();
//     _calculateFinalMetrics();
//     setState(() {
//       _isTesting = false;
//       _currentScreenState = HrvScreenState.finished;
//     });
//   }

//   void _calculateFinalMetrics() {
//     if (_collectedRRIntervals.length < 10) {
//       setState(() {
//         _stressIndex = 0;
//         _stressCategory = "Data Kurang";
//       });
//       return;
//     }
//     _avgRRInterval = _collectedRRIntervals.reduce((a, b) => a + b) /
//         _collectedRRIntervals.length;
//     var modeMap = <int, int>{};
//     for (var interval in _collectedRRIntervals) {
//       modeMap[interval] = (modeMap[interval] ?? 0) + 1;
//     }
//     var modusEntry =
//         modeMap.entries.reduce((a, b) => a.value > b.value ? a : b);
//     int modus = modusEntry.key;
//     int amoCount = modusEntry.value;
//     double amoPercent = (amoCount / _collectedRRIntervals.length) * 100;
//     double moSeconds = modus / 1000.0;
//     double variationRangeMs =
//         (_collectedRRIntervals.reduce(max) - _collectedRRIntervals.reduce(min))
//             .toDouble();

//     if (variationRangeMs < 15) {
//       setState(() {
//         _stressIndex = 0;
//         _stressCategory = "Data Tidak Stabil";
//       });
//       return;
//     }
//     double variationRangeSeconds = variationRangeMs / 1000.0;
//     _stressIndex = (moSeconds > 0 && variationRangeSeconds > 0)
//         ? amoPercent / (2 * moSeconds * variationRangeSeconds)
//         : 0;

//     // Perbaikan: Menambahkan kurung kurawal pada blok if-else
//     if (_stressIndex >= 500) {
//       _stressCategory = "Very High";
//     } else if (_stressIndex >= 300) {
//       _stressCategory = "High";
//     } else if (_stressIndex >= 150) {
//       _stressCategory = "Moderate";
//     } else if (_stressIndex >= 50) {
//       _stressCategory = "Normal";
//     } else {
//       _stressCategory = "Low";
//     }

//     _saveResultsToSupabase();
//   }

//   Future<void> _saveResultsToSupabase() async {
//     try {
//       final username = supabase.auth.currentUser!.userMetadata?['username'];
//       final pegawaiData = await supabase
//           .from('stress_pegawai')
//           .select('id_pegawai')
//           .eq('username', username)
//           .single();
//       final pegawaiIntegerId = pegawaiData['id_pegawai'];
//       final String todayDate = DateTime.now().toIso8601String().split('T')[0];

//       await supabase.from('stress_objektif').upsert({
//         'pegawai_id': pegawaiIntegerId,
//         'tanggal_assesment': todayDate,
//         'index': _stressIndex,
//         'avg_rr_interval': _avgRRInterval,
//         'avg_heart_rate': _avgHeartRate,
//       }, onConflict: 'pegawai_id, tanggal_assesment');

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//               content: Text('Hasil HRV berhasil disimpan!'),
//               backgroundColor: Colors.green),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//               content: Text('Gagal menyimpan hasil: $e'),
//               backgroundColor: Colors.red),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Color(0xFF00B5AD), Color(0xFF008983)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),
//           SafeArea(
//             child: Column(
//               children: [
//                 _buildTopSection(),
//                 Expanded(
//                   child: Container(
//                     width: double.infinity,
//                     decoration: const BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.only(
//                           topLeft: Radius.circular(30),
//                           topRight: Radius.circular(30)),
//                     ),
//                     child: AnimatedSwitcher(
//                       duration: const Duration(milliseconds: 300),
//                       child: _buildContentForState(),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildContentForState() {
//     switch (_currentScreenState) {
//       case HrvScreenState.scanning:
//         return _buildScanningLoader();
//       case HrvScreenState.deviceList:
//         return _buildDeviceListContent();
//       case HrvScreenState.testing:
//         return _buildTimerContent();
//       case HrvScreenState.finished:
//         return _buildResultContent();
//     }
//   }

//   Widget _buildScanningLoader() {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         const CircularProgressIndicator(color: Colors.teal),
//         const SizedBox(height: 16),
//         const Text("Mencari perangkat...",
//             style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
//       ],
//     );
//   }

//   Widget _buildTopSection() {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           AppBar(
//             title: const Text('HRV TEST PAGE',
//                 style: TextStyle(color: Colors.white, fontSize: 14)),
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             iconTheme: const IconThemeData(color: Colors.white),
//           ),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text('HRV test',
//                     style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 32,
//                         fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 16),
//                 _buildInfoCard(),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDeviceListContent() {
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text("Pilih Perangkat Anda",
//                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
//               IconButton(
//                   icon: const Icon(Icons.refresh),
//                   onPressed: _isBluetoothOn ? _startScan : null),
//             ],
//           ),
//         ),
//         if (_scanResults.isEmpty)
//           const Expanded(
//               child: Center(
//                   child: Text(
//                       "Tidak ada perangkat ditemukan.\nPastikan GPS aktif & sensor dipakai.",
//                       textAlign: TextAlign.center)))
//         else
//           Expanded(
//             child: ListView.builder(
//               itemCount: _scanResults.length,
//               itemBuilder: (context, index) {
//                 final result = _scanResults[index];
//                 final name = result.device.advName.isNotEmpty
//                     ? result.device.advName
//                     : "Unknown Device";
//                 return ListTile(
//                   leading: const Icon(Icons.bluetooth, color: Colors.teal),
//                   title: Text(name,
//                       style: const TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: Text(result.device.remoteId.toString()),
//                   onTap: () => _connectToDevice(result.device),
//                 );
//               },
//             ),
//           ),
//       ],
//     );
//   }

//   Widget _buildTimerContent() {
//     if (!_isTesting) {
//       return Padding(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.touch_app, color: Colors.teal, size: 80),
//             const SizedBox(height: 24),
//             const Text('Siap Memulai Tes',
//                 style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
//             const Spacer(),
//             ElevatedButton(
//               onPressed: _connectedDevice != null ? _startTest : null,
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.teal.shade700,
//                   foregroundColor: Colors.white,
//                   minimumSize: const Size(double.infinity, 50),
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16))),
//               child: const Text('MULAI HRV TEST'),
//             ),
//           ],
//         ),
//       );
//     }
//     double progress = (180 - _secondsRemaining) / 180.0;
//     return Padding(
//       padding: const EdgeInsets.all(32),
//       child: Column(
//         children: [
//           _buildRealtimeMetric(
//               'Detak Jantung', _currentHeartRate.toString(), 'BPM'),
//           const Divider(height: 40),
//           _buildRealtimeMetric(
//               'Interval R-R', _latestRRInterval.toString(), 'ms'),
//           const Spacer(),
//           LinearProgressIndicator(
//               value: progress,
//               minHeight: 8,
//               color: Colors.teal,
//               borderRadius: BorderRadius.circular(4)),
//           const SizedBox(height: 8),
//           Text('Sisa Waktu: $_secondsRemaining detik'),
//         ],
//       ),
//     );
//   }

//   Widget _buildRealtimeMetric(String title, String value, String unit) {
//     return Column(children: [
//       Text(title, style: const TextStyle(fontSize: 18, color: Colors.grey)),
//       Row(mainAxisAlignment: MainAxisAlignment.center, children: [
//         Text(value,
//             style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold)),
//         const SizedBox(width: 8),
//         Text(unit, style: const TextStyle(fontSize: 20))
//       ])
//     ]);
//   }

//   Widget _buildResultContent() {
//     return Padding(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         children: [
//           Card(
//             elevation: 0,
//             color: Colors.grey.shade100,
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 children: [
//                   Text(_stressIndex.toStringAsFixed(2),
//                       style: const TextStyle(
//                           fontSize: 48, fontWeight: FontWeight.w900)),
//                   Text(_stressCategory.toUpperCase(),
//                       style: const TextStyle(
//                           color: Colors.teal, fontWeight: FontWeight.bold)),
//                 ],
//               ),
//             ),
//           ),
//           const Spacer(),
//           ElevatedButton(
//               onPressed: () => Navigator.of(context).pop(),
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.teal.shade700,
//                   foregroundColor: Colors.white,
//                   minimumSize: const Size(double.infinity, 50),
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16))),
//               child: const Text('Kembali')),
//         ],
//       ),
//     );
//   }

//   Widget _buildRightHrvMetric(String value, String unit, String label) {
//     return Column(children: [
//       Text(value,
//           style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//       Text(unit),
//       Text(label)
//     ]);
//   }

//   Widget _buildInfoCard() {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//           color: Colors.black.withOpacity(0.1),
//           borderRadius: BorderRadius.circular(8)),
//       child: const Row(children: [
//         Icon(Icons.info_outline, color: Colors.white, size: 20),
//         SizedBox(width: 12),
//         Expanded(
//             child: Text('Pastikan Bluetooth dan GPS HP aktif.',
//                 style: TextStyle(color: Colors.white70, fontSize: 12)))
//       ]),
//     );
//   }
// }

// import 'dart:async';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'dart:io';

// final supabase = Supabase.instance.client;

// enum HrvScreenState { scanning, deviceList, testing, finished }

// class HrvTestScreen extends StatefulWidget {
//   const HrvTestScreen({super.key});

//   @override
//   State<HrvTestScreen> createState() => _HrvTestScreenState();
// }


// class _HrvTestScreenState extends State<HrvTestScreen> {
//   HrvScreenState _currentScreenState = HrvScreenState.scanning;
//   bool _isBluetoothOn = false;
//   bool _isTesting = false;
//   bool _isTestFinished = false;
//   Timer? _testTimer;
//   int _secondsRemaining = 180;
//   final ScrollController _scrollController = ScrollController();
//   final List<ScanResult> _scanResults = [];
//   BluetoothDevice? _connectedDevice;
//   StreamSubscription<List<ScanResult>>? _scanSubscription;
//   StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
//   StreamSubscription<List<int>>? _valueSubscription;
//   final List<int> _collectedRRIntervals = [];
//   double _stressIndex = 0.0;
//   double _avgRRInterval = 0.0;
//   double _avgHeartRate = 0.0;
//   String _stressCategory = "Normal";

//   // Variabel untuk data real-time
//   int _currentHeartRate = 0;
//   int _latestRRInterval = 0;

//   @override
//   void initState() {
//     super.initState();
//     _checkBluetoothStatus();
//   }

//   @override
//   void dispose() {
//     _testTimer?.cancel();
//     _scanSubscription?.cancel();
//     _connectionSubscription?.cancel();
//     _valueSubscription?.cancel();
//     _connectedDevice?.disconnect();
//     _scrollController.dispose();
//     FlutterBluePlus.stopScan();
//     super.dispose();
//   }

//   Future<void> requestPermissions() async {
//   if (Platform.isAndroid) {
//     await [
//       Permission.bluetoothScan,
//       Permission.bluetoothConnect,
//       Permission.location,
//     ].request();
//   }
// }

//   Future<void> _checkBluetoothStatus() async {
//     Map<Permission, PermissionStatus> statuses = await [
//       Permission.bluetoothScan,
//       Permission.bluetoothConnect,
//       Permission.location,
//     ].request();

//     if (statuses[Permission.bluetoothScan]!.isGranted &&
//         statuses[Permission.bluetoothConnect]!.isGranted &&
//         statuses[Permission.location]!.isGranted) {
//       FlutterBluePlus.adapterState.listen((state) {
//         if (mounted) {
//           setState(() => _isBluetoothOn = state == BluetoothAdapterState.on);
//           if (_isBluetoothOn) {
//             _startScan();
//           }
//         }
//       });
//     } else {
//       print("Satu atau lebih izin ditolak oleh pengguna.");
//     }
//   }

//   void _startScan() {
//     if (mounted) {
//       setState(() {
//         _currentScreenState = HrvScreenState.scanning;
//         _scanResults.clear();
//       });
//     }
//     _scanSubscription?.cancel();
//     _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
//       for (var r in results) {
//         if (r.device.advName.isNotEmpty &&
//             !_scanResults
//                 .any((sr) => sr.device.remoteId == r.device.remoteId)) {
//           if (mounted) {
//             setState(() => _scanResults.add(r));
//           }
//         }
//       }
//     });
//     FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
//     Future.delayed(const Duration(seconds: 10), () {
//       if (mounted && _currentScreenState == HrvScreenState.scanning) {
//         setState(() => _currentScreenState = HrvScreenState.deviceList);
//       }
//     });
//   }

//   void _connectToDevice(BluetoothDevice device) async {
//     await FlutterBluePlus.stopScan();
//     _scanSubscription?.cancel();
//     _connectedDevice = device;
//     _connectionSubscription = _connectedDevice!.connectionState.listen((state) {
//       if (state == BluetoothConnectionState.connected && mounted) {
//         setState(() => _currentScreenState = HrvScreenState.testing);
//         _discoverServices();
//       }
//     });
//     await _connectedDevice!
//         .connect(autoConnect: false, license: License.commercial);
//   }

//   void _discoverServices() async {
//     final services = await _connectedDevice!.discoverServices();
//     for (var service in services) {
//       if (service.uuid.toString().toUpperCase().contains("180D")) {
//         for (var char in service.characteristics) {
//           if (char.uuid.toString().toUpperCase().contains("2A37")) {
//             _subscribeToCharacteristic(char);
//             return;
//           }
//         }
//       }
//     }
//   }

//   void _subscribeToCharacteristic(
//       BluetoothCharacteristic characteristic) async {
//     await characteristic.setNotifyValue(true);
//     _valueSubscription = characteristic.lastValueStream.listen((value) {
//       if (value.isNotEmpty && mounted) {
//         int newHeartRate = value[1];

//         int newRRInterval = _latestRRInterval;
//         if (_isTesting && value.length > 2) {
//           int rr = value[2] | (value[3] << 8);
//           double rrMs = rr * 0.625;
//           newRRInterval = rrMs.toInt();
//           _collectedRRIntervals.add(newRRInterval);
//         }

//         setState(() {
//           _currentHeartRate = newHeartRate;
//           _latestRRInterval = newRRInterval;
//         });
//       }
//     });
//   }

//   void _startTest() {
//     setState(() {
//       _isTesting = true;
//       _isTestFinished = false;
//       _secondsRemaining = 180;
//       _collectedRRIntervals.clear();
//       _latestRRInterval = 0;
//     });
//     _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_secondsRemaining > 0) {
//         setState(() {
//           _secondsRemaining--;
//           if (_collectedRRIntervals.isNotEmpty) {
//             double meanRR = _collectedRRIntervals.reduce((a, b) => a + b) /
//                 _collectedRRIntervals.length;
//             _avgHeartRate = 60000 / meanRR;
//           }
//         });
//       } else {
//         _finishTest();
//       }
//     });
//   }

//   void _finishTest() {
//     _testTimer?.cancel();
//     _calculateFinalMetrics();
//     setState(() {
//       _isTesting = false;
//       _isTestFinished = true;
//       _currentScreenState = HrvScreenState.finished;
//     });
//   }

//   void _calculateFinalMetrics() {
//     if (_collectedRRIntervals.length < 10) {
//       setState(() {
//         _stressIndex = 0;
//         _stressCategory = "Data Kurang";
//       });
//       return;
//     }
//     _avgRRInterval = _collectedRRIntervals.reduce((a, b) => a + b) /
//         _collectedRRIntervals.length;
//     var modeMap = <int, int>{};
//     for (var interval in _collectedRRIntervals) {
//       modeMap[interval] = (modeMap[interval] ?? 0) + 1;
//     }
//     var modusEntry =
//         modeMap.entries.reduce((a, b) => a.value > b.value ? a : b);
//     int modus = modusEntry.key;
//     int amoCount = modusEntry.value;
//     double amoPercent = (amoCount / _collectedRRIntervals.length) * 100;
//     double moSeconds = modus / 1000.0;
//     double variationRangeMs =
//         (_collectedRRIntervals.reduce(max) - _collectedRRIntervals.reduce(min))
//             .toDouble();

//     if (variationRangeMs < 15) {
//       setState(() {
//         _stressIndex = 0;
//         _stressCategory = "Data Tidak Stabil";
//       });
//       return;
//     }
//     double variationRangeSeconds = variationRangeMs / 1000.0;
//     if (moSeconds > 0 && variationRangeSeconds > 0) {
//       _stressIndex = amoPercent / (2 * moSeconds * variationRangeSeconds);
//     } else {
//       _stressIndex = 0;
//     }
//     if (_stressIndex >= 500) {
//       _stressCategory = "Very High";
//     } else if (_stressIndex >= 300)
//       _stressCategory = "High";
//     else if (_stressIndex >= 150)
//       _stressCategory = "Moderate";
//     else if (_stressIndex >= 50)
//       _stressCategory = "Normal";
//     else
//       _stressCategory = "Low";
//     _saveResultsToSupabase();
//   }

//   Future<void> _saveResultsToSupabase() async {
//     try {
//       final username = supabase.auth.currentUser!.userMetadata?['username'];
//       final pegawaiData = await supabase
//           .from('stress_pegawai')
//           .select('id_pegawai')
//           .eq('username', username)
//           .single();
//       final pegawaiIntegerId = pegawaiData['id_pegawai'];

//       final String todayDate = DateTime.now().toIso8601String().split('T')[0];

//     // 2. Ganti .insert() menjadi .upsert()
//     // Pastikan onConflict sesuai dengan Unique Constraint yang dibuat di SQL Supabase
//       await supabase.from('stress_objektif').upsert({
//         'pegawai_id': pegawaiIntegerId,
//         'tanggal_assesment': todayDate, // Gunakan tanggal tanpa komponen waktu
//         'index': _stressIndex,
//         'avg_rr_interval': _avgRRInterval,
//         'avg_heart_rate': _avgHeartRate,
//       }, onConflict: 'pegawai_id, tanggal_assesment');
      
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//               content: Text('Hasil HRV berhasil disimpan!'),
//               backgroundColor: Colors.green),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//               content: Text('Gagal menyimpan hasil: $e'),
//               backgroundColor: Colors.red),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Color(0xFF00B5AD), Color(0xFF008983)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),
//           SafeArea(
//             child: Column(
//               children: [
//                 _buildTopSection(),
//                 Expanded(
//                   child: Container(
//                     width: double.infinity,
//                     decoration: const BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.only(
//                         topLeft: Radius.circular(30),
//                         topRight: Radius.circular(30),
//                       ),
//                     ),
//                     child: AnimatedSwitcher(
//                       duration: const Duration(milliseconds: 300),
//                       child: _buildContentForState(),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildContentForState() {
//     switch (_currentScreenState) {
//       case HrvScreenState.scanning:
//       case HrvScreenState.deviceList:
//         return _buildDeviceListContent();
//       case HrvScreenState.testing:
//         return _buildTimerContent();
//       case HrvScreenState.finished:
//         return _buildResultContent();
//     }
//   }

//   Widget _buildTopSection() {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           AppBar(
//             title: const Text('HRV TEST PAGE',
//                 style: TextStyle(color: Colors.white, fontSize: 14)),
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             iconTheme: const IconThemeData(color: Colors.white),
//           ),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text('HRV test',
//                     style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 32,
//                         fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 16),
//                 _buildInfoCard(),
//                 const SizedBox(height: 16),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDeviceListContent() {
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text("Pilih Perangkat Anda",
//                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
//               IconButton(
//                 icon: const Icon(Icons.refresh),
//                 onPressed: _isBluetoothOn ? _startScan : null,
//               ),
//             ],
//           ),
//         ),
//         if (_currentScreenState == HrvScreenState.scanning)
//           const Padding(
//             padding: EdgeInsets.all(32.0),
//             child: Column(
//               children: [
//                 CircularProgressIndicator(),
//                 SizedBox(height: 16),
//                 Text("Mencari perangkat..."),
//               ],
//             ),
//           ),
//         Expanded(
//           child: ListView.builder(
//             itemCount: _scanResults.length,
//             itemBuilder: (context, index) {
//               final result = _scanResults[index];
//               final deviceName = result.device.advName;
//               return ListTile(
//                 title: Text(deviceName),
//                 subtitle: Text(result.device.remoteId.toString()),
//                 onTap: () => _connectToDevice(result.device),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTimerContent() {
//     if (!_isTesting) {
//       return Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.touch_app, color: Colors.teal, size: 80),
//             const SizedBox(height: 24),
//             const Text(
//               'Siap Memulai Tes',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 12),
//             Text(
//               'Detak Jantung Saat Ini: $_currentHeartRate BPM',
//               style: const TextStyle(fontSize: 18, color: Colors.grey),
//             ),
//             const Spacer(),
//             ElevatedButton(
//               onPressed: _connectedDevice != null ? _startTest : null,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.teal.shade700,
//                 disabledBackgroundColor: Colors.grey.shade300,
//                 foregroundColor: Colors.white,
//                 minimumSize: const Size(double.infinity, 50),
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(16)),
//               ),
//               child: const Text('MULAI HRV TEST'),
//             ),
//           ],
//         ),
//       );
//     }

//     double progress = (180 - _secondsRemaining) / 180.0;
//     return SingleChildScrollView(
//       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
//       child: Column(
//         children: [
//           _buildRealtimeMetric(
//               'Detak Jantung', _currentHeartRate.toString(), 'BPM'),
//           const Divider(height: 40),
//           _buildRealtimeMetric(
//               'Interval R-R', _latestRRInterval.toString(), 'ms'),
//           const SizedBox(height: 60),
//           Column(
//             children: [
//               LinearProgressIndicator(
//                 value: progress,
//                 minHeight: 8,
//                 backgroundColor: Colors.grey.shade200,
//                 color: Colors.teal,
//                 borderRadius: BorderRadius.circular(4),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Sisa Waktu: $_secondsRemaining detik',
//                 style: const TextStyle(color: Colors.grey, fontSize: 14),
//               ),
//             ],
//           ),
//           const SizedBox(height: 40),
//           ElevatedButton(
//             onPressed: null,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.grey.shade300,
//               foregroundColor: Colors.white,
//               minimumSize: const Size(double.infinity, 50),
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16)),
//             ),
//             child: const Text('TES BERLANGSUNG...'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRealtimeMetric(String title, String value, String unit) {
//     return Column(
//       children: [
//         Text(title, style: const TextStyle(fontSize: 20, color: Colors.grey)),
//         const SizedBox(height: 8),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.baseline,
//           textBaseline: TextBaseline.alphabetic,
//           children: [
//             Text(value,
//                 style: const TextStyle(
//                     fontSize: 64,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87)),
//             const SizedBox(width: 8),
//             Text(unit,
//                 style: const TextStyle(fontSize: 20, color: Colors.black54)),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildResultContent() {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
//       child: Column(
//         children: [
//           Card(
//             elevation: 0,
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//             color: Colors.grey.shade100,
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 children: [
//                   Row(
//                     children: [
//                       Icon(Icons.favorite, color: Colors.teal.shade300),
//                       const SizedBox(width: 8),
//                       const Text('Hasil tes HRV terakhir',
//                           style: TextStyle(fontWeight: FontWeight.bold)),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Expanded(
//                         flex: 3,
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             Text(_stressIndex.toStringAsFixed(2),
//                                 style: const TextStyle(
//                                     fontSize: 48, fontWeight: FontWeight.w900)),
//                             const SizedBox(height: 4),
//                             Text(_stressCategory.toUpperCase(),
//                                 style: TextStyle(
//                                     color: Colors.teal.shade400,
//                                     fontWeight: FontWeight.bold)),
//                             const Text('Stress Index (SI)',
//                                 style: TextStyle(color: Colors.grey)),
//                           ],
//                         ),
//                       ),
//                       Expanded(
//                         flex: 2,
//                         child: Column(
//                           children: [
//                             _buildRightHrvMetric(
//                                 _avgRRInterval.toStringAsFixed(1),
//                                 'ms',
//                                 'Avg RR Interval'),
//                             const SizedBox(height: 20),
//                             _buildRightHrvMetric(
//                                 _avgHeartRate.toStringAsFixed(1),
//                                 'BPM',
//                                 'Avg Heart Rate'),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 24),
//           ElevatedButton(
//             onPressed: () => Navigator.of(context).pop(),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.teal.shade700,
//               minimumSize: const Size(double.infinity, 50),
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16)),
//             ),
//             child: const Text('Kembali ke Beranda',
//                 style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRightHrvMetric(String value, String unit, String label) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.baseline,
//           textBaseline: TextBaseline.alphabetic,
//           children: [
//             Text(value,
//                 style:
//                     const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
//             const SizedBox(width: 4),
//             Text(unit, style: const TextStyle(color: Colors.grey)),
//           ],
//         ),
//         const SizedBox(height: 2),
//         Text(label, style: const TextStyle(color: Colors.grey)),
//       ],
//     );
//   }

//   Widget _buildInfoCard() {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: const Row(
//         children: [
//           Icon(Icons.info_outline, color: Colors.white, size: 20),
//           SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               'Untuk memulai HRV test, pastikan koneksi bluethooth pada perangkat anda sudah aktif (Anda tidak perlu melakukan "pairing" dengan perangkat Coospo).',
//               style: TextStyle(color: Colors.white70, fontSize: 13),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }



// // import 'dart:async';
// // import 'dart:math';
// // import 'package:flutter/material.dart';
// // import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// // import 'package:permission_handler/permission_handler.dart';
// // import 'package:supabase_flutter/supabase_flutter.dart';
// // import 'package:timer_builder/timer_builder.dart';

// // final supabase = Supabase.instance.client;

// // class HrvTestScreen extends StatefulWidget {
// //   const HrvTestScreen({super.key});

// //   @override
// //   State<HrvTestScreen> createState() => _HrvTestScreenState();
// // }

// // class _HrvTestScreenState extends State<HrvTestScreen> {
// //   // --- Variabel State ---
// //   bool _isBluetoothOn = false;
// //   bool _isTesting = false;
// //   bool _isTestFinished = false;
// //   Timer? _testTimer;
// //   int _secondsRemaining = 60;
// //   final ScrollController _scrollController = ScrollController();

// //   BluetoothDevice? _coospoDevice;
// //   StreamSubscription<List<ScanResult>>? _scanSubscription;
// //   StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
// //   StreamSubscription<List<int>>? _valueSubscription;
// //   final List<int> _collectedRRIntervals = [];

// //   double _stressIndex = 0.0;
// //   double _avgRRInterval = 0.0;
// //   double _avgHeartRate = 0.0;
// //   String _stressCategory = "Normal";

// //   @override
// //   void initState() {
// //     super.initState();
// //     _checkBluetoothStatus();
// //   }

// //   @override
// //   void dispose() {
// //     _testTimer?.cancel();
// //     _scanSubscription?.cancel();
// //     _connectionSubscription?.cancel();
// //     _valueSubscription?.cancel();
// //     _coospoDevice?.disconnect();
// //     _scrollController.dispose();
// //     super.dispose();
// //   }

// //   // --- SEMUA FUNGSI LOGIKA ---

// //   Future<void> _checkBluetoothStatus() async {
// //     if (await Permission.bluetoothScan.request().isGranted &&
// //         await Permission.bluetoothConnect.request().isGranted) {
// //       FlutterBluePlus.adapterState.listen((state) {
// //         if (mounted) {
// //           setState(() {
// //             _isBluetoothOn = state == BluetoothAdapterState.on;
// //           });
// //           if (_isBluetoothOn) _startScan();
// //         }
// //       });
// //     }
// //   }
  
// //   void _openBluetoothSettings() {
// //     openAppSettings();
// //   }

// //   void _startScan() {
// //     _scanSubscription?.cancel();
// //     _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
// //       try {
// //         final coospoResult = results.firstWhere(
// //           (r) => r.device.platformName.isNotEmpty,
// //         );
// //         FlutterBluePlus.stopScan();
// //         _scanSubscription?.cancel();
// //         _connectToDevice(coospoResult.device);
// //       } catch (e) {
// //         print("Mencari perangkat yang cocok...");
// //       }
// //     });
// //     FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
// //   }
  
// //   void _connectToDevice(BluetoothDevice device) async {
// //     _coospoDevice = device;
// //     _connectionSubscription = _coospoDevice!.connectionState.listen((state) {
// //       if (state == BluetoothConnectionState.connected && mounted) {
// //         setState(() {});
// //         _discoverServices();
// //       }
// //     });
// //     await _coospoDevice!.connect(autoConnect: false, license: License.commercial);
// //   }

// //   void _discoverServices() async {
// //     final services = await _coospoDevice!.discoverServices();
// //     for (var service in services) {
// //       if (service.uuid.toString().toUpperCase().contains("180D")) {
// //         for (var char in service.characteristics) {
// //           if (char.uuid.toString().toUpperCase().contains("2A37")) {
// //             _subscribeToCharacteristic(char);
// //             return;
// //           }
// //         }
// //       }
// //     }
// //   }

// //   void _subscribeToCharacteristic(BluetoothCharacteristic characteristic) async {
// //     await characteristic.setNotifyValue(true);
// //     _valueSubscription = characteristic.value.listen((value) {
// //       if (value.isNotEmpty && _isTesting && value.length > 2) {
// //         int rr = value[2] | (value[3] << 8);
// //         double rrMs = rr * 0.625; 
// //         if(mounted) setState(() => _collectedRRIntervals.add(rrMs.toInt()));
// //       }
// //     });
// //   }

// //   void _startTest() {
// //     setState(() {
// //       _isTesting = true;
// //       _isTestFinished = false;
// //       _secondsRemaining = 60;
// //       _collectedRRIntervals.clear();
// //       _currentHeartRate = 0;
// //     });

// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //        if (_scrollController.hasClients) {
// //         _scrollController.animateTo(
// //           _scrollController.position.maxScrollExtent,
// //           duration: const Duration(milliseconds: 500),
// //           curve: Curves.easeInOut,
// //         );
// //       }
// //     });

// //     _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
// //       if (_secondsRemaining > 0) {
// //         setState(() {
// //            _secondsRemaining--;
// //            // Tampilkan heart rate saat ini di UI (opsional)
// //            _avgHeartRate = _currentHeartRate.toDouble();
// //         });
// //       } else {
// //         _finishTest();
// //       }
// //     });
// //   }
  
// //   void _finishTest() {
// //     _testTimer?.cancel();
// //     _valueSubscription?.cancel();
    
// //     _calculateFinalMetrics(); // Panggil perhitungan final
    
// //     setState(() {
// //       _isTesting = false;
// //       _isTestFinished = true;
// //     });
// //   }
  
// //   // Variabel untuk menyimpan heart rate saat ini, perlu didefinisikan
// //   int _currentHeartRate = 0;

// //   void _calculateFinalMetrics() {
// //     if (_collectedRRIntervals.isEmpty) return;

// //     _avgRRInterval = _collectedRRIntervals.reduce((a, b) => a + b) / _collectedRRIntervals.length;

// //     var modeMap = <int, int>{};
// //     for (var interval in _collectedRRIntervals) {
// //       modeMap[interval] = (modeMap[interval] ?? 0) + 1;
// //     }

// //     if (modeMap.isEmpty) return;

// //     var modusEntry = modeMap.entries.reduce((a, b) => a.value > b.value ? a : b);
// //     int modus = modusEntry.key;
// //     int amoCount = modusEntry.value;

// //     double amoPercent = (amoCount / _collectedRRIntervals.length) * 100;
// //     double moSeconds = modus / 1000.0;
// //     double variationRangeMs = (_collectedRRIntervals.reduce(max) - _collectedRRIntervals.reduce(min)).toDouble();
// //     double variationRangeSeconds = variationRangeMs / 1000.0;

// //     if (moSeconds == 0 || variationRangeSeconds == 0) {
// //       _stressIndex = 0;
// //     } else {
// //       _stressIndex = amoPercent / (2 * moSeconds * variationRangeSeconds);
// //     }
    
// //     if (_stressIndex >= 500) _stressCategory = "Very High";
// //     else if (_stressIndex >= 300) _stressCategory = "High";
// //     else if (_stressIndex >= 150) _stressCategory = "Moderate";
// //     else if (_stressIndex >= 50) _stressCategory = "Normal";
// //     else _stressCategory = "Low";

// //     _saveResultsToSupabase();
// //   }

// //   Future<void> _saveResultsToSupabase() async {
// //      try {
// //       final username = supabase.auth.currentUser!.userMetadata?['username'];
// //       final pegawaiData = await supabase.from('stress_pegawai').select('id_pegawai').eq('username', username).single();
// //       final pegawaiIntegerId = pegawaiData['id_pegawai'];

// //       await supabase.from('stress_objektif').insert({
// //         'nama_pegawai_id': pegawaiIntegerId,
// //         'tanggal_assessment': DateTime.now().toIso8601String(),
// //         'index': _stressIndex,
// //         'avg_rr_interval': _avgRRInterval,
// //         'avg_heart_rate': _avgHeartRate,
// //       });
// //       if (mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text('Hasil HRV berhasil disimpan!'), backgroundColor: Colors.green),
// //         );
// //       }
// //     } catch (e) {
// //       if (mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(content: Text('Gagal menyimpan hasil: $e'), backgroundColor: Colors.red),
// //         );
// //       }
// //     }
// //   }

// //   // --- SEMUA METHOD BUILDER UI ---
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       body: Stack(
// //         children: [
// //           Container(
// //             decoration: const BoxDecoration(
// //               gradient: LinearGradient(
// //                 colors: [Color(0xFF00B5AD), Color(0xFF008983)],
// //                 begin: Alignment.topLeft,
// //                 end: Alignment.bottomRight,
// //               ),
// //             ),
// //           ),
// //           SafeArea(
// //             child: Column(
// //               children: [
// //                 _buildTopSection(),
// //                 Expanded(
// //                   child: Container(
// //                     width: double.infinity,
// //                     decoration: const BoxDecoration(
// //                       color: Colors.white,
// //                       borderRadius: BorderRadius.only(
// //                         topLeft: Radius.circular(30),
// //                         topRight: Radius.circular(30),
// //                       ),
// //                     ),
// //                     child: SingleChildScrollView(
// //                       controller: _scrollController,
// //                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
// //                       child: _isTestFinished ? _buildResultContent() : _buildTimerContent(),
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildTopSection() {
// //     return Padding(
// //       padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           AppBar(
// //             title: const Text('HRV TEST PAGE', style: TextStyle(color: Colors.white, fontSize: 14)),
// //             backgroundColor: Colors.transparent,
// //             elevation: 0,
// //             iconTheme: const IconThemeData(color: Colors.white),
// //           ),
// //           Padding(
// //             padding: const EdgeInsets.symmetric(horizontal: 16.0),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 const Text('HRV test', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
// //                 const SizedBox(height: 16),
// //                 _buildInfoCard(),
// //                 const SizedBox(height: 16),
// //                 SizedBox(
// //                   width: double.infinity,
// //                   child: TextButton(
// //                     onPressed: _openBluetoothSettings,
// //                     style: TextButton.styleFrom(
// //                       backgroundColor: Colors.white,
// //                       foregroundColor: Colors.teal.shade800,
// //                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //                       padding: const EdgeInsets.symmetric(vertical: 12)
// //                     ),
// //                     child: Text(
// //                       _isBluetoothOn ? 'Perangkat Tersambung' : 'Sambungkan cospa device anda',
// //                       style: TextStyle(
// //                         fontWeight: _isBluetoothOn ? FontWeight.bold : FontWeight.normal,
// //                       ),
// //                     ),
// //                   ),
// //                 ),
// //                 const SizedBox(height: 16),
// //                 const Divider(color: Colors.white24),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildTimerContent() {
// //     double progress = _isTesting ? (60 - _secondsRemaining) / 60.0 : 0.0;
// //     return Column(
// //       children: [
// //         SizedBox(
// //           height: 200,
// //           width: 200,
// //           child: Stack(
// //             fit: StackFit.expand,
// //             children: [
// //               CircularProgressIndicator(
// //                 value: progress,
// //                 strokeWidth: 8,
// //                 backgroundColor: Colors.grey.shade200,
// //                 valueColor: AlwaysStoppedAnimation<Color>(
// //                   _isBluetoothOn ? Colors.teal : Colors.grey.shade300,
// //                 ),
// //               ),
// //               Center(
// //                 child: TimerBuilder.periodic(
// //                   const Duration(seconds: 1),
// //                   builder: (context) {
// //                     final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
// //                     final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
// //                     return Column(
// //                       mainAxisAlignment: MainAxisAlignment.center,
// //                       children: [
// //                         Text(
// //                           _isTesting ? '$minutes:$seconds' : '01:00',
// //                           style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: _isBluetoothOn ? Colors.black : Colors.grey.shade300),
// //                         ),
// //                         Text('Durasi tes HRV', style: TextStyle(color: Colors.grey.shade400)),
// //                       ],
// //                     );
// //                   },
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //         const SizedBox(height: 40),
// //         ElevatedButton(
// //           onPressed: _isBluetoothOn && !_isTesting ? _startTest : null,
// //           style: ElevatedButton.styleFrom(
// //             backgroundColor: Colors.teal.shade700,
// //             disabledBackgroundColor: Colors.grey.shade300,
// //             foregroundColor: Colors.white,
// //             minimumSize: const Size(double.infinity, 50),
// //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //           ),
// //           child: Text(_isTesting ? 'TES BERLANGSUNG...' : 'MULAI HRV TEST'),
// //         ),
// //         const SizedBox(height: 16),
// //         const Text('Pastikan perangkat anda tetap terhubung\nselama proses tes HRV berlangsung.',
// //             textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
// //       ],
// //     );
// //   }

// //   Widget _buildResultContent() {
// //     return Column(
// //       children: [
// //         Card(
// //           elevation: 0,
// //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //           color: Colors.grey.shade100,
// //           child: Padding(
// //             padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
// //             child: Column(
// //               children: [
// //                 const Text('Tes Selesai!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
// //                 const Text('00:00', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
// //                 const Text('Durasi tes HRV', style: TextStyle(color: Colors.grey)),
// //                 const SizedBox(height: 24),
// //                 ElevatedButton(
// //                   onPressed: null,
// //                   style: ElevatedButton.styleFrom(
// //                     backgroundColor: Colors.grey.shade300,
// //                     foregroundColor: Colors.grey.shade600,
// //                     minimumSize: const Size(200, 50),
// //                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //                   ),
// //                   child: const Text('MULAI HRV TEST'),
// //                 ),
// //                 const SizedBox(height: 8),
// //                 const Text('Pastikan perangkat anda tetap terhubung...', 
// //                   style: TextStyle(color: Colors.grey, fontSize: 12),
// //                   textAlign: TextAlign.center,
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ),
// //         const SizedBox(height: 24),
// //         Card(
// //            elevation: 0,
// //            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //            color: Colors.grey.shade100,
// //            child: Padding(
// //              padding: const EdgeInsets.all(16.0),
// //              child: Column(
// //                children: [
// //                  Row(
// //                    children: [
// //                     Icon(Icons.favorite, color: Colors.teal.shade300),
// //                     const SizedBox(width: 8),
// //                     const Text('Hasil tes HRV terakhir', style: TextStyle(fontWeight: FontWeight.bold)),
// //                    ],
// //                  ),
// //                  const SizedBox(height: 16),
// //                  Row(
// //                    crossAxisAlignment: CrossAxisAlignment.start,
// //                    children: [
// //                      Expanded(
// //                        flex: 3,
// //                        child: Column(
// //                          crossAxisAlignment: CrossAxisAlignment.center,
// //                          children: [
// //                            Text(_stressIndex.toStringAsFixed(2), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
// //                            const SizedBox(height: 4),
// //                            Text(_stressCategory.toUpperCase(), style: TextStyle(color: Colors.teal.shade400, fontWeight: FontWeight.bold)),
// //                            const Text('Stress Index (SI)', style: TextStyle(color: Colors.grey)),
// //                          ],
// //                        ),
// //                      ),
// //                      Expanded(
// //                        flex: 2,
// //                        child: Column(
// //                          children: [
// //                            _buildRightHrvMetric(_avgRRInterval.toStringAsFixed(1), 'ms', 'Avg RR Interval'),
// //                            const SizedBox(height: 20),
// //                            _buildRightHrvMetric(_avgHeartRate.toStringAsFixed(1), 'BPM', 'Avg Heart Rate'),
// //                          ],
// //                        ),
// //                      ),
// //                    ],
// //                  ),
// //                ],
// //              ),
// //            ),
// //         ),
// //         const SizedBox(height: 24),
// //         ElevatedButton(
// //             onPressed: () => Navigator.of(context).pop(),
// //             style: ElevatedButton.styleFrom(
// //               backgroundColor: Colors.teal.shade700,
// //               minimumSize: const Size(double.infinity, 50),
// //               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //             ),
// //             child: const Text('Kembali ke beranda', style: TextStyle(color: Colors.white)),
// //           ),
// //       ],
// //     );
// //   }
  
// //   Widget _buildRightHrvMetric(String value, String unit, String label) {
// //     return Column(
// //       crossAxisAlignment: CrossAxisAlignment.center,
// //       children: [
// //         Row(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           crossAxisAlignment: CrossAxisAlignment.baseline,
// //           textBaseline: TextBaseline.alphabetic,
// //           children: [
// //             Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
// //             const SizedBox(width: 4),
// //             Text(unit, style: const TextStyle(color: Colors.grey)),
// //           ],
// //         ),
// //         const SizedBox(height: 2),
// //         Text(label, style: const TextStyle(color: Colors.grey)),
// //       ],
// //     );
// //   }

// //   Widget _buildInfoCard() {
// //     return Container(
// //       padding: const EdgeInsets.all(12),
// //       decoration: BoxDecoration(
// //         color: Colors.black.withOpacity(0.1),
// //         borderRadius: BorderRadius.circular(8),
// //       ),
// //       child: const Row(
// //         children: [
// //           Icon(Icons.info_outline, color: Colors.white, size: 20),
// //           SizedBox(width: 12),
// //           Expanded(
// //             child: Text(
// //               'Untuk memulai HRV test, pastikan perangkat Coospo sudah terhubung dengan Bluetooth.',
// //               style: TextStyle(color: Colors.white70, fontSize: 13),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }



// // import 'dart:async';
// // import 'dart:math';

// // import 'package:flutter/material.dart';
// // import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// // import 'package:permission_handler/permission_handler.dart';
// // import 'package:supabase_flutter/supabase_flutter.dart';
// // import 'package:timer_builder/timer_builder.dart';

// // final supabase = Supabase.instance.client;

// // class HrvTestScreen extends StatefulWidget {
// //   const HrvTestScreen({super.key});

// //   @override
// //   State<HrvTestScreen> createState() => _HrvTestScreenState();
// // }

// // class _HrvTestScreenState extends State<HrvTestScreen> {
// //   // --- Variabel State ---
// //   bool _isBluetoothOn = false;
// //   bool _isTesting = false;
// //   bool _isTestFinished = false;
// //   Timer? _testTimer;
// //   int _secondsRemaining = 60;
// //   final ScrollController _scrollController = ScrollController();

// //   BluetoothDevice? _coospoDevice;
// //   StreamSubscription<List<ScanResult>>? _scanSubscription;
// //   StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
// //   StreamSubscription<List<int>>? _valueSubscription;
// //   final List<int> _collectedRRIntervals = [];

// //   double _stressIndex = 0.0;
// //   double _avgRRInterval = 0.0;
// //   double _avgHeartRate = 0.0;
// //   String _stressCategory = "Normal";

// //   @override
// //   void initState() {
// //     super.initState();
// //     _checkBluetoothStatus();
// //   }

// //   @override
// //   void dispose() {
// //     _testTimer?.cancel();
// //     _scanSubscription?.cancel();
// //     _connectionSubscription?.cancel();
// //     _valueSubscription?.cancel();
// //     _coospoDevice?.disconnect();
// //     _scrollController.dispose();
// //     super.dispose();
// //   }

// //   // --- SEMUA FUNGSI LOGIKA ---

// //   Future<void> _checkBluetoothStatus() async {
// //     if (await Permission.bluetoothScan.request().isGranted &&
// //         await Permission.bluetoothConnect.request().isGranted) {
// //       FlutterBluePlus.adapterState.listen((state) {
// //         if (mounted) {
// //           setState(() {
// //             _isBluetoothOn = state == BluetoothAdapterState.on;
// //           });
// //           if (_isBluetoothOn) _startScan();
// //         }
// //       });
// //     }
// //   }
  
// //   void _openBluetoothSettings() {
// //     openAppSettings();
// //   }

// //   void _startScan() {
// //     _scanSubscription?.cancel();
// //     _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
// //       try {
// //         final coospoResult = results.firstWhere(
// //           (r) => r.device.platformName.isNotEmpty,
// //         );
// //         FlutterBluePlus.stopScan();
// //         _scanSubscription?.cancel();
// //         _connectToDevice(coospoResult.device);
// //       } catch (e) {
// //         print("Mencari perangkat yang cocok...");
// //       }
// //     });
// //     FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
// //   }
  
// //   void _connectToDevice(BluetoothDevice device) async {
// //     _coospoDevice = device;
// //     _connectionSubscription = _coospoDevice!.connectionState.listen((state) {
// //       if (state == BluetoothConnectionState.connected && mounted) {
// //         setState(() {});
// //         _discoverServices();
// //       }
// //     });

// //     await _coospoDevice!.connect (autoConnect: false, license: License.commercial);
// //   }

// //   void _discoverServices() async {
// //     final services = await _coospoDevice!.discoverServices();
// //     for (var service in services) {
// //       if (service.uuid.toString().toUpperCase().contains("180D")) {
// //         for (var char in service.characteristics) {
// //           if (char.uuid.toString().toUpperCase().contains("2A37")) {
// //             _subscribeToCharacteristic(char);
// //             return;
// //           }
// //         }
// //       }
// //     }
// //   }

// //   void _subscribeToCharacteristic(BluetoothCharacteristic characteristic) async {
// //     await characteristic.setNotifyValue(true);
// //     _valueSubscription = characteristic.value.listen((value) {
// //       if (value.isNotEmpty && _isTesting && value.length > 2) {
// //         int rr = value[2] | (value[3] << 8);
// //         double rrMs = (rr / 1024.0) * 1000.0; 
// //         if(mounted) setState(() => _collectedRRIntervals.add(rrMs.toInt()));
// //       }
// //     });
// //   }

// //   void _startTest() {
// //     setState(() {
// //       _isTesting = true;
// //       _isTestFinished = false;
// //       _secondsRemaining = 60;
// //       _collectedRRIntervals.clear();
// //     });

// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       if (_scrollController.hasClients) {
// //         _scrollController.animateTo(
// //           _scrollController.position.maxScrollExtent,
// //           duration: const Duration(milliseconds: 500),
// //           curve: Curves.easeInOut,
// //         );
// //       }
// //     });

// //     _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
// //       if (_secondsRemaining > 0) {
// //         setState(() {
// //           _secondsRemaining--;
// //           _calculateHrvMetrics();
// //         });
// //       } else {
// //         _finishTest();
// //       }
// //     });
// //   }
  
// //   void _finishTest() {
// //     _testTimer?.cancel();
// //     _valueSubscription?.cancel();
// //     _calculateHrvMetrics();
// //     _saveResultsToSupabase();
// //     setState(() {
// //       _isTesting = false;
// //       _isTestFinished = true;
// //     });
// //   }

// //   void _calculateHrvMetrics() {
// //     if (_collectedRRIntervals.length < 2) return;
// //     final double meanRR = _collectedRRIntervals.reduce((a, b) => a + b) / _collectedRRIntervals.length;
// //     final double avgHeartRate = 60000 / meanRR;
// //     final double variationRangeMs = (_collectedRRIntervals.reduce(max) - _collectedRRIntervals.reduce(min)).toDouble();
// //     if (variationRangeMs == 0) return;
// //     var modeMap = <int, int>{};
// //     for (var interval in _collectedRRIntervals) {
// //       int bin = (interval / 50).round() * 50;
// //       modeMap[bin] = (modeMap[bin] ?? 0) + 1;
// //     }
// //     int moMs = 0;
// //     int amoCount = 0;
// //     modeMap.forEach((key, value) {
// //       if (value > amoCount) { amoCount = value; moMs = key; }
// //     });
// //     if (moMs == 0) return;
// //     final double amoPercent = (amoCount / _collectedRRIntervals.length) * 100;
// //     final double moSeconds = moMs / 1000.0;
// //     final double variationRangeSeconds = variationRangeMs / 1000.0;
// //     final double stressIndex = amoPercent / (2 * moSeconds * variationRangeSeconds);
// //     setState(() {
// //       _avgRRInterval = meanRR;
// //       _avgHeartRate = avgHeartRate;
// //       _stressIndex = stressIndex;
// //       if (_stressIndex >= 500) _stressCategory = "Very High";
// //       else if (_stressIndex >= 300) _stressCategory = "High";
// //       else if (_stressIndex >= 150) _stressCategory = "Moderate";
// //       else if (_stressIndex >= 50) _stressCategory = "Normal";
// //       else _stressCategory = "Low";
// //     });
// //   }

// //   Future<void> _saveResultsToSupabase() async {
// //     try {
// //       final username = supabase.auth.currentUser!.userMetadata?['username'];
// //       final pegawaiData = await supabase.from('stress_pegawai').select('id_pegawai').eq('username', username).single();
// //       final pegawaiIntegerId = pegawaiData['id_pegawai'];
// //       await supabase.from('stress_objektif').insert({
// //         'nama_pegawai_id': pegawaiIntegerId,
// //         'tanggal_assessment': DateTime.now().toIso8601String(),
// //         'index': _stressIndex,
// //         'avg_rr_interval': _avgRRInterval,
// //         'avg_heart_rate': _avgHeartRate,
// //       });
// //       if (mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text('Hasil HRV berhasil disimpan!'), backgroundColor: Colors.green),
// //         );
// //       }
// //     } catch (e) {
// //       if (mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(content: Text('Gagal menyimpan hasil: $e'), backgroundColor: Colors.red),
// //         );
// //       }
// //     }
// //   }

// //   // --- SEMUA METHOD BUILDER UI ---
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       body: Stack(
// //         children: [
// //           Container(
// //             decoration: const BoxDecoration(
// //               gradient: LinearGradient(
// //                 colors: [Color(0xFF00B5AD), Color(0xFF008983)],
// //                 begin: Alignment.topLeft,
// //                 end: Alignment.bottomRight,
// //               ),
// //             ),
// //           ),
// //           SafeArea(
// //             child: Column(
// //               children: [
// //                 _buildTopSection(),
// //                 Expanded(
// //                   child: Container(
// //                     width: double.infinity,
// //                     decoration: const BoxDecoration(
// //                       color: Colors.white,
// //                       borderRadius: BorderRadius.only(
// //                         topLeft: Radius.circular(30),
// //                         topRight: Radius.circular(30),
// //                       ),
// //                     ),
// //                     child: SingleChildScrollView(
// //                       controller: _scrollController,
// //                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
// //                       child: _isTestFinished ? _buildResultContent() : _buildTimerContent(),
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildTopSection() {
// //     return Padding(
// //       padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           AppBar(
// //             title: const Text('HRV TEST PAGE', style: TextStyle(color: Colors.white, fontSize: 14)),
// //             backgroundColor: Colors.transparent,
// //             elevation: 0,
// //             iconTheme: const IconThemeData(color: Colors.white),
// //           ),
// //           Padding(
// //             padding: const EdgeInsets.symmetric(horizontal: 16.0),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 const Text('HRV test', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
// //                 const SizedBox(height: 16),
// //                 _buildInfoCard(),
// //                 const SizedBox(height: 16),
// //                 SizedBox(
// //                   width: double.infinity,
// //                   child: TextButton(
// //                     onPressed: _openBluetoothSettings,
// //                     style: TextButton.styleFrom(
// //                       backgroundColor: Colors.white,
// //                       foregroundColor: Colors.teal.shade800,
// //                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// //                       padding: const EdgeInsets.symmetric(vertical: 12)
// //                     ),
// //                     child: Text(
// //                       _isBluetoothOn ? 'Perangkat Tersambung' : 'Sambungkan cospa device anda',
// //                       style: TextStyle(
// //                         fontWeight: _isBluetoothOn ? FontWeight.bold : FontWeight.normal,
// //                       ),
// //                     ),
// //                   ),
// //                 ),
// //                 const SizedBox(height: 16),
// //                 const Divider(color: Colors.white24),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildTimerContent() {
// //     double progress = _isTesting ? (60 - _secondsRemaining) / 60.0 : 0.0;
// //     return Column(
// //       children: [
// //         SizedBox(
// //           height: 200,
// //           width: 200,
// //           child: Stack(
// //             fit: StackFit.expand,
// //             children: [
// //               CircularProgressIndicator(
// //                 value: progress,
// //                 strokeWidth: 8,
// //                 backgroundColor: Colors.grey.shade200,
// //                 valueColor: AlwaysStoppedAnimation<Color>(
// //                   _isBluetoothOn ? Colors.teal : Colors.grey.shade300,
// //                 ),
// //               ),
// //               Center(
// //                 child: TimerBuilder.periodic(
// //                   const Duration(seconds: 1),
// //                   builder: (context) {
// //                     final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
// //                     final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
// //                     return Column(
// //                       mainAxisAlignment: MainAxisAlignment.center,
// //                       children: [
// //                         Text(
// //                           _isTesting ? '$minutes:$seconds' : '01:00',
// //                           style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: _isBluetoothOn ? Colors.black : Colors.grey.shade300),
// //                         ),
// //                         Text('Durasi tes HRV', style: TextStyle(color: Colors.grey.shade400)),
// //                       ],
// //                     );
// //                   },
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //         const SizedBox(height: 40),
// //         ElevatedButton(
// //           onPressed: _isBluetoothOn && !_isTesting ? _startTest : null,
// //           style: ElevatedButton.styleFrom(
// //             backgroundColor: Colors.teal.shade700,
// //             disabledBackgroundColor: Colors.grey.shade300,
// //             foregroundColor: Colors.white,
// //             minimumSize: const Size(double.infinity, 50),
// //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //           ),
// //           child: Text(_isTesting ? 'TES BERLANGSUNG...' : 'MULAI HRV TEST'),
// //         ),
// //         const SizedBox(height: 16),
// //         const Text('Pastikan perangkat anda tetap terhubung\nselama proses tes HRV berlangsung.',
// //             textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
// //       ],
// //     );
// //   }

// //   Widget _buildResultContent() {
// //     return Column(
// //       children: [
// //         Card(
// //           elevation: 0,
// //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //           color: Colors.grey.shade100,
// //           child: Padding(
// //             padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
// //             child: Column(
// //               children: [
// //                 const Text('Tes Selesai!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
// //                 const Text('00:00', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
// //                 const Text('Durasi tes HRV', style: TextStyle(color: Colors.grey)),
// //                 const SizedBox(height: 24),
// //                 ElevatedButton(
// //                   onPressed: null,
// //                   style: ElevatedButton.styleFrom(
// //                     backgroundColor: Colors.grey.shade300,
// //                     foregroundColor: Colors.grey.shade600,
// //                     minimumSize: const Size(200, 50),
// //                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //                   ),
// //                   child: const Text('MULAI HRV TEST'),
// //                 ),
// //                 const SizedBox(height: 8),
// //                 const Text('Pastikan perangkat anda tetap terhubung...', 
// //                   style: TextStyle(color: Colors.grey, fontSize: 12),
// //                   textAlign: TextAlign.center,
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ),
// //         const SizedBox(height: 24),
// //         Card(
// //            elevation: 0,
// //            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //            color: Colors.grey.shade100,
// //            child: Padding(
// //              padding: const EdgeInsets.all(16.0),
// //              child: Column(
// //                children: [
// //                  Row(
// //                    children: [
// //                     Icon(Icons.favorite, color: Colors.teal.shade300),
// //                     const SizedBox(width: 8),
// //                     const Text('Hasil tes HRV terakhir', style: TextStyle(fontWeight: FontWeight.bold)),
// //                    ],
// //                  ),
// //                  const SizedBox(height: 16),
// //                  Row(
// //                    crossAxisAlignment: CrossAxisAlignment.start,
// //                    children: [
// //                      Expanded(
// //                        flex: 3,
// //                        child: Column(
// //                          crossAxisAlignment: CrossAxisAlignment.center,
// //                          children: [
// //                            Text(_stressIndex.toStringAsFixed(2), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
// //                            const SizedBox(height: 4),
// //                            Text(_stressCategory.toUpperCase(), style: TextStyle(color: Colors.teal.shade400, fontWeight: FontWeight.bold)),
// //                            const Text('Stress Index (SI)', style: TextStyle(color: Colors.grey)),
// //                          ],
// //                        ),
// //                      ),
// //                      Expanded(
// //                        flex: 2,
// //                        child: Column(
// //                          children: [
// //                            _buildRightHrvMetric(_avgRRInterval.toStringAsFixed(1), 'ms', 'Avg RR Interval'),
// //                            const SizedBox(height: 20),
// //                            _buildRightHrvMetric(_avgHeartRate.toStringAsFixed(1), 'BPM', 'Avg Heart Rate'),
// //                          ],
// //                        ),
// //                      ),
// //                    ],
// //                  ),
// //                ],
// //              ),
// //            ),
// //         ),
// //         const SizedBox(height: 24),
// //         ElevatedButton(
// //             onPressed: () => Navigator.of(context).pop(),
// //             style: ElevatedButton.styleFrom(
// //               backgroundColor: Colors.teal.shade700,
// //               minimumSize: const Size(double.infinity, 50),
// //               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //             ),
// //             child: const Text('Kembali ke beranda', style: TextStyle(color: Colors.white)),
// //           ),
// //       ],
// //     );
// //   }
  
// //   Widget _buildRightHrvMetric(String value, String unit, String label) {
// //     return Column(
// //       crossAxisAlignment: CrossAxisAlignment.center,
// //       children: [
// //         Row(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           crossAxisAlignment: CrossAxisAlignment.baseline,
// //           textBaseline: TextBaseline.alphabetic,
// //           children: [
// //             Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
// //             const SizedBox(width: 4),
// //             Text(unit, style: const TextStyle(color: Colors.grey)),
// //           ],
// //         ),
// //         const SizedBox(height: 2),
// //         Text(label, style: const TextStyle(color: Colors.grey)),
// //       ],
// //     );
// //   }

// //   Widget _buildInfoCard() {
// //     return Container(
// //       padding: const EdgeInsets.all(12),
// //       decoration: BoxDecoration(
// //         color: Colors.black.withOpacity(0.1),
// //         borderRadius: BorderRadius.circular(8),
// //       ),
// //       child: const Row(
// //         children: [
// //           Icon(Icons.info_outline, color: Colors.white, size: 20),
// //           SizedBox(width: 12),
// //           Expanded(
// //             child: Text(
// //               'Untuk memulai HRV test, pastikan perangkat Coospo sudah terhubung dengan Bluetooth.',
// //               style: TextStyle(color: Colors.white70, fontSize: 13),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }