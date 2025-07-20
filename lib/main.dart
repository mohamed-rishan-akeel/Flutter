import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'ble_controller.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("Building MyApp");
    return GetMaterialApp(
      title: 'BLE Messenger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          primary: Colors.blueAccent,
          secondary: Colors.teal,
          surface: Colors.grey[100],
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 4,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
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
  final BleController controller = Get.put(BleController());
  final RxString _errorMessage = "".obs;

  @override
  Widget build(BuildContext context) {
    debugPrint("Building MyHomePage");
    return Scaffold(
      appBar: AppBar(
        title: const Text("BLE Messenger"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Connection status
                Obx(() {
                  debugPrint("Updating status: ${controller.connectionState.value}");
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: controller.connectionState.value == "Connected"
                                  ? Colors.green
                                  : (controller.connectionState.value == "Connecting..."
                                      ? Colors.orange
                                      : Colors.red),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage.value.isNotEmpty
                                  ? "Error: ${_errorMessage.value}"
                                  : "Status: ${controller.connectionState.value}",
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                    color: _errorMessage.value.isNotEmpty
                                        ? Colors.red
                                        : (controller.connectionState.value == "Connected"
                                            ? Colors.green
                                            : (controller.connectionState.value == "Connecting..."
                                                ? Colors.orange
                                                : Colors.red)),
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // Scan button
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: controller.isScanning ? null : () => controller.scanDevices(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      child: Obx(() => Text(
                            controller.isScanning ? "Scanning..." : "Scan & Connect",
                            style: const TextStyle(fontSize: 16),
                          )),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Device list
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Available Devices",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Obx(() {
                            debugPrint("Updating device list: ${controller.scanResults.length}");
                            final devices = controller.scanResults.value;
                            if (devices.isEmpty) {
                              return const Center(child: Text("No devices found"));
                            }
                            return ListView.builder(
                              itemCount: devices.length,
                              itemBuilder: (context, index) {
                                final device = devices[index];
                                final name = device.advertisementData.advName.isNotEmpty
                                    ? device.advertisementData.advName
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
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Message list
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Messages",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Obx(() {
                            debugPrint("Updating messages: ${controller.receivedMessages.length}");
                            return controller.receivedMessages.isEmpty
                                ? const Center(child: Text("No messages received"))
                                : ListView.builder(
                                    itemCount: controller.receivedMessages.length,
                                    itemBuilder: (context, index) {
                                      final message = controller.receivedMessages[index];
                                      final isSent = message.startsWith("You:");
                                      return Align(
                                        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(vertical: 4),
                                          padding: const EdgeInsets.all(12),
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSent
                                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                                : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            message,
                                            style: TextStyle(
                                              color: isSent
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Message input
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              labelText: "Type a message",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(8)),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final message = _messageController.text.trim();
                            if (message.isNotEmpty) {
                              _errorMessage.value = "";
                              await controller.handleMessage(message, (error) {
                                _errorMessage.value = error;
                              });
                              _messageController.clear();
                            } else {
                              _errorMessage.value = "Please enter a message";
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                          ),
                          child: const Text("Send"),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Clear messages
                TextButton(
                  onPressed: () => controller.receivedMessages.clear(),
                  child: const Text("Clear Messages"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}