import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/auth_service.dart';
import '../../services/device_security_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_page.dart';
import '../profile/profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _deviceId = 'Loading...';
  bool _isBiometricSupported = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final devId = await DeviceSecurityService.instance.getHardwareDeviceId();
    final bioAvail = await DeviceSecurityService.instance.isBiometricSupported();

    if (mounted) {
      setState(() {
        _deviceId = devId;
        _isBiometricSupported = bioAvail;
      });
    }
  }

  void _showChangePasswordModal() {
    AppTheme.triggerLightHaptic();
    final formKey = GlobalKey<FormState>();
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool isUpdating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.borderLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.royalNavy.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.lock, color: AppTheme.royalNavy, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Change Password',
                          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Current Password
                    TextFormField(
                      controller: currentPassController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon: const Icon(LucideIcons.key, size: 16, color: AppTheme.royalNavy),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? LucideIcons.eyeOff : LucideIcons.eye, size: 17, color: AppTheme.textSecondary),
                          onPressed: () => setModalState(() => obscureCurrent = !obscureCurrent),
                        ),
                        filled: true,
                        fillColor: AppTheme.bgLight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Please enter current password' : null,
                    ),
                    const SizedBox(height: 12),

                    // New Password
                    TextFormField(
                      controller: newPassController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(LucideIcons.lock, size: 16, color: AppTheme.royalNavy),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? LucideIcons.eyeOff : LucideIcons.eye, size: 17, color: AppTheme.textSecondary),
                          onPressed: () => setModalState(() => obscureNew = !obscureNew),
                        ),
                        filled: true,
                        fillColor: AppTheme.bgLight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Please enter new password';
                        if (v.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Confirm New Password
                    TextFormField(
                      controller: confirmPassController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: const Icon(LucideIcons.checkCheck, size: 16, color: AppTheme.royalNavy),
                        filled: true,
                        fillColor: AppTheme.bgLight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Please confirm new password';
                        if (v != newPassController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isUpdating
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isUpdating = true);

                                final res = await AuthService.instance.changePassword(
                                  currentPassword: currentPassController.text.trim(),
                                  newPassword: newPassController.text.trim(),
                                );

                                if (ctx.mounted) {
                                  setModalState(() => isUpdating = false);
                                  Navigator.pop(ctx);

                                  if (res['success'] == true) {
                                    AppTheme.triggerSuccessHaptic();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['message'] ?? 'Password changed successfully!'),
                                        backgroundColor: AppTheme.emeraldGreen,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } else {
                                    AppTheme.triggerErrorHaptic();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['message'] ?? 'Failed to change password.'),
                                        backgroundColor: AppTheme.crimsonRose,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.royalNavy,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: isUpdating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(LucideIcons.check, size: 16),
                        label: Text(
                          isUpdating ? 'Updating...' : 'Update Password',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChangeEmailModal() {
    AppTheme.triggerLightHaptic();
    final formKey = GlobalKey<FormState>();
    final currentPassController = TextEditingController();
    final newEmailController = TextEditingController();
    bool obscureCurrent = true;
    bool isUpdating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.borderLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.royalNavy.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.mail, color: AppTheme.royalNavy, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Change Email Address',
                          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Current Password Verification
                    TextFormField(
                      controller: currentPassController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon: const Icon(LucideIcons.key, size: 16, color: AppTheme.royalNavy),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? LucideIcons.eyeOff : LucideIcons.eye, size: 17, color: AppTheme.textSecondary),
                          onPressed: () => setModalState(() => obscureCurrent = !obscureCurrent),
                        ),
                        filled: true,
                        fillColor: AppTheme.bgLight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Please enter current password to verify' : null,
                    ),
                    const SizedBox(height: 12),

                    // New Email Address
                    TextFormField(
                      controller: newEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'New Email Address',
                        hintText: 'name@ccsa.du.ac.in',
                        prefixIcon: const Icon(LucideIcons.mailCheck, size: 16, color: AppTheme.royalNavy),
                        filled: true,
                        fillColor: AppTheme.bgLight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter new email address';
                        if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isUpdating
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isUpdating = true);

                                final res = await AuthService.instance.changeEmail(
                                  currentPassword: currentPassController.text.trim(),
                                  newEmail: newEmailController.text.trim(),
                                );

                                if (ctx.mounted) {
                                  setModalState(() => isUpdating = false);
                                  Navigator.pop(ctx);

                                  if (res['success'] == true) {
                                    AppTheme.triggerSuccessHaptic();
                                    setState(() {}); // Refresh UI
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['message'] ?? 'Email updated successfully!'),
                                        backgroundColor: AppTheme.emeraldGreen,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } else {
                                    AppTheme.triggerErrorHaptic();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['message'] ?? 'Failed to update email.'),
                                        backgroundColor: AppTheme.crimsonRose,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.royalNavy,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: isUpdating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(LucideIcons.check, size: 16),
                        label: Text(
                          isUpdating ? 'Updating...' : 'Update Email',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.logOut, color: AppTheme.crimsonRose, size: 22),
            const SizedBox(width: 8),
            Text(
              'Sign Out',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out from this device?',
          style: TextStyle(fontSize: 13, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crimsonRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      AuthService.instance.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Account Tile
                if (user != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.roundedRadius,
                      border: Border.all(color: AppTheme.borderLight, width: 1.2),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.royalNavy,
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: user.isStudent ? AppTheme.electricTealBg : AppTheme.emeraldGreenBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  user.role == 'faculty' ? 'Faculty Member' : 'Student',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: user.isStudent ? AppTheme.electricTeal : const Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit Profile',
                          icon: const Icon(LucideIcons.chevronRight, size: 20, color: AppTheme.textSecondary),
                          onPressed: () async {
                            final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
                            if (updated == true) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Security & Credentials Section
                Text(
                  'Account Security & Credentials',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppTheme.roundedRadius,
                    border: Border.all(color: AppTheme.borderLight, width: 1.2),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.royalNavy.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.lock, size: 18, color: AppTheme.royalNavy),
                        ),
                        title: Text('Change Password', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Update your account password', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
                        trailing: const Icon(LucideIcons.chevronRight, size: 16, color: AppTheme.textSecondary),
                        onTap: _showChangePasswordModal,
                      ),
                      const Divider(height: 1, color: AppTheme.borderSubtle),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.electricTealBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.mail, size: 18, color: AppTheme.electricTeal),
                        ),
                        title: Text('Change Email Address', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Update primary academic email', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
                        trailing: const Icon(LucideIcons.chevronRight, size: 16, color: AppTheme.textSecondary),
                        onTap: _showChangeEmailModal,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),



                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleSignOut,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.crimsonRose,
                      side: const BorderSide(color: AppTheme.crimsonRoseBorder, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(LucideIcons.logOut, size: 18),
                    label: Text(
                      'Sign Out',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
