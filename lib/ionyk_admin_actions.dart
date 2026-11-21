import 'package:flutter/material.dart';

/// Reusable admin action buttons for IONYK Systems.
/// These are purely UI components: supply backend callbacks from the page.
class IonykAdminAction extends StatelessWidget {
  const IonykAdminAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = IonykAdminActionVariant.secondary,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IonykAdminActionVariant variant;
  final bool busy;

  static const _ink = Color(0xFF151B1A);
  static const _lime = Color(0xFFD8FF57);
  static const _outline = Color(0xFFDCE2DC);
  static const _muted = Color(0xFF637067);
  static const _danger = Color(0xFFB42318);

  @override
  Widget build(BuildContext context) {
    final foreground = switch (variant) {
      IonykAdminActionVariant.primary => _lime,
      IonykAdminActionVariant.secondary => _ink,
      IonykAdminActionVariant.destructive => _danger,
    };
    final background = switch (variant) {
      IonykAdminActionVariant.primary => _ink,
      _ => Colors.white,
    };
    final border = switch (variant) {
      IonykAdminActionVariant.primary => _ink,
      IonykAdminActionVariant.secondary => _outline,
      IonykAdminActionVariant.destructive => const Color(0xFFEBC5C2),
    };

    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              height: 15,
              width: 15,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            )
          : (icon == null ? const SizedBox.shrink() : Icon(icon, size: 17)),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledForegroundColor: _muted,
        side: BorderSide(color: border),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

enum IonykAdminActionVariant { primary, secondary, destructive }

/// Returns true only if the operator confirms.
/// Run the authenticated backend action AFTER a true result.
Future<bool> showIonykConfirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: Text(message),
      actions: [
        IonykAdminAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        IonykAdminAction(
          label: confirmLabel,
          variant: destructive
              ? IonykAdminActionVariant.destructive
              : IonykAdminActionVariant.primary,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}
