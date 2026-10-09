import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_config.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/photographer_categories.dart';
import '../../utils/validators.dart';
import '../../widgets/avatar_crop_screen.dart';
import '../../widgets/category_selector_sheet.dart';
import '../../widgets/location_search_field.dart';
import '../../widgets/pin_particle_field.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_card.dart';
import '../../widgets/studio_text_field.dart';
import '../../widgets/change_password_sheet.dart';
import '../legal/legal_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.initialEditing = false});

  final bool initialEditing;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late bool _editing;
  bool _isUploadingImage = false;
  bool _isUploadingQr = false;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _studioName;
  late final TextEditingController _ownerName;
  late final TextEditingController _username;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _about;
  late final TextEditingController _instagram;
  late final TextEditingController _youtube;
  late final TextEditingController _website;
  late final TextEditingController _specialties;
  late final TextEditingController _locationSearch;
  List<String> _selectedCategories = [];
  double? _studioLatitude;
  double? _studioLongitude;

  Timer? _usernameDebounce;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameErrorText;

  @override
  void initState() {
    super.initState();
    _editing = widget.initialEditing;
    final user = context.read<AuthProvider>().user;
    _studioName = TextEditingController(text: user?.studioName ?? '');
    _ownerName = TextEditingController(text: user?.ownerName ?? '');
    _username = TextEditingController(text: user?.username ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _city = TextEditingController(text: user?.city ?? '');
    _address = TextEditingController(text: user?.address ?? '');
    _about = TextEditingController(text: user?.about ?? '');
    _instagram = TextEditingController(text: user?.instagram ?? '');
    _youtube = TextEditingController(text: user?.youtube ?? '');
    _website = TextEditingController(text: user?.website ?? '');
    _specialties = TextEditingController(text: user?.specialties ?? '');
    _locationSearch = TextEditingController(
      text: user?.address.isNotEmpty == true
          ? user!.address
          : (user?.city.isNotEmpty == true ? user!.city : ''),
    );
    _selectedCategories = List<String>.from(user?.categories ?? []);
    _studioLatitude = user?.latitude;
    _studioLongitude = user?.longitude;
  }

  @override
  void dispose() {
    _studioName.dispose();
    _ownerName.dispose();
    _username.dispose();
    _phone.dispose();
    _email.dispose();
    _city.dispose();
    _address.dispose();
    _about.dispose();
    _instagram.dispose();
    _youtube.dispose();
    _website.dispose();
    _specialties.dispose();
    _locationSearch.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  void _fillFrom(User? user) {
    if (user == null) return;
    _studioName.text = user.studioName;
    _ownerName.text = user.ownerName;
    _username.text = user.username;
    _phone.text = user.phone;
    _email.text = user.email;
    _city.text = user.city;
    _address.text = user.address;
    _about.text = user.about;
    _instagram.text = user.instagram;
    _youtube.text = user.youtube;
    _website.text = user.website;
    _specialties.text = user.specialties;
    _locationSearch.text = user.address.isNotEmpty
        ? user.address
        : (user.city.isNotEmpty ? user.city : '');
    _selectedCategories = List<String>.from(user.categories);
    _studioLatitude = user.latitude;
    _studioLongitude = user.longitude;
    _isUsernameAvailable = null;
    _usernameErrorText = null;
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final trimmed = value.trim();
    final currentUser = context.read<AuthProvider>().user;

    if (trimmed.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameErrorText = 'Username cannot be empty';
      });
      return;
    }

    if (trimmed.toLowerCase() == (currentUser?.username ?? '').toLowerCase()) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = true;
        _usernameErrorText = null;
      });
      return;
    }

    if (!RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch(trimmed)) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameErrorText = '3-24 chars (letters, numbers, underscore)';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _isUsernameAvailable = null;
      _usernameErrorText = null;
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final available = await context.read<AuthProvider>().checkUsername(trimmed);
        if (!mounted) return;
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = available;
          _usernameErrorText = available ? null : 'Username is already taken';
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = null;
          _usernameErrorText = null;
        });
      }
    });
  }

  Future<void> _showImageSourcePicker() async {
    final user = context.read<AuthProvider>().user;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Profile Photo',
                    style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                          color: sheetContext.textMain,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: sheetContext.accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.photo_library_outlined,
                        color: sheetContext.accentColor),
                  ),
                  title: Text('Choose from Gallery',
                      style: TextStyle(color: sheetContext.textMain)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickAndUpload(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: sheetContext.accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.camera_alt_outlined,
                        color: sheetContext.accentColor),
                  ),
                  title: Text('Take a Photo',
                      style: TextStyle(color: sheetContext.textMain)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickAndUpload(ImageSource.camera);
                  },
                ),
                if (user?.logoUrl.isNotEmpty == true)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                    title: const Text('Remove Photo',
                        style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _removeProfilePhoto();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final original = await picked.readAsBytes();
      if (!mounted) return;
      final cropped = await AvatarCropScreen.open(
        context,
        bytes: original,
        filename: picked.name,
      );
      if (cropped == null || !mounted) return;

      setState(() => _isUploadingImage = true);

      final auth = context.read<AuthProvider>();
      final success = await auth.uploadLogo(cropped.bytes, cropped.filename);

      if (!mounted) return;
      setState(() => _isUploadingImage = false);

      if (success) {
        AppSnackBar.success(context, 'Profile image updated successfully.');
      } else {
        AppSnackBar.error(
            context, auth.errorMessage ?? 'Could not upload profile image.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        AppSnackBar.error(context, 'Failed to pick or upload image: $e');
      }
    }
  }

  static const _photoHeroTag = 'profile-photo';

  void _viewProfilePhoto(String logoUrl) {
    final resolved = ApiConfig.resolveMedia(logoUrl);
    final ImageProvider image = resolved.startsWith('data:')
        ? MemoryImage(base64Decode(resolved.split(',').last))
        : NetworkImage(resolved);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        barrierDismissible: true,
        pageBuilder: (routeContext, _, _) => Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.of(routeContext).pop(),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: Hero(
                          tag: _photoHeroTag,
                          child: Image(
                            image: image,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Text(
                              'Could not load photo.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(routeContext).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _removeProfilePhoto() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile({'logoUrl': ''});
    if (!mounted) return;
    if (success) {
      AppSnackBar.success(context, 'Profile photo removed.');
    } else {
      AppSnackBar.error(context, auth.errorMessage ?? 'Could not remove photo.');
    }
  }

  Future<void> _save() async {
    if (_isCheckingUsername) {
      AppSnackBar.error(context, 'Checking username availability, please wait...');
      return;
    }
    if (_isUsernameAvailable == false) {
      AppSnackBar.error(context, _usernameErrorText ?? 'Please choose an available username.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      AppSnackBar.error(context, 'Please fix the highlighted fields.');
      return;
    }
    final auth = context.read<AuthProvider>();
    final payload = <String, dynamic>{
      'studioName': _studioName.text.trim(),
      'ownerName': _ownerName.text.trim(),
      'username': _username.text.trim(),
      'phone': _phone.text.trim(),
      'city': _city.text.trim(),
      'address': _address.text.trim(),
      'about': _about.text.trim(),
      'instagram': _instagram.text.trim(),
      'youtube': _youtube.text.trim(),
      'website': _website.text.trim(),
      'specialties': _specialties.text.trim(),
      'categories': _selectedCategories,
    };
    if (_studioLatitude != null) payload['latitude'] = _studioLatitude;
    if (_studioLongitude != null) payload['longitude'] = _studioLongitude;
    final success = await auth.updateProfile(payload);
    if (!mounted) return;
    if (success) {
      setState(() => _editing = false);
      AppSnackBar.success(context, 'Profile saved.');
    } else {
      AppSnackBar.error(context, auth.errorMessage ?? 'Could not save profile.');
    }
  }

  void _showChangeEmailSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _ChangeEmailSheet(),
    );
  }

  Future<void> _openChangePasswordSheet() async {
    final success = await ChangePasswordSheet.show(context);
    if (success == true && mounted) {
      AppSnackBar.success(context, 'Password updated successfully.');
    }
  }

  void _showDeleteAccountSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _DeleteAccountSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isBusy = auth.isLoading || _isUploadingImage;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Studio Profile',
          style: TextStyle(
            color: context.textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: context.accentColor,
                backgroundColor: context.accentColor.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              onPressed: isBusy
                  ? null
                  : () {
                      if (_editing) {
                        _fillFrom(user);
                        setState(() => _editing = false);
                      } else {
                        setState(() => _editing = true);
                      }
                    },
              icon: Icon(_editing ? Icons.close_rounded : Icons.edit_outlined, size: 16),
              label: Text(_editing ? 'Cancel' : 'Edit'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // Profile Header Card
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.accentColor.withValues(alpha: 0.35),
                          width: 2.5,
                        ),
                      ),
                      child: GestureDetector(
                        onTap: isBusy
                            ? null
                            : () => (user?.logoUrl.isNotEmpty ?? false)
                                ? _viewProfilePhoto(user!.logoUrl)
                                : _showImageSourcePicker(),
                        child: ProfileAvatar(
                          logoUrl: user?.logoUrl,
                          size: 104,
                          heroTag: _photoHeroTag,
                        ),
                      ),
                    ),
                    if (_isUploadingImage)
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.ink.withValues(alpha: 0.7),
                        ),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.sky),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Semantics(
                        button: true,
                        label: 'Upload studio profile image',
                        child: Material(
                          color: context.accentColor,
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: isBusy ? null : _showImageSourcePicker,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 17,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                user?.displayStudioName ?? 'Your studio',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.textMain,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 4,
                children: [
                  Icon(Icons.person_outline_rounded, size: 15, color: context.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    user?.ownerName.isNotEmpty == true
                        ? user!.ownerName
                        : (user?.displayOwner ?? ''),
                    style: TextStyle(
                      color: context.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user != null && user.username.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.textMuted.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              if (_editing) ...[
                _buildForm(isBusy),
              ] else ...[
                // Section 1: Studio Details
                _buildSectionHeader(context, 'Studio Details', Icons.apartment_rounded),
                const SizedBox(height: 8),
                _buildStudioDetailsCard(user),

                const SizedBox(height: 18),
                // Section 2: Online & Social
                _buildSectionHeader(context, 'Social & Portfolio', Icons.share_rounded),
                const SizedBox(height: 8),
                _buildSocialCard(user),

                const SizedBox(height: 18),
                _buildSectionHeader(context, 'Payments', Icons.qr_code_2_rounded),
                const SizedBox(height: 8),
                _buildPaymentQrCard(user),

                const SizedBox(height: 18),
                // Section 3: Account Settings
                _buildSectionHeader(context, 'Account Settings', Icons.settings_outlined),
                const SizedBox(height: 8),
                _buildSettingsCard(context),

                const SizedBox(height: 18),
                _buildSectionHeader(context, 'Legal', Icons.policy_outlined),
                const SizedBox(height: 8),
                _buildLegalCard(context),

                const SizedBox(height: 24),
                StudioButton(
                  label: 'Sign out',
                  isSecondary: true,
                  icon: Icons.logout_rounded,
                  onPressed: isBusy
                      ? null
                      : () {
                          final auth = context.read<AuthProvider>();
                          final rootContext =
                              Navigator.of(context, rootNavigator: true).context;
                          Navigator.of(context).pop();
                          auth.logout();
                          AppSnackBar.success(rootContext, 'Signed out successfully.');
                        },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, {bool isDanger = false}) {
    final color = isDanger ? const Color(0xFFFF5252) : context.accentColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: isDanger ? const Color(0xFFFF5252) : context.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioDetailsCard(User? user) {
    return StudioCard(
      child: Column(
        children: [
          _DetailRow(icon: Icons.apartment_outlined, label: 'Studio Name', value: user?.displayStudioName ?? '—'),
          _DetailRow(icon: Icons.person_outline_rounded, label: 'Owner', value: user?.ownerName.isNotEmpty == true ? user!.ownerName : (user?.displayOwner ?? '—')),
          _DetailRow(icon: Icons.alternate_email_rounded, label: 'Username', value: user?.username.isNotEmpty == true ? '@${user!.username}' : '—'),
          _DetailRow(icon: Icons.phone_outlined, label: 'Phone', value: user?.phone ?? '—'),
          _DetailRow(icon: Icons.mail_outline_rounded, label: 'Email', value: _orDash(user?.email)),
          _DetailRow(icon: Icons.location_city_outlined, label: 'City', value: _orDash(user?.city)),
          _DetailRow(icon: Icons.place_outlined, label: 'Address', value: _orDash(user?.address), last: true),
        ],
      ),
    );
  }

  Widget _buildSocialCard(User? user) {
    final cats = user?.categories ?? [];
    return StudioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photographer Categories chips
          if (cats.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 16, color: context.accentColor),
                      const SizedBox(width: 8),
                      Text(
                        'Photographer Roles',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.textMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: cats.map((c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.accentColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        c,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.accentColor,
                        ),
                      ),
                    )).toList(),
                  ),
                  Divider(height: 20, color: context.cardBorder),
                ],
              ),
            ),
          ],
          _DetailRow(icon: Icons.auto_awesome_outlined, label: 'Specialties', value: _orDash(user?.specialties)),
          _DetailRow(icon: Icons.camera_alt_outlined, label: 'Instagram', value: _orDash(user?.instagram)),
          _DetailRow(icon: Icons.ondemand_video_rounded, label: 'YouTube', value: _orDash(user?.youtube)),
          _DetailRow(icon: Icons.link_rounded, label: 'Website', value: _orDash(user?.website)),
          _DetailRow(icon: Icons.info_outline_rounded, label: 'About', value: _orDash(user?.about), last: true),
        ],
      ),
    );
  }

  Future<void> _uploadPaymentQr() async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 95,
      );
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'Could not open the gallery.');
      return;
    }
    if (picked == null || !mounted) return;
    setState(() => _isUploadingQr = true);
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.uploadPaymentQr(bytes, picked.name);
    if (!mounted) return;
    setState(() => _isUploadingQr = false);
    if (ok) {
      AppSnackBar.success(context, 'Payment QR saved. It will appear on your invoices.');
    } else {
      AppSnackBar.error(context, auth.errorMessage ?? 'Could not upload payment QR.');
    }
  }

  Future<void> _removePaymentQr() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgContext) => AlertDialog(
        backgroundColor: dlgContext.cardBg,
        title: Text(
          'Remove payment QR?',
          style: TextStyle(color: dlgContext.textMain, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Invoices will show your UPI ID instead of the QR.',
          style: TextStyle(color: dlgContext.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: dlgContext.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dlgContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile({'paymentQrUrl': ''});
    if (!mounted) return;
    if (ok) {
      AppSnackBar.success(context, 'Payment QR removed.');
    } else {
      AppSnackBar.error(context, auth.errorMessage ?? 'Could not remove payment QR.');
    }
  }

  Widget _buildPaymentQrCard(User? user) {
    final qrUrl = user?.paymentQrUrl.trim() ?? '';
    final hasQr = qrUrl.isNotEmpty;
    final accent = context.accentColor;
    const danger = Color(0xFFEF4444);

    return StudioCard(
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: hasQr ? Colors.white : context.innerBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.cardBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: _isUploadingQr
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
                    ),
                  )
                : hasQr
                    ? Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.network(
                          ApiConfig.resolveMedia(qrUrl),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              Icon(Icons.broken_image_outlined, color: context.textMuted),
                        ),
                      )
                    : Icon(Icons.qr_code_2_rounded, size: 40, color: context.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment QR',
                  style: TextStyle(
                    color: context.textMain,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasQr
                      ? 'Shown as "Scan to Pay" on your invoices.'
                      : 'Upload your UPI QR to show it on invoices. Without it, your UPI ID is shown.',
                  style: TextStyle(color: context.textMuted, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isUploadingQr ? null : _uploadPaymentQr,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent.withValues(alpha: 0.5)),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(hasQr ? Icons.edit_rounded : Icons.upload_rounded, size: 16),
                      label: Text(hasQr ? 'Replace' : 'Upload QR'),
                    ),
                    if (hasQr)
                      OutlinedButton.icon(
                        onPressed: _isUploadingQr ? null : _removePaymentQr,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: danger,
                          side: BorderSide(color: danger.withValues(alpha: 0.5)),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Remove'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final accent = context.accentColor;

    return StudioCard(
      child: Container(
        decoration: BoxDecoration(
          color: context.innerBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          children: [
            // Option 1: Change Password
            InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              onTap: _openChangePasswordSheet,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.lock_reset_rounded, color: accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Change Password',
                            style: TextStyle(
                              color: textMain,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Update current login password',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: textMuted),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: context.cardBorder),
            // Option 2: Change Email
            InkWell(
              onTap: _showChangeEmailSheet,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.mark_email_read_outlined, color: accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Change Email',
                            style: TextStyle(
                              color: textMain,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Verify and update your email address',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: textMuted),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: context.cardBorder),
            // Option 3: Delete Account
            InkWell(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              onTap: _showDeleteAccountSheet,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: textMuted.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.delete_outline_rounded, color: textMain, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete Account',
                            style: TextStyle(
                              color: textMain,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Permanently remove account and studio data',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: textMuted),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalCard(BuildContext context) {
    return StudioCard(
      child: Container(
        decoration: BoxDecoration(
          color: context.innerBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          children: [
            _buildLegalTile(
              context,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'How we handle your studio and client data',
              document: LegalDocument.privacy,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            Divider(height: 1, color: context.cardBorder),
            _buildLegalTile(
              context,
              icon: Icons.gavel_rounded,
              title: 'Terms & Conditions',
              subtitle: 'Rules for using the app',
              document: LegalDocument.terms,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required LegalDocument document,
    required BorderRadius borderRadius,
  }) {
    final accent = context.accentColor;
    final textMuted = context.textMuted;
    return InkWell(
      borderRadius: borderRadius,
      onTap: () => LegalScreen.open(context, document),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textMain,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          StudioTextField(
            label: 'Photography studio name',
            hint: 'Lumen Studio',
            controller: _studioName,
            prefixIcon: Icons.apartment_outlined,
            validator: (value) =>
                (value == null || value.trim().isEmpty)
                    ? 'Enter your studio name'
                    : null,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Owner name',
            hint: 'Your name',
            controller: _ownerName,
            prefixIcon: Icons.person_outline_rounded,
            helperText: 'Your personal name (display name)',
            validator: (value) =>
                (value == null || value.trim().isEmpty)
                    ? 'Enter the owner name'
                    : null,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Username',
            hint: 'unique_handle',
            controller: _username,
            prefixIcon: Icons.alternate_email_rounded,
            onChanged: _onUsernameChanged,
            suffixIcon: _isCheckingUsername
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : _isUsernameAvailable == true
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 20)
                    : _isUsernameAvailable == false
                        ? const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 20)
                        : null,
            helperText: _usernameErrorText ?? 'Unique handle for your studio profile',
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) return 'Enter a username';
              if (!RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch(trimmed)) {
                return '3-24 characters (letters, numbers, underscore only)';
              }
              if (_isUsernameAvailable == false) {
                return _usernameErrorText ?? 'Username is already taken';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Phone number',
            hint: '10-digit mobile number',
            controller: _phone,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: Validators.phone,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Email (Read-only)',
            hint: 'studio@email.com',
            controller: _email,
            readOnly: true,
            enabled: false,
            prefixIcon: Icons.mail_outline_rounded,
            suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
            helperText: 'To change your email, use Change Email in Account Settings.',
          ),
          const SizedBox(height: 14),
          // Studio Location — geocodes venue to lat/lng automatically
          LocationSearchField(
            label: 'Studio Location',
            hint: 'Search studio address or venue…',
            controller: _locationSearch,
            initialLatitude: _studioLatitude,
            initialLongitude: _studioLongitude,
            onLocationSelected: (result) {
              setState(() {
                _studioLatitude = result.latitude;
                _studioLongitude = result.longitude;
                // Auto-fill city if empty
                if (_city.text.trim().isEmpty && result.city != null) {
                  _city.text = result.city!;
                }
                // Auto-fill address if empty
                if (_address.text.trim().isEmpty) {
                  _address.text = result.displayName;
                }
              });
            },
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'City',
            hint: 'Where the studio is based',
            controller: _city,
            prefixIcon: Icons.location_city_outlined,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Enter your city'
                : null,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Address',
            hint: 'Street, floor, landmark',
            controller: _address,
            prefixIcon: Icons.place_outlined,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Specialties',
            hint: 'Weddings, portraits, commercial...',
            controller: _specialties,
            prefixIcon: Icons.auto_awesome_outlined,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Enter what you specialise in'
                : null,
          ),
          const SizedBox(height: 14),
          // Photographer Roles & Categories
          _buildCategorySelector(),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Instagram (optional)',
            hint: '@yourstudio',
            controller: _instagram,
            keyboardType: TextInputType.url,
            prefixIcon: Icons.camera_alt_outlined,
            validator: Validators.instagram,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'YouTube (optional)',
            hint: 'https://youtube.com/@yourstudio',
            controller: _youtube,
            keyboardType: TextInputType.url,
            prefixIcon: Icons.ondemand_video_rounded,
            validator: Validators.youtube,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Website (optional)',
            hint: 'https://yourstudio.com',
            controller: _website,
            keyboardType: TextInputType.url,
            prefixIcon: Icons.link_rounded,
            validator: Validators.website,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'About',
            hint: 'Tell clients what makes your studio special',
            controller: _about,
            maxLines: 4,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Write a short description'
                : null,
          ),
          const SizedBox(height: 20),
          StudioButton(
            label: 'Save profile',
            isLoading: isLoading,
            onPressed: isLoading ? null : _save,
          ),
        ],
      ),
    );
  }

  String _orDash(String? value) {
    if (value == null || value.trim().isEmpty) return '—';
    return value.trim();
  }

  Widget _buildCategorySelector() {
    final isDark = context.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera_outlined, size: 16, color: context.accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Photographer Roles & Categories',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textMain,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final updated = await CategorySelectorSheet.show(
                  context,
                  initial: _selectedCategories,
                );
                if (updated != null && mounted) {
                  setState(() => _selectedCategories = updated);
                }
              },
              icon: Icon(
                _selectedCategories.isEmpty ? Icons.add_rounded : Icons.edit_rounded,
                size: 15,
                color: context.accentColor,
              ),
              label: Text(
                _selectedCategories.isEmpty ? 'Select Roles' : 'Edit Roles',
                style: TextStyle(color: context.accentColor, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedCategories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.cardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: context.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select your roles so other photographers can find and collaborate with you.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: context.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedCategories.map((cat) {
              final isOperator = PhotographerCategories.isOperatorRole(cat);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOperator
                      ? AppColors.sky.withValues(alpha: isDark ? 0.18 : 0.1)
                      : context.accentColor.withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOperator
                        ? AppColors.sky.withValues(alpha: 0.4)
                        : context.accentColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOperator ? Icons.video_camera_back_outlined : Icons.camera_alt_outlined,
                      size: 12,
                      color: isOperator ? AppColors.sky : context.accentColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      cat,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOperator ? AppColors.sky : context.accentColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategories.remove(cat));
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: isOperator ? AppColors.sky : context.accentColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.icon,
    this.last = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: context.accentColor.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted(context),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMain(context),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DeleteAccountStep { requestOtp, verifyOtp, confirmPassword }

/// Account deletion verification sheet:
/// 1. Verifies email OTP code using PinParticleField (just like signup OTP)
/// 2. Then verifies account password to confirm permanent deletion
class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  static const _dangerColor = Color(0xFFFF5252);

  _DeleteAccountStep _step = _DeleteAccountStep.requestOtp;

  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _deleting = false;

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _errorMessage;
  String? _deleteToken;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _sendingOtp = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.sendDeleteAccountOtp();
      if (!mounted) return;

      final cd = (res['cooldownSeconds'] as num?)?.toInt() ?? 60;
      setState(() {
        _sendingOtp = false;
        _step = _DeleteAccountStep.verifyOtp;
      });
      _startCooldown(cd);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _otpFocusNodes[0].requestFocus();
      });

      AppSnackBar.success(
        context,
        'Verification email sent. Check your inbox and spam folder.',
        duration: const Duration(seconds: 4),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingOtp = false;
        _errorMessage = e.message;
      });
      AppSnackBar.error(context, e.message);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _sendingOtp = false;
        _errorMessage = message;
      });
      AppSnackBar.error(context, message);
    }
  }

  Future<void> _handleVerifyOtp() async {
    FocusScope.of(context).unfocus();
    final otp = _otpControllers.map((c) => c.text.trim()).join();

    if (otp.length != 6) {
      const message = 'Please enter the complete 6-digit verification code.';
      setState(() => _errorMessage = message);
      AppSnackBar.error(context, message);
      return;
    }

    setState(() {
      _verifyingOtp = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final token = await auth.verifyDeleteAccountOtp(otp);
      if (!mounted) return;

      setState(() {
        _verifyingOtp = false;
        _deleteToken = token;
        _step = _DeleteAccountStep.confirmPassword;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _passwordFocusNode.requestFocus();
      });

      AppSnackBar.success(
        context,
        'Code verified. Please confirm your password to finalize deletion.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifyingOtp = false;
        _errorMessage = e.message;
      });
      AppSnackBar.error(context, e.message);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _verifyingOtp = false;
        _errorMessage = message;
      });
      AppSnackBar.error(context, message);
    }
  }

  Future<void> _confirmDelete() async {
    final auth = context.read<AuthProvider>();
    final needsPassword = !(auth.user?.needsPasswordSetup ?? false);
    final password = _passwordController.text;

    if (needsPassword && password.isEmpty) {
      const message = 'Please enter your account password.';
      setState(() => _errorMessage = message);
      AppSnackBar.error(context, message);
      return;
    }

    setState(() {
      _deleting = true;
      _errorMessage = null;
    });

    final success = await auth.deleteAccount(
      deleteToken: _deleteToken,
      password: password,
    );

    if (!mounted) return;
    setState(() => _deleting = false);

    if (success) {
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      Navigator.of(context).pop(); // Close bottom sheet
      Navigator.of(context).pop(); // Exit profile screen
      if (rootContext.mounted) {
        AppSnackBar.success(
          rootContext,
          'Your account and associated data have been permanently deleted.',
        );
      }
    } else {
      final message = auth.errorMessage ?? 'Unable to delete account.';
      setState(() => _errorMessage = message);
      AppSnackBar.error(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: _dangerColor.withValues(alpha: 0.3), width: 1.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_step == _DeleteAccountStep.requestOtp)
              _buildRequestStep(context)
            else if (_step == _DeleteAccountStep.verifyOtp)
              _buildVerifyOtpStep(context)
            else
              _buildConfirmPasswordStep(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestStep(BuildContext context) {
    final user = context.read<AuthProvider>().user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _dangerColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: _dangerColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Permanently Delete Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _dangerColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'This action cannot be undone.',
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Warning Notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _dangerColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _dangerColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: _dangerColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All your events, clients, quotes, invoices, and expenses will be permanently wiped. To protect your data, a verification code will be sent to your email.',
                  style: TextStyle(fontSize: 12, color: context.textMain, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
          const SizedBox(height: 14),
        ],

        // Registered Email Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.innerBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.cardBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.mark_email_read_outlined, size: 20, color: context.accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registered Email',
                      style: TextStyle(fontSize: 11, color: context.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? 'Unknown Email',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textMain,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Send OTP Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _dangerColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: _sendingOtp ? null : _sendOtp,
          child: _sendingOtp
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Send Verification Code',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                setState(() => _step = _DeleteAccountStep.verifyOtp);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _otpFocusNodes[0].requestFocus();
                });
              },
              child: Text(
                'Already have a code?',
                style: TextStyle(color: context.accentColor, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: context.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerifyOtpStep(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final isDark = AppColors.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.mark_email_read_outlined, color: context.accentColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Verify Email Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.textMain,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Step 1 of 2',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: context.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Code sent to ${user?.email ?? 'your email'}',
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
          const SizedBox(height: 14),
        ],

        Text(
          'Enter the 6-digit verification code from your inbox to confirm your identity.',
          style: TextStyle(fontSize: 12.5, color: context.textMuted, height: 1.35),
        ),
        const SizedBox(height: 16),

        // 6 PIN boxes with particle burst (matching signup OTP field)
        PinParticleField(
          controllers: _otpControllers,
          focusNodes: _otpFocusNodes,
          isDark: isDark,
          onChanged: () {
            if (_errorMessage != null) {
              setState(() => _errorMessage = null);
            }
          },
          onCompleted: (_) => _handleVerifyOtp(),
        ),
        const SizedBox(height: 16),

        // Resend Timer / Button
        Center(
          child: _cooldownSeconds > 0
              ? Text(
                  'Resend code in ${_cooldownSeconds}s',
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 12.5,
                  ),
                )
              : TextButton.icon(
                  onPressed: _sendingOtp ? null : _sendOtp,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text(
                    'Resend Code',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
        ),
        const SizedBox(height: 18),

        // Verify OTP Button
        StudioButton(
          label: 'Verify Code',
          isLoading: _verifyingOtp,
          onPressed: _verifyingOtp ? null : _handleVerifyOtp,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() => _step = _DeleteAccountStep.requestOtp),
              child: Text(
                'Back',
                style: TextStyle(color: context.textMuted, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: context.textMuted, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordStep(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final needsPassword = !(auth.user?.needsPasswordSetup ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _dangerColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_person_outlined, color: _dangerColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Confirm Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _dangerColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _dangerColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Step 2 of 2',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _dangerColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Verification code approved',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Warning Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _dangerColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _dangerColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: _dangerColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Final Step: Enter your account password to authorize permanent deletion. All data will be deleted immediately and cannot be recovered.',
                  style: TextStyle(fontSize: 12, color: context.textMain, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
          const SizedBox(height: 14),
        ],

        if (needsPassword) ...[
          Text(
            'ACCOUNT PASSWORD',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.accentColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: _obscurePassword,
            style: TextStyle(color: context.textMain, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter your account password',
              hintStyle: TextStyle(color: context.textMuted, fontSize: 13),
              prefixIcon: Icon(Icons.lock_outline_rounded, color: context.accentColor, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: context.textMuted,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: context.innerBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.accentColor, width: 1.5),
              ),
            ),
            onSubmitted: (_) => _confirmDelete(),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.cardBorder),
            ),
            child: Text(
              'Your account is connected via Google Sign-In. Tap below to confirm deletion.',
              style: TextStyle(fontSize: 13, color: context.textMuted),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Confirm Delete Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _dangerColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: _deleting ? null : _confirmDelete,
          child: _deleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Permanently Delete Account',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() => _step = _DeleteAccountStep.verifyOtp),
              child: Text(
                'Back to Code Verification',
                style: TextStyle(color: context.textMuted, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: context.textMuted, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeEmailSheet extends StatefulWidget {
  const _ChangeEmailSheet();

  @override
  State<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends State<_ChangeEmailSheet> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _sendingOtp = false;
  bool _otpSent = false;
  bool _verifying = false;
  int _cooldown = 0;
  Timer? _timer;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    final emailErr = Validators.email(email);
    if (emailErr != null) {
      setState(() => _errorMessage = emailErr);
      AppSnackBar.error(context, emailErr);
      return;
    }

    final currentUser = context.read<AuthProvider>().user;
    if (currentUser?.email != null && currentUser!.email.toLowerCase() == email) {
      const msg = 'This is already your registered email.';
      setState(() => _errorMessage = msg);
      AppSnackBar.error(context, msg);
      return;
    }

    setState(() {
      _sendingOtp = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      await auth.sendEmailChangeOtp(email);
      if (!mounted) return;

      setState(() {
        _sendingOtp = false;
        _otpSent = true;
      });
      _startCooldown();

      AppSnackBar.success(
        context,
        'Verification email sent. Check your inbox and spam folder.',
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _sendingOtp = false;
        _errorMessage = message;
      });
      AppSnackBar.error(context, message);
    }
  }

  Future<void> _verifyAndChange() async {
    final email = _emailController.text.trim().toLowerCase();
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      const msg = 'Please enter the 6-digit verification code.';
      setState(() => _errorMessage = msg);
      AppSnackBar.error(context, msg);
      return;
    }

    setState(() {
      _verifying = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyEmailChange(newEmail: email, otp: otp);

    if (!mounted) return;
    setState(() => _verifying = false);

    if (success) {
      Navigator.of(context).pop();
      AppSnackBar.success(context, 'Email updated to $email successfully!');
    } else {
      final message = auth.errorMessage ?? 'Unable to verify email code.';
      setState(() => _errorMessage = message);
      AppSnackBar.error(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final textMain = context.textMain;
    final textMuted = context.textMuted;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: accent.withValues(alpha: 0.3), width: 1.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.mark_email_read_outlined, color: accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change Email Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'A verification code will be sent to confirm.',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current Email Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: context.innerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, size: 16, color: textMuted),
                  const SizedBox(width: 8),
                  Text(
                    'Current: ',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                  Expanded(
                    child: Text(
                      context.read<AuthProvider>().user?.email.isNotEmpty == true
                          ? context.read<AuthProvider>().user!.email
                          : 'None',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textMain,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Step 1: New Email Input
            Text(
              'New Email Address',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textMain,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              enabled: !_otpSent,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: textMain, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter new email address',
                hintStyle: TextStyle(color: textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 18, color: textMuted),
                suffixIcon: _otpSent
                    ? IconButton(
                        tooltip: 'Edit email',
                        icon: Icon(Icons.edit_outlined, size: 18, color: accent),
                        onPressed: () {
                          setState(() {
                            _otpSent = false;
                            _otpController.clear();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.innerBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (!_otpSent) ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _sendingOtp ? null : _sendOtp,
                child: _sendingOtp
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Send Verification Code',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
              ),
            ] else ...[
              // Step 2: OTP Verification
              Text(
                '6-Digit Verification Code',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  color: textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color: textMuted.withValues(alpha: 0.5),
                    fontSize: 18,
                    letterSpacing: 8,
                  ),
                  filled: true,
                  fillColor: context.innerBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Resend Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_cooldown > 0)
                    Text(
                      'Resend in ${_cooldown}s',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    )
                  else
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _sendingOtp ? null : _sendOtp,
                      child: Text(
                        'Resend code',
                        style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Confirm Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _verifying ? null : _verifyAndChange,
                child: _verifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Verify & Update Email',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
              ),
            ],

            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: textMuted, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
