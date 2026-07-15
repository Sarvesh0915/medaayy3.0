import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _ocr = OcrService();
  bool _scanning = false;
  List<String> _lines = [];
  String? _selected;

  Future<void> _capture() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo == null) return;

    setState(() => _scanning = true);
    final lines = await _ocr.scanImage(File(photo.path));
    setState(() {
      _lines = lines;
      _scanning = false;
    });
  }

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan prescription')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(ocrDisclaimer, style: const TextStyle(fontSize: 12.5)),
            ),
            const SizedBox(height: 16),
            if (_lines.isEmpty && !_scanning)
              OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take a photo of the prescription'),
                onPressed: _capture,
              ),
            if (_scanning) const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            if (_lines.isNotEmpty) ...[
              const Text('Tap the line that has the medicine name:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: _lines
                      .map((line) => RadioListTile<String>(
                            value: line,
                            groupValue: _selected,
                            title: Text(line),
                            onChanged: (v) => setState(() => _selected = v),
                          ))
                      .toList(),
                ),
              ),
              ElevatedButton(
                onPressed: _selected == null ? null : () => Navigator.of(context).pop(_selected),
                child: const Text('Use this'),
              ),
              TextButton(onPressed: _capture, child: const Text('Retake photo')),
            ],
          ],
        ),
      ),
    );
  }
}
