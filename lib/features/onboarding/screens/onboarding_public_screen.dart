import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/onboarding_model.dart';
import '../../../providers/service_providers.dart';

class OnboardingPublicScreen extends ConsumerStatefulWidget {
  const OnboardingPublicScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<OnboardingPublicScreen> createState() =>
      _OnboardingPublicScreenState();
}

class _OnboardingPublicScreenState
    extends ConsumerState<OnboardingPublicScreen> {
  int _step = 0;
  OnboardingLinkModel? _link;
  String? _submissionId;
  bool _loading = true;
  bool _submitting = false;
  Uint8List? _profileBytes;
  final List<({String name, Uint8List bytes})> _documents = [];

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _fatherName = TextEditingController();
  final _cnic = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _department = TextEditingController();
  final _position = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLink();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _fatherName.dispose();
    _cnic.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _department.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _loadLink() async {
    final link =
        await ref.read(onboardingServiceProvider).getLinkByToken(widget.token);
    setState(() {
      _link = link;
      _loading = false;
    });
  }

  OnboardingSubmissionModel _buildSubmission() {
    return OnboardingSubmissionModel(
      id: _submissionId ?? '',
      linkId: _link?.id ?? '',
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      fatherName: _fatherName.text.trim(),
      cnic: _cnic.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      department: _department.text.trim(),
      position: _position.text.trim(),
      currentStep: _step,
    );
  }

  Future<void> _saveDraft() async {
    try {
      final id = await ref
          .read(onboardingServiceProvider)
          .saveDraft(_buildSubmission());
      setState(() => _submissionId = id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    }
  }

  Future<void> _pickProfile() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() => _profileBytes = bytes);
    }
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      for (final f in result.files) {
        if (f.bytes != null) {
          _documents.add((name: f.name, bytes: f.bytes!));
        }
      }
      setState(() {});
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      var submissionId = _submissionId ?? '';
      if (submissionId.isEmpty) {
        submissionId =
            await ref.read(onboardingServiceProvider).saveDraft(_buildSubmission());
      }
      final storage = ref.read(storageServiceProvider);
      String? profileUrl;
      if (_profileBytes != null) {
        profileUrl = await storage.uploadOnboardingFile(
          submissionId,
          _profileBytes!,
          'profile.jpg',
        );
      }
      final docUrls = <String>[];
      for (final doc in _documents) {
        final url = await storage.uploadOnboardingFile(
          submissionId,
          doc.bytes,
          doc.name,
        );
        docUrls.add(url);
      }
      final submission = OnboardingSubmissionModel(
        id: submissionId,
        linkId: _link!.id,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        fatherName: _fatherName.text.trim(),
        cnic: _cnic.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
        department: _department.text.trim(),
        position: _position.text.trim(),
        profilePictureUrl: profileUrl,
        documentUrls: docUrls,
        currentStep: _step,
      );
      await ref.read(onboardingServiceProvider).submitApplication(submission);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Submitted'),
            content: const Text(
              'Your onboarding application was submitted. HR will review it shortly.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        return Validators.required(_firstName.text, 'First name') == null &&
            Validators.required(_lastName.text, 'Last name') == null &&
            Validators.cnic(_cnic.text) == null;
      case 1:
        return Validators.email(_email.text) == null &&
            Validators.phone(_phone.text) == null;
      case 2:
        return Validators.required(_department.text, 'Department') == null &&
            Validators.required(_position.text, 'Position') == null;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_link == null || !_link!.isValid) {
      return const Scaffold(
        body: Center(child: Text('Invalid or expired onboarding link')),
      );
    }

    final steps = ['Personal', 'Contact', 'Job', 'Documents'];
    final progress = (_step + 1) / steps.length;

    return Scaffold(
      appBar: AppBar(title: Text(_link!.title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: GlassCard(
              child: Column(
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('Step ${_step + 1} of ${steps.length}: ${steps[_step]}'),
                  const SizedBox(height: 24),
                  if (_step == 0) ...[
                    TextFormField(
                        controller: _firstName,
                        decoration: const InputDecoration(labelText: 'First Name')),
                    TextFormField(
                        controller: _lastName,
                        decoration: const InputDecoration(labelText: 'Last Name')),
                    TextFormField(
                        controller: _fatherName,
                        decoration: const InputDecoration(labelText: 'Father Name')),
                    TextFormField(
                        controller: _cnic,
                        decoration: const InputDecoration(labelText: 'CNIC')),
                  ] else if (_step == 1) ...[
                    TextFormField(
                        controller: _phone,
                        decoration: const InputDecoration(labelText: 'Phone')),
                    TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'Email')),
                    TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(labelText: 'Address')),
                  ] else if (_step == 2) ...[
                    TextFormField(
                        controller: _department,
                        decoration: const InputDecoration(labelText: 'Department')),
                    TextFormField(
                        controller: _position,
                        decoration: const InputDecoration(labelText: 'Position')),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: _pickProfile,
                      icon: const Icon(Icons.person),
                      label: Text(_profileBytes != null
                          ? 'Profile photo selected'
                          : 'Upload profile photo'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickDocuments,
                      icon: const Icon(Icons.upload_file),
                      label: Text('Documents (${_documents.length})'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (_step > 0)
                        TextButton(
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _step--),
                          child: const Text('Back'),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: _submitting ? null : _saveDraft,
                        child: const Text('Save Draft'),
                      ),
                      const SizedBox(width: 8),
                      if (_step < steps.length - 1)
                        ElevatedButton(
                          onPressed: _submitting
                              ? null
                              : () {
                                  if (!_validateStep()) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Fix validation errors')),
                                    );
                                    return;
                                  }
                                  setState(() => _step++);
                                },
                          child: const Text('Next'),
                        )
                      else
                        ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Submit'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
