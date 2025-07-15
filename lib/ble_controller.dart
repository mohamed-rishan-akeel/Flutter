import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class BleController extends GetxController {
  // You don't need an instance for static methods
  // final FlutterBluePlus ble = FlutterBluePlus.instance; // ❌ Not needed

  Future<void> scanDevices() async {
    // Request permissions
    final scanPermission = await Permission.bluetoothScan.request();
    final connectPermission = await Permission.bluetoothConnect.request();
    final locationPermission = await Permission.locationWhenInUse.request(); // required on Android

    if (scanPermission.isGranted &&
        connectPermission.isGranted &&
        locationPermission.isGranted) {
      print("Starting BLE scan...");
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      await Future.delayed(const Duration(seconds: 11)); // allow time for results
      await FlutterBluePlus.stopScan();
      print("Scan completed.");
    } else {
      print("Required permissions not granted");
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          print("Connected to ${device.platformName}");
        } else if (state == BluetoothConnectionState.disconnected) {
          print("Disconnected from ${device.platformName}");
        }
      });
    } catch (e) {
      print("Error connecting: $e");
    }
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
}
