import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_background.dart';
import '../../utils/validators.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/studio_button.dart';
import '../../widgets/studio_card.dart';
import '../../widgets/studio_text_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;
  bool _isUploadingImage = false;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _studioName;
  late final TextEditingController _ownerName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _about;
  late final TextEditingController _instagram;
  late final TextEditingController _website;
  late final TextEditingController _specialties;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _studioName = TextEditingController(text: user?.studioName ?? '');
    _ownerName = TextEditingController(text: user?.displayOwner ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _city = TextEditingController(text: user?.city ?? '');
    _address = TextEditingController(text: user?.address ?? '');
    _about = TextEditingController(text: user?.about ?? '');
    _instagram = TextEditingController(text: user?.instagram ?? '');
    _website = TextEditingController(text: user?.website ?? '');
    _specialties = TextEditingController(text: user?.specialties ?? '');
  }

  @override
  void dispose() {
    _studioName.dispose();
    _ownerName.dispose();
    _phone.dispose();
    _email.dispose();
    _city.dispose();
    _address.dispose();
    _about.dispose();
    _instagram.dispose();
    _website.dispose();
    _specialties.dispose();
    super.dispose();
  }

  void _fillFrom(User? user) {
    if (user == null) return;
    _studioName.text = user.studioName;
    _ownerName.text = user.displayOwner;
    _phone.text = user.phone;
    _email.text = user.email;
    _city.text = user.city;
    _address.text = user.address;
    _about.text = user.about;
    _instagram.text = user.instagram;
    _website.text = user.website;
    _specialties.text = user.specialties;
  }

  Future<void> _showImageSourcePicker() async {
    final user = context.read<AuthProvider>().user;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navy,
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
                      borderRadius: BorderRadius.circular(10),
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
                      borderRadius: BorderRadius.circular(10),
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
                if (user != null && user.logoUrl.isNotEmpty) ...[
                  const Divider(color: Color(0x18FFFFFF)),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A8A).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFFF7A8A)),
                    ),
                    title: const Text('Remove Photo',
                        style: TextStyle(color: Color(0xFFFF7A8A))),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _removeProfilePhoto();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _isUploadingImage = true);

      final auth = context.read<AuthProvider>();
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final base64Image = base64Encode(bytes);
      final ext = picked.name.toLowerCase();
      final mimeType = ext.endsWith('.png')
          ? 'image/png'
          : ext.endsWith('.webp')
              ? 'image/webp'
              : ext.endsWith('.gif')
                  ? 'image/gif'
                  : 'image/jpeg';
      final dataUri = 'data:$mimeType;base64,$base64Image';

      // Instantly update UI avatar visuals
      auth.setTemporaryLogoUrl(dataUri);

      final success = await auth.uploadLogo(bytes, picked.name);
      if (!mounted) return;

      setState(() => _isUploadingImage = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Profile image updated successfully.'
                : auth.errorMessage ?? 'Could not upload profile image.',
          ),
          backgroundColor: AppColors.navy,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick or upload image: $e'),
            backgroundColor: AppColors.navy,
          ),
        );
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile({'logoUrl': ''});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Profile photo removed.'
              : auth.errorMessage ?? 'Could not remove photo.',
        ),
        backgroundColor: AppColors.navy,
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile({
      'studioName': _studioName.text.trim(),
      'ownerName': _ownerName.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'city': _city.text.trim(),
      'address': _address.text.trim(),
      'about': _about.text.trim(),
      'instagram': _instagram.text.trim(),
      'website': _website.text.trim(),
      'specialties': _specialties.text.trim(),
    });
    if (!mounted) return;
    if (success) {
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved.'),
          backgroundColor: AppColors.navy,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Could not save profile.'),
          backgroundColor: AppColors.navy,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isBusy = auth.isLoading || _isUploadingImage;

    return AuthBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            TextButton(
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
              child: Text(_editing ? 'Cancel' : 'Edit'),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ProfileAvatar(logoUrl: user?.logoUrl, size: 112),
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
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.aqua),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Semantics(
                          button: true,
                          label: 'Upload studio profile image',
                          child: Material(
                            color: AppColors.aqua,
                            shape: const CircleBorder(),
                            elevation: 4,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: isBusy ? null : _showImageSourcePicker,
                              child: const Padding(
                                padding: EdgeInsets.all(9),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 18,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayStudioName ?? 'Your studio',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: context.textMain,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.displayOwner ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
                const SizedBox(height: 22),
                if (_editing) _buildForm(isBusy) else _buildDetails(user),
                const SizedBox(height: 20),
                _buildThemeSelector(context),
                const SizedBox(height: 24),
                StudioButton(
                  label: 'Sign out',
                  isSecondary: true,
                  icon: Icons.logout_rounded,
                  onPressed: isBusy
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          context.read<AuthProvider>().logout();
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(User? user) {
    return StudioCard(
      child: Column(
        children: [
          _DetailRow(label: 'Studio name', value: user?.displayStudioName ?? '—'),
          _DetailRow(label: 'Owner', value: user?.displayOwner ?? '—'),
          _DetailRow(label: 'Phone', value: user?.phone ?? '—'),
          _DetailRow(label: 'Email', value: _orDash(user?.email)),
          _DetailRow(label: 'City', value: _orDash(user?.city)),
          _DetailRow(label: 'Address', value: _orDash(user?.address)),
          _DetailRow(label: 'Specialties', value: _orDash(user?.specialties)),
          _DetailRow(label: 'Instagram', value: _orDash(user?.instagram)),
          _DetailRow(label: 'Website', value: _orDash(user?.website)),
          _DetailRow(label: 'About', value: _orDash(user?.about), last: true),
        ],
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
            validator: (value) =>
                (value == null || value.trim().isEmpty)
                    ? 'Enter the owner name'
                    : null,
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
            label: 'Email',
            hint: 'studio@email.com',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline_rounded,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'City',
            hint: 'Where the studio is based',
            controller: _city,
            prefixIcon: Icons.location_city_outlined,
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
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Instagram',
            hint: '@yourstudio',
            controller: _instagram,
            prefixIcon: Icons.camera_alt_outlined,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'Website',
            hint: 'https://yourstudio.com',
            controller: _website,
            prefixIcon: Icons.link_rounded,
          ),
          const SizedBox(height: 14),
          StudioTextField(
            label: 'About',
            hint: 'Tell clients what makes your studio special',
            controller: _about,
            maxLines: 4,
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

  Widget _buildThemeSelector(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentMode = themeProvider.themeMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'App Appearance',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textMuted(context),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
          ),
        ),
        StudioCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _ThemeOptionButton(
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark',
                  isSelected: currentMode == ThemeMode.dark,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemeOptionButton(
                  icon: Icons.light_mode_rounded,
                  label: 'Light',
                  isSelected: currentMode == ThemeMode.light,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemeOptionButton(
                  icon: Icons.hdr_auto_rounded,
                  label: 'System',
                  isSelected: currentMode == ThemeMode.system,
                  onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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

class _ThemeOptionButton extends StatelessWidget {
  const _ThemeOptionButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final activeBg = isDark
        ? AppColors.aqua.withValues(alpha: 0.22)
        : AppColors.lightPrimary.withValues(alpha: 0.15);
    final activeBorder = isDark ? AppColors.aqua : AppColors.lightPrimary;
    final activeText = isDark ? AppColors.aqua : AppColors.lightPrimary;

    return Material(
      color: isSelected ? activeBg : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeBorder : AppColors.cardBorder(context),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? activeText : AppColors.textMuted(context),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeText : AppColors.textMain(context),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
