import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../features/side_effect/side_effect_ai_service.dart';

class SideEffectCheckerPage extends StatefulWidget {
  const SideEffectCheckerPage({super.key});

  @override
  State<SideEffectCheckerPage> createState() => _SideEffectCheckerPageState();
}

class _SideEffectCheckerPageState extends State<SideEffectCheckerPage> {
  final _formKey = GlobalKey<FormState>();
  final _medicineController = TextEditingController();
  final _doseController = TextEditingController();
  final _symptomsController = TextEditingController();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  SideEffectAnalysisResult? _result;
  String? _error;
  String _selectedGender = '';

  @override
  void dispose() {
    _medicineController.dispose();
    _doseController.dispose();
    _symptomsController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _conditionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<String> _split(String input) =>
      input.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _analyze() async {
    if (!_formKey.currentState!.validate()) return;
    if (dotenv.env['GEMINI_API_KEY']?.trim().isEmpty ?? true) {
      setState(
        () =>
            _error = 'Add GEMINI_API_KEY to .env to use side-effect analyzer.',
      );
      return;
    }
    final symptoms = _split(_symptomsController.text);
    if (symptoms.isEmpty) {
      setState(() => _error = 'Please enter at least one symptom.');
      return;
    }

    final age = int.tryParse(_ageController.text.trim());

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final res = await SideEffectAiService.instance.analyze(
        SideEffectAnalysisRequest(
          medicineName: _medicineController.text.trim(),
          dose: _doseController.text.trim(),
          symptoms: symptoms,
          patientAge: age,
          patientGender: _genderController.text.trim(),
          knownConditions: _split(_conditionsController.text),
          extraNotes: _notesController.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.deepOrange;
      case 'emergency':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        title: const Text('Side Effect Analyzer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _formCard(user),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _errorCard(_error!),
            ],
            if (_result != null) ...[
              const SizedBox(height: 12),
              _resultCard(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _formCard(User? user) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hi ${user?.displayName ?? ''}, describe the issue',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _medicineController,
                decoration: const InputDecoration(
                  labelText: 'Medicine name',
                  prefixIcon: Icon(Icons.medication_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _doseController,
                decoration: const InputDecoration(
                  labelText: 'Dose (optional)',
                  prefixIcon: Icon(Icons.science_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _symptomsController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Symptoms (comma separated)',
                  prefixIcon: Icon(Icons.sick_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age (optional)',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedGender.isEmpty ? null : _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender (optional)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  final selected = value ?? '';
                  setState(() => _selectedGender = selected);
                  _genderController.text = selected;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _conditionsController,
                decoration: const InputDecoration(
                  labelText: 'Known conditions (comma separated, optional)',
                  prefixIcon: Icon(Icons.healing_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notesController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Extra notes (optional)',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _analyze,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.analytics_outlined),
                label: Text(_isLoading ? 'Analyzing...' : 'Analyze'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _resultCard(SideEffectAnalysisResult result) {
    final color = _severityColor(result.severity);
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.health_and_safety, color: Color(0xFF0D47A1)),
                const SizedBox(width: 8),
                const Text(
                  'Analysis Result',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Chip(
                  label: Text(result.severity.toUpperCase()),
                  backgroundColor: color.withOpacity(0.12),
                  labelStyle: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Urgency: ${result.urgency}'),
            Text(
              'Doctor consult needed: ${result.doctorConsultationNeeded ? 'Yes' : 'No'}',
            ),
            Text(
              'Confidence: ${(result.confidence * 100).toStringAsFixed(0)}%',
            ),
            if (result.recommendation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                result.recommendation,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 10),
            _listBlock('Possible reasons', result.possibleReasons),
            _listBlock('Immediate actions', result.immediateActions),
            _listBlock('Warning signs', result.warningSigns),
            const SizedBox(height: 6),
            const Text(
              'Note: This is AI-generated guidance, not medical advice.',
              style: TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listBlock(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...items.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('- $e'),
            ),
          ),
        ],
      ),
    );
  }
}
