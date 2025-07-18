import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert'; // Needed for utf8.encode  ///




class BleController extends GetxController {
  final RxBool _isScanning = false.obs;

  late BluetoothCharacteristic txChar; ////
  late BluetoothCharacteristic rxChar; ///

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

      await discoverServices(device); ///
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

  ////
  Future<void> discoverServices(BluetoothDevice device) async {
  List<BluetoothService> services = await device.discoverServices();

  for (var service in services) {
    for (var characteristic in service.characteristics) {
      if (characteristic.uuid.str.toLowerCase().contains("6e400003")) {
        txChar = characteristic;
        await txChar.setNotifyValue(true);
        txChar.lastValueStream.listen((value) {
          print("📥 From ESP32: ${String.fromCharCodes(value)}");
        });
      } else if (characteristic.uuid.str.toLowerCase().contains("6e400002")) {
        rxChar = characteristic;
      }
    }
  }

  print("✅ Characteristics discovered");
}

Future<void> sendToEsp32(String message) async {
  if (rxChar != null) {
    await rxChar.write(utf8.encode(message));
    print("📤 Sent to ESP32: $message");
  } else {
    print("⚠️ RX Characteristic not available");
  }
}

}
