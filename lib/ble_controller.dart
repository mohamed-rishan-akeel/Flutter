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
  final RxList<ScanResult> scanResults = <ScanResult>[].obs;
  BluetoothCharacteristic? txChar;
  BluetoothCharacteristic? rxChar;
  BluetoothDevice? connectedDevice;

  bool get isScanning => _isScanning.value;

  @override
  void onInit() {
    super.onInit();
    debugPrint("Initializing BleController");
    FlutterBluePlus.adapterState.listen((state) {
      debugPrint("Bluetooth adapter state: $state");
      if (state != BluetoothAdapterState.on) {
        connectionState.value = "Disconnected";
        throwError("Bluetooth is turned off");
      }
    });
    FlutterBluePlus.scanResults.listen((results) {
      scanResults.value = results;
      debugPrint("Scan results updated: ${results.length} devices found");
    });
  }

  void throwError(String message) {
    debugPrint("⚠️ Error: $message");
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
        throwError("Scan failed: $e");
        throw "Scan failed: $e";
      } finally {
        _isScanning.value = false;
      }
    } else {
      throwError("Required permissions not granted");
      throw "Required permissions not granted";
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
        debugPrint("Connection state changed: $state");
        if (state == BluetoothConnectionState.connected) {
          connectionState.value = "Connected";
          debugPrint("🟢 Device connected: ${device.platformName}");
        } else if (state == BluetoothConnectionState.disconnected) {
          connectionState.value = "Disconnected";
          connectedDevice = null;
          txChar = null;
          rxChar = null;
          debugPrint("🔴 Device disconnected: ${device.platformName}");
        }
      });

      await discoverServices(device);
    } catch (e) {
      connectionState.value = "Disconnected";
      throwError("Connection failed: $e");
      throw "Failed to connect: $e";
    }
  }

  /// Discover services and characteristics
  Future<void> discoverServices(BluetoothDevice device) async {
    try {
      debugPrint("Starting service discovery");
      List<BluetoothService> services = await device.discoverServices();
      bool serviceFound = false;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUUID) {
          serviceFound = true;
          debugPrint("✅ Found service: $serviceUUID");
          for (var characteristic in service.characteristics) {
            debugPrint("Found characteristic: ${characteristic.uuid}");
            if (characteristic.uuid.toString().toLowerCase() == txCharUUID) {
              txChar = characteristic;
              try {
                await txChar!.setNotifyValue(true);
                debugPrint("✅ Subscribed to TX characteristic: $txCharUUID");
                txChar!.lastValueStream.listen((value) {
                  debugPrint("Raw notification value: $value");
                  final message = String.fromCharCodes(value);
                  receivedMessages.add("ESP32: $message");
                  debugPrint("📥 From ESP32: $message");
                }, onError: (e) {
                  throwError("Notification error: $e");
                  throw "Failed to receive notification: $e";
                });
              } catch (e) {
                throwError("Failed to subscribe to TX characteristic: $e");
                throw "Failed to subscribe to notifications: $e";
              }
            } else if (characteristic.uuid.toString().toLowerCase() == rxCharUUID) {
              rxChar = characteristic;
              debugPrint("✅ Found RX characteristic: $rxCharUUID");
            }
          }
        }
      }
      if (!serviceFound) {
        throwError("Service $serviceUUID not found");
        throw "Service $serviceUUID not found";
      } else if (txChar == null || rxChar == null) {
        throwError("Characteristics not found: TX=$txChar, RX=$rxChar");
        throw "Required characteristics not found";
      } else {
        debugPrint("✅ Characteristics discovered");
      }
    } catch (e) {
      throwError("Discovery error: $e");
      throw "Service discovery failed: $e";
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
        throwError("Send error: $e");
        throw "Failed to send message: $e";
      }
    } else {
      throwError("Cannot send: RX=$rxChar, State=${connectionState.value}");
      throw "Not connected or RX characteristic unavailable";
    }
  }

  /// Handle message workflow: scan, connect, send
  Future<void> handleMessage(String message, Function(String) onError) async {
    if (connectionState.value == "Connected" && connectedDevice != null) {
      try {
        await sendToEsp32(message);
      } catch (e) {
        onError(e.toString());
      }
      return;
    }

    // Scan and connect to ESP32_BLE
    try {
      await scanDevices();
      final devices = scanResults.value;
      debugPrint("Devices found during auto-connect: ${devices.length}");
      final esp32Device = devices.firstWhereOrNull(
        (r) => r.advertisementData.advName == "ESP32_BLE",
      );
      if (esp32Device != null) {
        debugPrint("Found ESP32_BLE, connecting...");
        await connectToDevice(esp32Device.device);
        if (connectionState.value == "Connected") {
          await sendToEsp32(message);
        }
      } else {
        onError("ESP32_BLE not found");
        debugPrint("⚠️ ESP32_BLE not found during scan");
      }
    } catch (e) {
      onError(e.toString());
    }
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}