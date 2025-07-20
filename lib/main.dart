import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'ble_controller.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'BLE Messenger',
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
  final TextEditingController _messageController = TextEditingController();
  final BleController controller = Get.put(BleController()); // Ensure single instance

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE MESSENGER")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection status
            Obx(() => Text(
                  "Status: ${controller.connectionState.value}",
                  style: TextStyle(
                    color: controller.connectionState.value == "Connected"
                        ? Colors.green
                        : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                )),
            const SizedBox(height: 16),
            // Scan button
            ElevatedButton(
              onPressed: controller.isScanning ? null : () => controller.scanDevices(),
              child: Obx(() => Text(controller.isScanning ? "SCANNING..." : "SCAN DEVICES")),
            ),
            const SizedBox(height: 16),
            // Device list
            Container(
              height: 200, // Fixed height for device list
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
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
                        return ListTile(
                          title: Text(name),
                          subtitle: Text(device.device.remoteId.str),
                          trailing: Text("${device.rssi} dBm"),
                          onTap: () => controller.connectToDevice(device.device),
                        );
                      },
                    );
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            // Received messages
            Container(
              height: 150, // Fixed height for messages
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Obx(() => controller.receivedMessages.isEmpty
                  ? const Center(child: Text("No messages received"))
                  : ListView.builder(
                      itemCount: controller.receivedMessages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Text(controller.receivedMessages[index]),
                        );
                      },
                    )),
            ),
            const SizedBox(height: 16),
            // Message input
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: "Enter message",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Send button
            ElevatedButton(
              onPressed: () {
                final message = _messageController.text.trim();
                if (message.isNotEmpty) {
                  controller.sendToEsp32(message);
                  _messageController.clear();
                } else {
                  Get.snackbar("Error", "Please enter a message");
                }
              },
              child: const Text("SEND TO ESP32"),
            ),
          ],
        ),
      ),
    );
  }
}