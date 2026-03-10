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
  bool _loading = false;

  Future<void> search() async {
    setState(() => _loading = true);
    final result = await MedicineService.getMedicine(controller.text);
    _applyResult(result);
  }

  Future<void> _searchByBarcode(String code) async {
    setState(() => _loading = true);
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
      if (!hasMedicineData &&
          errorMessage == null &&
          result["message"] != null) {
        errorMessage = result["message"].toString();
      }
      _loading = false;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("No barcode detected.")));
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
      appBar: AppBar(title: const Text("Medicine Search")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _searchCard(),
            const SizedBox(height: 16),
            if (data != null) _resultCard(),
            _disclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _searchCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Enter medicine name",
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : search,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_loading ? "Searching..." : "Search"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text("Scan Barcode"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard() {
    if (errorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    final brand = data?['brand']?.toString().trim();
    final usage = data?['usage']?.toString().trim();
    final dosage = data?['dosage']?.toString().trim();
    final sideEffects = data?['side_effects']?.toString().trim();
    final warning = data?['warning']?.toString();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medication, color: Color(0xFF0D47A1)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand?.isNotEmpty == true ? brand! : "Unknown medicine",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      if (warning != null && warning.isNotEmpty)
                        Text(
                          warning!,
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _infoRow(Icons.info_outline, usage, 'Usage not available'),
            const SizedBox(height: 10),
            _infoRow(
              Icons.medication_liquid_outlined,
              dosage,
              'Dosage not available',
            ),
            const SizedBox(height: 10),
            _infoRow(
              Icons.warning_amber_outlined,
              sideEffects,
              'Side effects not available',
            ),
          ],
        ),
      ),
    );
  }

  Widget _disclaimer() {
    return const Padding(
      padding: EdgeInsets.only(top: 12),
      child: Text(
        "Note: This tool can make mistakes. Please verify medicine details.",
        style: TextStyle(color: Colors.blueGrey, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _infoRow(IconData icon, String? value, String fallback) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0D47A1)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            (value?.isNotEmpty == true) ? value! : fallback,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}
