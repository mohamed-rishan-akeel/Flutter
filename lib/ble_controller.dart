import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

// UUIDs matching the ESP32
const String serviceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
const String txCharUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; // ESP32 notify
const String rxCharUUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; // ESP32 write

class BleController extends GetxController {
  final RxBool _isScanning = false.obs;
  final RxString connectionState = "Disconnected".obs;
  final RxList<String> receivedMessages = <String>[].obs;
  BluetoothCharacteristic? txChar;
  BluetoothCharacteristic? rxChar;
  BluetoothDevice? connectedDevice;

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  bool get isScanning => _isScanning.value;

  @override
  void onInit() {
    super.onInit();
    FlutterBluePlus.adapterState.listen((state) {
      if (state != BluetoothAdapterState.on) {
        Get.snackbar("Error", "Bluetooth is turned off");
        connectionState.value = "Disconnected";
      }
    });
  }

  /// Start scanning for BLE devices
  Future<void> scanDevices() async {
    final scanPermission = await Permission.bluetoothScan.request();
    final connectPermission = await Permission.bluetoothConnect.request();
    final locationPermission = await Permission.locationWhenInUse.request();

    if (scanPermission.isGranted &&
        connectPermission.isGranted &&
        locationPermission.isGranted) {
      debugPrint("🔍 Starting BLE scan...");
      _isScanning.value = true;
      try {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
        await Future.delayed(const Duration(seconds: 11));
        await FlutterBluePlus.stopScan();
        debugPrint("✅ Scan completed.");
      } catch (e) {
        Get.snackbar("Error", "Scan failed: $e");
        debugPrint("⚠️ Scan error: $e");
      } finally {
        _isScanning.value = false;
      }
    } else {
      Get.snackbar("Error", "Required permissions not granted");
      debugPrint("❌ Permissions denied");
    }
  }

  /// Connect to a BLE device
  Future<void> connectToDevice(BluetoothDevice device) async {
    debugPrint("🔌 Connecting to: ${device.platformName} (${device.remoteId.str})");
    connectionState.value = "Connecting...";

    try {
      await device.disconnect(); // Clean up previous connection
      await Future.delayed(const Duration(seconds: 1));
    } catch (_) {}

    try {
      await device.connect(timeout: const Duration(seconds: 15), autoConnect: false);
      connectedDevice = device;
      connectionState.value = "Connected";
      debugPrint("✅ Connected to ${device.platformName}");

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          connectionState.value = "Connected";
          debugPrint("🟢 Device connected: ${device.platformName}");
        } else if (state == BluetoothConnectionState.disconnected) {
          connectionState.value = "Disconnected";
          connectedDevice = null;
          txChar = null;
          rxChar = null;
          debugPrint("🔴 Device disconnected: ${device.platformName}");
          Get.snackbar("Disconnected", "${device.platformName} disconnected");
        }
      });

      await discoverServices(device);
    } catch (e) {
      connectionState.value = "Disconnected";
      debugPrint("⚠️ Connection failed: $e");
      Get.snackbar("Error", "Failed to connect: $e");
    }
  }

  /// Discover services and characteristics
  Future<void> discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      bool serviceFound = false;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUUID) {
          serviceFound = true;
          debugPrint("✅ Found service: $serviceUUID");
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == txCharUUID) {
              txChar = characteristic;
              await txChar!.setNotifyValue(true);
              debugPrint("✅ Subscribed to TX characteristic: $txCharUUID");
              txChar!.lastValueStream.listen((value) {
                final message = String.fromCharCodes(value);
                receivedMessages.add("ESP32: $message");
                debugPrint("📥 From ESP32: $message");
              }, onError: (e) {
                debugPrint("⚠️ Notification error: $e");
                Get.snackbar("Error", "Failed to receive notification: $e");
              });
            } else if (characteristic.uuid.toString().toLowerCase() == rxCharUUID) {
              rxChar = characteristic;
              debugPrint("✅ Found RX characteristic: $rxCharUUID");
            }
          }
        }
      }
      if (!serviceFound) {
        Get.snackbar("Error", "Service $serviceUUID not found");
        debugPrint("⚠️ Service $serviceUUID not found");
      } else if (txChar == null || rxChar == null) {
        Get.snackbar("Error", "Required characteristics not found");
        debugPrint("⚠️ Characteristics not found: TX=$txChar, RX=$rxChar");
      } else {
        debugPrint("✅ Characteristics discovered");
      }
    } catch (e) {
      Get.snackbar("Error", "Service discovery failed: $e");
      debugPrint("⚠️ Discovery error: $e");
    }
  }

  /// Send message to ESP32
  Future<void> sendToEsp32(String message) async {
    if (rxChar != null && connectionState.value == "Connected") {
      try {
        await rxChar!.write(utf8.encode(message));
        debugPrint("📤 Sent to ESP32: $message");
        receivedMessages.add("You: $message"); // Show sent message in UI
      } catch (e) {
        Get.snackbar("Error", "Failed to send message: $e");
        debugPrint("⚠️ Send error: $e");
      }
    } else {
      Get.snackbar("Error", "Not connected or RX characteristic unavailable");
      debugPrint("⚠️ Cannot send: RX=$rxChar, State=${connectionState.value}");
    }
  }
}