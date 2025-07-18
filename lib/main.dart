import 'ble_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'BLE Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE SCANNER")),
      body: GetBuilder<BleController>(
        init: BleController(),
        builder: (controller) {
          return Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: controller.scanResults,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final devices = snapshot.data!;
                      if (devices.isEmpty) {
                        return const Center(child: Text("No devices found"));
                      }
                      return ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
  final device = devices[index];
  final name = device.advertisementData.localName.isNotEmpty
      ? device.advertisementData.localName
      : (device.device.platformName.isNotEmpty
          ? device.device.platformName
          : "Unknown Device");

  return Card(
    child: ListTile(
      title: Text(name),
      subtitle: Text(device.device.remoteId.str),
      trailing: Text("${device.rssi} dBm"),
      onTap: () => controller.connectToDevice(device.device),
    ),
  );
},

                      );
                    } else {
                      return const Center(child: CircularProgressIndicator());
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
              onPressed: () => controller.scanDevices(),
              child: const Text("SCAN"),
              ),
              const SizedBox(height: 10),
            
              ElevatedButton(
              onPressed: () => controller.sendToEsp32("Hello from Flutter!"),
              child: const Text("SEND TO ESP32"),
             ),
              const SizedBox(height: 20),

            ],
          );
        },
      ),
    );
  }
}
