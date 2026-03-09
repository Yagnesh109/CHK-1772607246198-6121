import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/medicine_service.dart';
import 'barcode_scanner_screen.dart';

enum ScanSource { camera, gallery }

class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  final TextEditingController controller = TextEditingController();
  Map<String, dynamic>? data;
  String? errorMessage;

  Future<void> search() async {
    final result = await MedicineService.getMedicine(controller.text);
    _applyResult(result);
  }

  Future<void> _searchByBarcode(String code) async {
    final result = await MedicineService.getMedicineByBarcode(code);
    _applyResult(result);
  }

  void _applyResult(Map<String, dynamic> result) {
    final hasMedicineData =
        result["brand"] != null ||
        result["usage"] != null ||
        result["dosage"] != null ||
        result["side_effects"] != null;

    setState(() {
      data = result;
      errorMessage = result["error"]?.toString();
      if (!hasMedicineData && errorMessage == null && result["message"] != null) {
        errorMessage = result["message"].toString();
      }
    });
  }

  Future<void> _scanBarcode() async {
    final source = await showModalBottomSheet<ScanSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text("Scan with camera"),
                onTap: () => Navigator.of(context).pop(ScanSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text("Pick from gallery"),
                onTap: () => Navigator.of(context).pop(ScanSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    String? code;
    if (source == ScanSource.camera) {
      code = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
      );
    } else {
      code = await _scanFromGallery();
    }

    if (!mounted || code == null || code.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No barcode detected.")),
        );
      }
      return;
    }

    controller.text = code;
    await _searchByBarcode(code);
  }

  Future<String?> _scanFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return null;
    }

    final scannerController = MobileScannerController(autoStart: false);
    final completer = Completer<String?>();

    late final StreamSubscription<BarcodeCapture> subscription;
    subscription = scannerController.barcodes.listen((capture) {
      if (completer.isCompleted) return;
      for (final barcode in capture.barcodes) {
        final value = barcode.rawValue?.trim();
        if (value != null && value.isNotEmpty) {
          completer.complete(value);
          return;
        }
      }
    });

    try {
      final found = await scannerController.analyzeImage(picked.path);
      if (!found && !completer.isCompleted) {
        completer.complete(null);
      }
      return await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
    } finally {
      await subscription.cancel();
      scannerController.dispose();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Medicine Info")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: "Enter medicine name"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: search,
              child: const Text("Search"),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _scanBarcode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Scan Barcode"),
            ),
            const SizedBox(height: 30),
            if (data != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: errorMessage != null
                      ? Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data!["brand"]?.toString() ?? "Unknown brand"),
                            const SizedBox(height: 10),
                            Text(data!["usage"]?.toString() ?? "Usage not available"),
                            const SizedBox(height: 10),
                            Text(data!["dosage"]?.toString() ?? "Dosage not available"),
                            const SizedBox(height: 10),
                            Text(
                              data!["side_effects"]?.toString() ??
                                  "Side effects not available",
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
