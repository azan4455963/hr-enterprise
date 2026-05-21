import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/employee_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/service_providers.dart';

class EmployeeFormScreen extends ConsumerStatefulWidget {
  const EmployeeFormScreen({super.key, this.employeeId});

  final String? employeeId;

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _fatherName = TextEditingController();
  final _cnic = TextEditingController();
  final _address = TextEditingController();
  final _position = TextEditingController();
  final _department = TextEditingController();
  final _salary = TextEditingController();
  bool _loading = false;
  Uint8List? _photoBytes;
  String? _existingPhotoUrl;

  @override
  void initState() {
    super.initState();
    if (widget.employeeId != null) _loadEmployee();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _fatherName.dispose();
    _cnic.dispose();
    _address.dispose();
    _position.dispose();
    _department.dispose();
    _salary.dispose();
    super.dispose();
  }

  Future<void> _loadEmployee() async {
    final emp = await ref
        .read(employeeServiceProvider)
        .getEmployee(widget.employeeId!);
    if (emp != null && mounted) {
      _firstName.text = emp.firstName;
      _lastName.text = emp.lastName;
      _email.text = emp.email;
      _phone.text = emp.phone ?? '';
      _fatherName.text = emp.fatherName ?? '';
      _cnic.text = emp.cnic ?? '';
      _address.text = emp.address ?? '';
      _position.text = emp.position ?? '';
      _department.text = emp.departmentName ?? '';
      _salary.text = emp.salary?.toString() ?? '';
      _existingPhotoUrl = emp.profilePictureUrl;
      setState(() {});
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() => _photoBytes = bytes);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    try {
      var employee = EmployeeModel(
        id: widget.employeeId ?? '',
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        fatherName: _fatherName.text.trim(),
        cnic: _cnic.text.trim(),
        address: _address.text.trim(),
        position: _position.text.trim(),
        departmentName: _department.text.trim(),
        salary: double.tryParse(_salary.text),
        profilePictureUrl: _existingPhotoUrl,
        joiningDate: DateTime.now(),
      );

      if (widget.employeeId != null) {
        if (_photoBytes != null) {
          final url = await ref.read(storageServiceProvider).uploadProfilePhoto(
                widget.employeeId!,
                _photoBytes!,
              );
          employee = EmployeeModel(
            id: widget.employeeId!,
            firstName: employee.firstName,
            lastName: employee.lastName,
            email: employee.email,
            phone: employee.phone,
            fatherName: employee.fatherName,
            cnic: employee.cnic,
            address: employee.address,
            position: employee.position,
            departmentName: employee.departmentName,
            salary: employee.salary,
            profilePictureUrl: url,
            joiningDate: employee.joiningDate,
          );
        }
        await ref.read(employeeServiceProvider).updateEmployee(
              employee,
              userId: user.id,
            );
      } else {
        final id = await ref.read(employeeServiceProvider).createEmployee(
              employee,
              userId: user.id,
            );
        if (_photoBytes != null) {
          final url = await ref.read(storageServiceProvider).uploadProfilePhoto(
                id,
                _photoBytes!,
              );
          await ref.read(employeeServiceProvider).updateEmployee(
                EmployeeModel(
                  id: id,
                  firstName: employee.firstName,
                  lastName: employee.lastName,
                  email: employee.email,
                  phone: employee.phone,
                  fatherName: employee.fatherName,
                  cnic: employee.cnic,
                  address: employee.address,
                  position: employee.position,
                  departmentName: employee.departmentName,
                  salary: employee.salary,
                  profilePictureUrl: url,
                  joiningDate: employee.joiningDate,
                ),
                userId: user.id,
              );
        }
        await ref.read(employeeServiceProvider).linkEmployeeToUser(
              employeeId: id,
              email: employee.email,
            );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canViewSalary =
        ref.watch(currentUserProvider).valueOrNull?.canViewSalary() ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employeeId == null ? 'Add Employee' : 'Edit Employee'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: GlassCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: CircleAvatar(
                      radius: 48,
                      backgroundImage: _photoBytes != null
                          ? MemoryImage(_photoBytes!)
                          : (_existingPhotoUrl != null
                              ? NetworkImage(_existingPhotoUrl!)
                              : null) as ImageProvider?,
                      child: _photoBytes == null && _existingPhotoUrl == null
                          ? const Icon(Icons.camera_alt, size: 40)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap to upload profile photo'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstName,
                          decoration: const InputDecoration(labelText: 'First Name'),
                          validator: (v) => Validators.required(v, 'First name'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastName,
                          decoration: const InputDecoration(labelText: 'Last Name'),
                          validator: (v) => Validators.required(v, 'Last name'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: Validators.email,
                  ),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    validator: Validators.phone,
                  ),
                  TextFormField(
                    controller: _fatherName,
                    decoration: const InputDecoration(labelText: 'Father Name'),
                  ),
                  TextFormField(
                    controller: _cnic,
                    decoration: const InputDecoration(labelText: 'CNIC'),
                    validator: Validators.cnic,
                  ),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  TextFormField(
                    controller: _position,
                    decoration: const InputDecoration(labelText: 'Position'),
                    validator: (v) => Validators.required(v, 'Position'),
                  ),
                  TextFormField(
                    controller: _department,
                    decoration: const InputDecoration(labelText: 'Department'),
                    validator: (v) => Validators.required(v, 'Department'),
                  ),
                  if (canViewSalary)
                    TextFormField(
                      controller: _salary,
                      decoration: const InputDecoration(labelText: 'Salary'),
                      keyboardType: TextInputType.number,
                      validator: Validators.positiveNumber,
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
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
