import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../utils/constants.dart';
import '../services/api_service.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _documentNumberController =
      TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _idFrontImage;
  File? _idBackImage;
  File? _selfieImage;
  bool _isLoading = false;
  bool _isLoadingData = true;
  DateTime? _selectedDate;
  String _selectedDocumentType = 'passport';

  // KYC Data from backend
  String _kycStatus = 'unverified';
  bool _isEligible = false;
  double _overallProgress = 0.0;
  List<Map<String, dynamic>> _checklist = [];
  Map<String, dynamic>? _submission;
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _documentNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadKycStatus() async {
    setState(() => _isLoadingData = true);
    try {
      final response = await ApiService.getKycStatus();
      setState(() {
        _kycStatus = response['kycStatus'] ?? 'unverified';
        _isEligible = response['isEligible'] ?? false;
        _overallProgress = (response['overallProgress'] ?? 0.0).toDouble();
        _checklist =
            List<Map<String, dynamic>>.from(response['checklist'] ?? []);
        _submission = response['submission'];
        _rejectionReason = _submission?['rejectionReason'];
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
      _showSnackBar('Failed to load KYC status: $e', isError: true);
    }
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          if (type == 'front') {
            _idFrontImage = File(image.path);
          } else if (type == 'back') {
            _idBackImage = File(image.path);
          } else if (type == 'selfie') {
            _selfieImage = File(image.path);
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1940),
      lastDate:
          DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.cardDark,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitKyc() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      _showSnackBar('Please select your date of birth', isError: true);
      return;
    }

    if (_idFrontImage == null || _selfieImage == null) {
      _showSnackBar('Please upload ID front image and selfie', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dateOfBirth = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      final response = await ApiService.submitKyc(
        fullName: _fullNameController.text.trim(),
        dateOfBirth: dateOfBirth,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        country: _countryController.text.trim(),
        postalCode: _postalCodeController.text.trim().isEmpty
            ? null
            : _postalCodeController.text.trim(),
        documentType: _selectedDocumentType,
        documentNumber: _documentNumberController.text.trim(),
        documentFront: _idFrontImage,
        documentBack: _idBackImage,
        selfie: _selfieImage,
      );

      setState(() => _isLoading = false);
      _showSnackBar(response['message'] ?? 'KYC submitted successfully!',
          isSuccess: true);
      await _loadKycStatus();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Future<void> _resubmitKyc() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      _showSnackBar('Please select your date of birth', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dateOfBirth = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      final response = await ApiService.resubmitKyc(
        fullName: _fullNameController.text.trim(),
        dateOfBirth: dateOfBirth,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        country: _countryController.text.trim(),
        postalCode: _postalCodeController.text.trim().isEmpty
            ? null
            : _postalCodeController.text.trim(),
        documentType: _selectedDocumentType,
        documentNumber: _documentNumberController.text.trim(),
        documentFront: _idFrontImage,
        documentBack: _idBackImage,
        selfie: _selfieImage,
      );

      setState(() => _isLoading = false);
      _showSnackBar(response['message'] ?? 'KYC resubmitted successfully!',
          isSuccess: true);
      await _loadKycStatus();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _showSnackBar(String message,
      {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppColors.error
            : isSuccess
                ? AppColors.success
                : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title: const Text('KYC Verification',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingData
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadKycStatus,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 24),
                    if (_checklist.isNotEmpty) ...[
                      _buildProgressChecklist(),
                      const SizedBox(height: 24),
                    ],
                    if (_kycStatus == 'unverified' && _isEligible)
                      _buildKycForm()
                    else if (_kycStatus == 'unverified' && !_isEligible)
                      _buildNotEligibleView()
                    else if (_kycStatus == 'rejected')
                      _buildKycForm(isResubmit: true)
                    else if (_kycStatus == 'pending')
                      _buildPendingView()
                    else if (_kycStatus == 'approved')
                      _buildApprovedView(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_kycStatus) {
      case 'approved':
        statusColor = AppColors.success;
        statusText = 'Verified';
        statusIcon = Icons.verified;
        break;
      case 'pending':
        statusColor = AppColors.warning;
        statusText = 'Pending Review';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusText = 'Rejected';
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unverified';
        statusIcon = Icons.shield_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(statusIcon, color: statusColor, size: 48),
          const SizedBox(height: 16),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getStatusMessage(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          if (_rejectionReason != null && _kycStatus == 'rejected') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: $_rejectionReason',
                      style:
                          const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusMessage() {
    switch (_kycStatus) {
      case 'approved':
        return 'Your identity has been verified. You now have full access to all features.';
      case 'pending':
        return 'Your documents are under review. This process usually takes 24-48 hours.';
      case 'rejected':
        return 'Your KYC was rejected. Please review the reason and submit again with corrections.';
      default:
        return _isEligible
            ? 'You are eligible to submit KYC. Verify your identity to unlock withdrawals.'
            : 'Complete the requirements below to become eligible for KYC verification.';
    }
  }

  Widget _buildProgressChecklist() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rounded, color: AppColors.primary),
              SizedBox(width: 12),
              Text('Eligibility Requirements', style: AppTextStyles.heading3),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Overall Progress: ${_overallProgress.toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ..._checklist.map((item) => _buildChecklistItem(item)),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(Map<String, dynamic> item) {
    final progress = (item['progress'] ?? 0.0).toDouble();
    final completed = item['completed'] ?? false;
    final current = item['current'] ?? 0;
    final required = item['required'] ?? 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                completed ? Icons.check_circle : Icons.radio_button_unchecked,
                color: completed ? AppColors.success : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item['title'] ?? '',
                  style: TextStyle(
                    color: completed ? Colors.white : Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$current/$required',
                style: TextStyle(
                  color: completed ? AppColors.success : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 6,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(
                completed ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
          if (item['description'] != null) ...[
            const SizedBox(height: 4),
            Text(
              item['description'],
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotEligibleView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.lock_clock, color: Colors.grey, size: 64),
          SizedBox(height: 16),
          Text(
            'Not Eligible Yet',
            textAlign: TextAlign.center,
            style: AppTextStyles.heading2,
          ),
          SizedBox(height: 8),
          Text(
            'Complete all the requirements above to unlock KYC verification.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.access_time, color: AppColors.primary, size: 64),
          const SizedBox(height: 16),
          const Text(
            'We are checking your documents',
            textAlign: TextAlign.center,
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 8),
          const Text(
            'Please wait while our team reviews your submission. You will be notified once the process is complete.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          if (_submission != null) ...[
            const SizedBox(height: 16),
            Text(
              'Submitted: ${_formatDate(_submission!['submittedAt'])}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApprovedView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.celebration, color: AppColors.success, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Congratulations!',
            textAlign: TextAlign.center,
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your KYC verification is complete. You now have access to all features including withdrawals.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          if (_submission != null && _submission!['reviewedAt'] != null) ...[
            const SizedBox(height: 16),
            Text(
              'Approved: ${_formatDate(_submission!['reviewedAt'])}',
              style: const TextStyle(color: AppColors.success, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildKycForm({bool isResubmit = false}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isResubmit) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.refresh, color: AppColors.warning),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Resubmitting KYC - Please correct the issues mentioned above',
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Text('Personal Information', style: AppTextStyles.heading3),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _fullNameController,
            label: 'Full Legal Name',
            icon: Icons.person,
          ),
          const SizedBox(height: 16),
          _buildDateField(),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _addressController,
            label: 'Address',
            icon: Icons.home,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _cityController,
                  label: 'City',
                  icon: Icons.location_city,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _countryController,
                  label: 'Country',
                  icon: Icons.flag,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _postalCodeController,
            label: 'Postal Code (Optional)',
            icon: Icons.pin_drop,
            required: false,
          ),
          const SizedBox(height: 24),
          const Text('Document Information', style: AppTextStyles.heading3),
          const SizedBox(height: 16),
          _buildDocumentTypeDropdown(),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _documentNumberController,
            label: 'ID / Passport Number',
            icon: Icons.badge,
          ),
          const SizedBox(height: 24),
          const Text('Document Upload', style: AppTextStyles.heading3),
          const SizedBox(height: 8),
          const Text(
            'Please upload clear photos of your ID and a selfie.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _buildUploadButton('ID Front Side *', 'front', _idFrontImage),
          const SizedBox(height: 16),
          _buildUploadButton('ID Back Side (Optional)', 'back', _idBackImage),
          const SizedBox(height: 16),
          _buildUploadButton('Selfie with ID *', 'selfie', _selfieImage),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _isLoading ? null : (isResubmit ? _resubmitKyc : _submitKyc),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[700],
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      isResubmit
                          ? 'Resubmit Verification'
                          : 'Submit Verification',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      validator: required
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: AppColors.cardLight,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDate == null
                    ? 'Date of Birth *'
                    : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                style: TextStyle(
                  color: _selectedDate == null ? Colors.grey : Colors.white,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.description, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDocumentType,
                dropdownColor: AppColors.cardDark,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'passport', child: Text('Passport')),
                  DropdownMenuItem(
                      value: 'driver_license',
                      child: Text('Driver\'s License')),
                  DropdownMenuItem(
                      value: 'national_id', child: Text('National ID')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDocumentType = value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton(String title, String type, File? file) {
    return InkWell(
      onTap: () => _pickImage(type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null
                ? AppColors.success
                : Colors.grey.withValues(alpha: 0.3),
            width: file != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: file != null
                    ? AppColors.success.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: file != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(file, fit: BoxFit.cover),
                    )
                  : Icon(Icons.cloud_upload_outlined,
                      color: file != null ? AppColors.success : Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    file != null ? 'File selected' : 'Tap to upload',
                    style: TextStyle(
                      color: file != null ? AppColors.success : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (file != null)
              const Icon(Icons.check_circle, color: AppColors.success),
          ],
        ),
      ),
    );
  }
}
