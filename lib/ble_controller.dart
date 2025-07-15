import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class BleController extends GetxController {
  final RxBool _isScanning = false.obs;

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  bool get isScanning => _isScanning.value;

  /// Start scanning for BLE devices with proper permission handling
  Future<void> scanDevices() async {
    // Request necessary permissions
    final scanPermission = await Permission.bluetoothScan.request();
    final connectPermission = await Permission.bluetoothConnect.request();
    final locationPermission = await Permission.locationWhenInUse.request();

    if (scanPermission.isGranted &&
        connectPermission.isGranted &&
        locationPermission.isGranted) {
      print("🔍 Starting BLE scan...");

      _isScanning.value = true;
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      await Future.delayed(const Duration(seconds: 11));
      await FlutterBluePlus.stopScan();
      _isScanning.value = false;

      print("✅ Scan completed.");
    } else {
      print("❌ Required permissions not granted.");
    }
  }

  /// Safely connect to a BLE device with retry logic and error handling
  Future<void> connectToDevice(BluetoothDevice device) async {
    print("🔌 Attempting to connect to: ${device.platformName} (${device.remoteId.str})");

    // Always disconnect first (in case previous connection wasn't cleaned up)
    try {
      await device.disconnect();
      print("➡️ Disconnected before new connection attempt.");
      await Future.delayed(const Duration(seconds: 1));
    } catch (_) {
      // No problem if already disconnected
    }

    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );
      print("✅ Connected to ${device.platformName}");

      // Listen to connection state
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          print("🟢 Device connected: ${device.platformName}");
        } else if (state == BluetoothConnectionState.disconnected) {
          print("🔴 Device disconnected: ${device.platformName}");
        }
      });
    } catch (e) {
      print("⚠️ Initial connection failed: $e");

      // Retry after delay
      await Future.delayed(const Duration(seconds: 2));
      try {
        await device.connect(
          timeout: const Duration(seconds: 10),
          autoConnect: false,
        );
        print("✅ Reconnected to ${device.platformName}");
      } catch (retryError) {
        print("❌ Retry failed: $retryError");
      }
    }
  }

  /// Optional method to connect to all "lora10" devices
  Future<void> connectToLora10Devices() async {
    print("🔍 Scanning for devices named 'lora10'...");

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    await Future.delayed(const Duration(seconds: 11));
    await FlutterBluePlus.stopScan();

    final results = await FlutterBluePlus.scanResults.first;
    final loraDevices = results
        .where((r) => r.device.platformName.toLowerCase().contains('lora10'))
        .map((r) => r.device)
        .toList();

    if (loraDevices.isEmpty) {
      print("❌ No devices with name containing 'lora10' found.");
      return;
    }

    for (final device in loraDevices) {
      await connectToDevice(device);
    }
  }
}
