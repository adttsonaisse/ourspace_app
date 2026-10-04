import 'package:flutter/material.dart';
import '../theme/kawaii.dart';

enum KawaiiBtnColor { peach, sky, sunny, pink, mint, white }

extension on KawaiiBtnColor {
  Color get bg {
    switch (this) {
      case KawaiiBtnColor.peach:
        return Kawaii.peach;
      case KawaiiBtnColor.sky:
        return Kawaii.sky;
      case KawaiiBtnColor.sunny:
        return Kawaii.sunny;
      case KawaiiBtnColor.pink:
        return Kawaii.bubble;
      case KawaiiBtnColor.mint:
        return Kawaii.mint;
      case KawaiiBtnColor.white:
        return Colors.white;
    }
  }

  Color get fg {
    return Kawaii.ink;
  }
}

class KawaiiButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final KawaiiBtnColor color;
  final IconData? icon;
  final bool expanded;
  const KawaiiButton({
    super.key,
    required this.label,
    this.onTap,
    this.color = KawaiiBtnColor.peach,
    this.icon,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final edge = dark ? Colors.white : Kawaii.ink;
    // Ink is outline-only: never a surface fill. Pastel bg lives in
    // BoxDecoration so there is no path to a black button.
    assert(color.bg != Kawaii.ink, 'KawaiiButton bg must be pastel, not ink');
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Container(
        width: expanded ? double.infinity : null,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Kawaii.radiusBtn),
          boxShadow: [
            BoxShadow(color: edge, offset: const Offset(4, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Kawaii.radiusBtn),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Kawaii.radiusBtn),
            child: Container(
              width: expanded ? double.infinity : null,
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: color.bg,
                borderRadius: BorderRadius.circular(Kawaii.radiusBtn),
                border: Border.all(color: edge, width: 3),
              ),
              child: Row(
                mainAxisSize:
                    expanded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: color.fg),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: color.fg,
                        fontFamily: Kawaii.displayFamily,
                      ),
                    ),
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

class KawaiiCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const KawaiiCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ?? (dark ? Kawaii.nightCard : Colors.white);
    final edge = dark ? Colors.white : Kawaii.ink;
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Kawaii.radiusCard),
        border: Border.all(color: edge, width: 3),
        boxShadow: [
          BoxShadow(color: edge, offset: const Offset(4, 4)),
          const BoxShadow(
              color: Color(0x10000000), offset: Offset(0, 10), blurRadius: 24),
        ],
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Kawaii.radiusCard),
        child: body,
      ),
    );
  }
}

enum KawaiiAlertKind { success, info, warning, danger }

class _AlertMeta {
  final Color bg;
  final Color tile;
  final IconData icon;
  const _AlertMeta(this.bg, this.tile, this.icon);
}

/// Sticker alert. Long copy wraps, the message never clips, and every
/// control (dismiss, action) either works or is not built.
class KawaiiAlert extends StatelessWidget {
  final String title;
  final String message;
  final KawaiiAlertKind kind;
  final VoidCallback? onClose;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const _metas = {
    KawaiiAlertKind.success:
        _AlertMeta(Kawaii.mintSubtle, Kawaii.mint, Icons.check_rounded),
    KawaiiAlertKind.info:
        _AlertMeta(Kawaii.skySubtle, Kawaii.sky, Icons.info_rounded),
    KawaiiAlertKind.warning:
        _AlertMeta(Kawaii.sunnySubtle, Kawaii.sunny, Icons.warning_rounded),
    KawaiiAlertKind.danger:
        _AlertMeta(Kawaii.pinkSubtle, Kawaii.bubble, Icons.error_rounded),
  };

  const KawaiiAlert({
    super.key,
    required this.title,
    required this.message,
    this.kind = KawaiiAlertKind.info,
    this.onClose,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final m = _metas[kind]!;
    return KawaiiCard(
      color: m.bg,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KawaiiIcon(
                  icon: m.icon, bg: m.tile, size: 44, iconSize: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(message,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (onClose != null) ...[
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Dismiss $title',
                  child: GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 44,
                    height: 44,
                    color: Colors.transparent,
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Kawaii.ink, width: 2),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Kawaii.ink),
                    ),
                  ),
                  ),
                ),
              ],
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: actionLabel,
              child: GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: m.tile,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Kawaii.ink, width: 2.5),
                ),
                alignment: Alignment.center,
                child: Text(actionLabel!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class KawaiiInput extends StatelessWidget {
  final String hint;
  final String? label;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboard;
  final IconData? prefix;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool enabled;
  const KawaiiInput({
    super.key,
    required this.hint,
    this.label,
    this.controller,
    this.obscure = false,
    this.keyboard,
    this.prefix,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.focusNode,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final edge = dark ? Colors.white : Kawaii.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Kawaii.sunny,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: edge, width: 2),
            ),
            child: Text(label!,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Kawaii.ink)),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscure,
          keyboardType: keyboard,
          maxLines: maxLines,
          validator: validator,
          onChanged: onChanged,
          autovalidateMode: validator == null
              ? AutovalidateMode.disabled
              : AutovalidateMode.onUserInteraction,
          style: TextStyle(
              color: dark ? Colors.white : Kawaii.ink,
              fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: (dark ? Colors.white : Kawaii.ink).withValues(alpha: 0.35),
                fontWeight: FontWeight.w500),
            prefixIcon: prefix != null
                ? Icon(prefix,
                    color: dark ? Colors.white : Kawaii.ink)
                : null,
            filled: true,
            fillColor: dark ? const Color(0xFF141414) : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Kawaii.radiusInput),
              borderSide: BorderSide(color: edge, width: 3),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Kawaii.radiusInput),
              borderSide: const BorderSide(color: Kawaii.sky, width: 3),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Kawaii.radiusInput),
              borderSide: const BorderSide(color: Kawaii.bubble, width: 3),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Kawaii.radiusInput),
              borderSide: const BorderSide(color: Kawaii.bubble, width: 3),
            ),
          ),
        ),
      ],
    );
  }
}

class KawaiiPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color fg;
  final IconData? icon;
  const KawaiiPill(
      {super.key,
      required this.label,
      required this.color,
      this.fg = Kawaii.ink,
      this.icon});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: dark ? Colors.white : Kawaii.ink, width: 2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
        ],
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
      ]),
    );
  }
}

class KawaiiIcon extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final double size;
  final double iconSize;
  final double radius;
  const KawaiiIcon({
    super.key,
    required this.icon,
    required this.bg,
    this.size = 48,
    this.iconSize = 24,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final edge = dark ? Colors.white : Kawaii.ink;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: edge, width: 2.5),
        boxShadow: [
          BoxShadow(color: edge, offset: const Offset(3, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: Kawaii.ink),
    );
  }
}

class KawaiiAvatarPair extends StatelessWidget {
  final String first;
  final String? second;
  final double size;
  const KawaiiAvatarPair(
      {super.key, required this.first, this.second, this.size = 34});

  @override
  Widget build(BuildContext context) {
    if (second == null || second!.trim().isEmpty) {
      return Semantics(
        label: first,
        child: KawaiiAvatar(text: first, bg: Kawaii.peach, size: size),
      );
    }
    final overlap = size * 0.65;
    return Semantics(
      label: '$first and $second',
      child: SizedBox(
        width: size + overlap,
        height: size + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
                left: 0,
                top: 8,
                child: KawaiiAvatar(text: first, bg: Kawaii.peach, size: size)),
            Positioned(
                left: overlap,
                top: 0,
                child: KawaiiAvatar(text: second!, bg: Kawaii.sky, size: size)),
          ],
        ),
      ),
    );
  }
}

class KawaiiPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bg;
  const KawaiiPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    // The account avatar pair lives only in the app bar: no duplicates here.
    return Row(
      children: [
        Transform.rotate(
          angle: -0.08,
          child: KawaiiIcon(icon: icon, bg: bg),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      fontFamily: Kawaii.displayFamily)),
              Text(subtitle,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

class KawaiiAvatar extends StatelessWidget {
  final String text;
  final Color bg;
  final double size;
  const KawaiiAvatar(
      {super.key, required this.text, required this.bg, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: dark ? Colors.white : Kawaii.ink, width: 3),
        boxShadow: [
          BoxShadow(
              color: dark ? Colors.white : Kawaii.ink,
              offset: const Offset(3, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(text,
          style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: size * 0.34,
              color: Kawaii.ink)),
    );
  }
}

class StickerDots extends StatelessWidget {
  final Color color;
  final int count;
  const StickerDots({super.key, this.color = Kawaii.skySubtle, this.count = 24});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(
        count,
        (_) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Kawaii.ink.withValues(alpha: 0.15), width: 1),
          ),
        ),
      ),
    );
  }
}

/// Ourspace toast: a SnackBar dressed in kawaii-pop (pastel fill per kind,
/// ink text + outline) so transient feedback matches the app.
/// For errors that need an action (Retry), prefer an inline [KawaiiAlert].
void showKawaiiToast(
  BuildContext context,
  String message, {
  KawaiiAlertKind kind = KawaiiAlertKind.info,
}) {
  final meta = switch (kind) {
    KawaiiAlertKind.success => (Kawaii.mint, Icons.check_rounded),
    KawaiiAlertKind.info => (Kawaii.sky, Icons.info_rounded),
    KawaiiAlertKind.warning => (Kawaii.sunny, Icons.warning_rounded),
    KawaiiAlertKind.danger => (Kawaii.bubble, Icons.error_rounded),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(meta.$2, size: 20, color: Kawaii.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Kawaii.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: meta.$1,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Kawaii.edgeOf(context), width: 2.5),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ),
    );
}
