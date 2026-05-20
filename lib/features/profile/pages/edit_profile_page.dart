import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/sportal_api_exception.dart';
import '../../../ui/sportal_colors.dart';
import '../../../ui/sportal_text_styles.dart';
import '../../../ui/widgets/sportal_background.dart';
import '../../../ui/widgets/sportal_avatar.dart';
import '../../../ui/widgets/sportal_primary_button.dart';
import '../../../ui/widgets/sportal_section_card.dart';
import '../../auth/providers/auth_session_provider.dart';
import '../../auth/services/auth_api_client.dart';

/// Edit-profile screen.
///
/// Backend currently only exposes `GET /users/me` (see API_ENDPOINTS.md).
/// There is no PATCH/PUT endpoint for user profile fields, so saving simply
/// updates local-only state and shows a confirmation. When the API ships,
/// wire `_save()` to the appropriate endpoint.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  bool _saving = false;
  File? _newAvatarFile;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authSessionProvider);
    final username = auth.user.username?.trim();
    _nameController = TextEditingController(
      text: (username != null && username.isNotEmpty)
          ? username
          : auth.user.email.split('@').first,
    );
    _phoneController = TextEditingController();
    _emailController = TextEditingController(text: auth.user.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final l10n = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: SportalColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                ),
                title: Text(
                  l10n.t('editProfilePickCamera'),
                  style: SportalTextStyles.b1,
                ),
                onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.white,
                ),
                title: Text(
                  l10n.t('editProfilePickGallery'),
                  style: SportalTextStyles.b1,
                ),
                onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _newAvatarFile = File(picked.path);
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    String? uploadError;
    try {
      try {
        final session = ref.read(authSessionProvider);
        final authApi = ref.read(authApiClientProvider);
        String? newAvatarUrl;
        if (_newAvatarFile != null) {
          newAvatarUrl = await authApi.uploadAvatar(
            accessToken: session.accessToken,
            file: _newAvatarFile!,
          );
        }
        final username = _nameController.text.trim();
        final phone = _phoneController.text.trim();
        await authApi.updateProfile(
          accessToken: session.accessToken,
          avatar: newAvatarUrl,
          username: username.isEmpty ? null : username,
          phone: phone.isEmpty ? null : phone,
        );
        // Always fetch the canonical user from the server after updating so
        // the avatar URL is the authoritative value stored by the backend
        // (the PUT response may omit the avatar field on some server versions).
        final fresh = await authApi.fetchMe(accessToken: session.accessToken);
        ref.read(authSessionProvider.notifier).setUser(fresh);
      } on SportalApiException catch (e) {
        uploadError = e.statusCode == 403
            ? l10n.t('editProfileAvatarForbidden')
            : l10n.t('editProfileAvatarFailed');
      } catch (_) {
        uploadError = l10n.t('editProfileAvatarFailed');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(uploadError ?? l10n.t('editProfileSaved'))),
    );
    if (uploadError == null) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = ref.watch(authSessionProvider).user;
    return Scaffold(
      body: SportalBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              SportalPageHeader(
                title: l10n.t('profileInfo'),
                subtitle: l10n.t('editProfileSubtitle'),
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 22),
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _newAvatarFile == null
                              ? LinearGradient(
                                  colors: [
                                    SportalColors.primaryBlue,
                                    SportalColors.primaryBlue.withValues(
                                      alpha: 0.6,
                                    ),
                                  ],
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: SportalColors.primaryBlue.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _newAvatarFile != null
                            ? ClipOval(
                                child: Image.file(
                                  _newAvatarFile!,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : (user.avatar != null && user.avatar!.isNotEmpty
                                  ? ClipOval(
                                      child: SportalAvatar(
                                        name: user.email,
                                        avatar: user.avatar,
                                        size: 96,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      size: 50,
                                      color: Colors.white,
                                    )),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: SportalColors.deepBlue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: SportalColors.primaryBlue,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SportalSectionCard(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    _LabeledField(
                      label: l10n.t('editProfileFullName'),
                      controller: _nameController,
                      icon: Icons.badge_rounded,
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: l10n.t('editProfilePhone'),
                      controller: _phoneController,
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      hint: '+993 ...',
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: l10n.t('emailHint'),
                      controller: _emailController,
                      icon: Icons.mail_rounded,
                      keyboardType: TextInputType.emailAddress,
                      enabled: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SportalPrimaryButton(
                label: _saving
                    ? l10n.t('commonLoading')
                    : l10n.t('editProfileSave'),
                enabled: !_saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.icon,
    this.hint,
    this.enabled = true,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hint;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SportalTextStyles.t1.copyWith(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: SportalColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: SportalColors.primaryBlue),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: keyboardType,
                  style: SportalTextStyles.b1.copyWith(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: SportalTextStyles.b2.copyWith(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
