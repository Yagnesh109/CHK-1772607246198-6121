import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import 'package:easy_localization/easy_localization.dart';
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
  late FlutterTts _tts;
  bool _ttsReady = false;
  bool _speaking = false;
  final GoogleTranslator _translator = GoogleTranslator();

  Future<void> _loadRoleAndPatients() async {
    // Placeholder kept for parity with other pages; no role-specific logic needed here.
  }

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _configureTts();
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _doseController.dispose();
    _symptomsController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _conditionsController.dispose();
    _notesController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _configureTts() async {
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    await _setTtsLanguage();
    if (mounted) setState(() => _ttsReady = true);
  }

  Future<void> _setTtsLanguage() async {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    final lang = switch (code) {
      'hi' => 'hi-IN',
      'mr' => 'mr-IN',
      _ => 'en-US',
    };
    await _tts.setLanguage(lang);
  }

  Future<void> _speakResult() async {
    if (!_ttsReady || _result == null) return;
    final r = _result!;
    final buffer = StringBuffer();
    buffer.writeln('Severity: ${r.severity}.');
    if (r.urgency.isNotEmpty) buffer.writeln('Urgency: ${r.urgency}.');
    if (r.recommendation.isNotEmpty) buffer.writeln(r.recommendation);
    if (r.immediateActions.isNotEmpty) {
      buffer.writeln('Immediate actions: ${r.immediateActions.join(', ')}.');
    }
    if (r.warningSigns.isNotEmpty) {
      buffer.writeln('Warning signs: ${r.warningSigns.join(', ')}.');
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) return;
    setState(() => _speaking = true);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _stopTts() async {
    await _tts.stop();
    if (mounted) setState(() => _speaking = false);
  }

  Future<SideEffectAnalysisResult> _localizeResult(
    SideEffectAnalysisResult res,
  ) async {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    if (locale == 'en') return res;

    Future<String> t(String input) async {
      if (input.trim().isEmpty) return input;
      try {
        final out = await _translator.translate(input, to: locale);
        return out.text;
      } catch (_) {
        return input;
      }
    }

    Future<List<String>> tl(List<String> list) async {
      final out = <String>[];
      for (final item in list) {
        out.add(await t(item));
      }
      return out;
    }

    return SideEffectAnalysisResult(
      severity: await t(res.severity),
      urgency: await t(res.urgency),
      doctorConsultationNeeded: res.doctorConsultationNeeded,
      recommendation: await t(res.recommendation),
      possibleReasons: await tl(res.possibleReasons),
      immediateActions: await tl(res.immediateActions),
      warningSigns: await tl(res.warningSigns),
      confidence: res.confidence,
      source: res.source,
    );
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
      final localized = await _localizeResult(res);
      setState(() => _result = localized);
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
        title: Text(tr('side_effect_analyzer')),
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
                tr('side_effect_greeting', args: [user?.displayName ?? '']),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _medicineController,
                decoration: InputDecoration(
                  labelText: tr('medicine_name_label'),
                  prefixIcon: const Icon(Icons.medication_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? tr('required') : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _doseController,
                decoration: InputDecoration(
                  labelText: tr('dose_optional'),
                  prefixIcon: const Icon(Icons.science_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _symptomsController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: tr('symptoms_label'),
                  prefixIcon: const Icon(Icons.sick_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? tr('required') : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('age_optional'),
                  prefixIcon: const Icon(Icons.calendar_month_outlined),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedGender.isEmpty ? null : _selectedGender,
                decoration: InputDecoration(
                  labelText: tr('gender_optional'),
                  prefixIcon: const Icon(Icons.person_outline),
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
                decoration: InputDecoration(
                  labelText: tr('conditions_optional'),
                  prefixIcon: const Icon(Icons.healing_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notesController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: tr('notes_optional'),
                  prefixIcon: const Icon(Icons.note_alt_outlined),
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
                label: Text(_isLoading ? tr('analyzing') : tr('analyze')),
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
                Text(
                  tr('analysis_result'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
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
            Text('${tr('urgency')}: ${result.urgency}'),
            Text(
              '${tr('doctor_consult_needed')}: ${result.doctorConsultationNeeded ? tr('yes') : tr('no')}',
            ),
            Text(
              '${tr('confidence')}: ${(result.confidence * 100).toStringAsFixed(0)}%',
            ),
            if (result.recommendation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                result.recommendation,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 10),
            _listBlock(tr('possible_reasons'), result.possibleReasons),
            _listBlock(tr('immediate_actions'), result.immediateActions),
            _listBlock(tr('warning_signs'), result.warningSigns),
            const SizedBox(height: 6),
            Text(
              tr('ai_note'),
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: (!_ttsReady || _speaking) ? null : _speakResult,
                  icon: const Icon(Icons.volume_up),
                  label: Text(tr('play')),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _speaking ? _stopTts : null,
                  icon: const Icon(Icons.pause),
                  label: Text(tr('pause')),
                ),
              ],
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
