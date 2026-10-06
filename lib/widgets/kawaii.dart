import 'package:flutter/material.dart';
import '../theme/kawaii.dart';
import 'kawaii_deco.dart';

enum KawaiiBtnColor { peach, sky, sunny, pink, mint, white }

extension KawaiiBtnColorFill on KawaiiBtnColor {
  Color get bg => switch (this) {
        KawaiiBtnColor.peach => Kawaii.peach,
        KawaiiBtnColor.sky => Kawaii.sky,
        KawaiiBtnColor.sunny => Kawaii.sunny,
        KawaiiBtnColor.pink => Kawaii.bubble,
        KawaiiBtnColor.mint => Kawaii.mint,
        KawaiiBtnColor.white => Colors.white,
      };
}

/// Error copy color: bubble pink is too light for text on cream.
Color kawaiiErrorText(BuildContext context) =>
    Kawaii.isDark(context) ? const Color(0xFFFF9BB5) : const Color(0xFFB3204A);

/// Sticker button: pastel pill, ink outline, hard offset. Pressing sinks
/// it onto its shadow so the tap reads as physical.
class KawaiiButton extends StatefulWidget {
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
  State<KawaiiButton> createState() => _KawaiiButtonState();
}

class _KawaiiButtonState extends State<KawaiiButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final edge = Kawaii.edgeOf(context);
    final bg = widget.color.bg;
    final fg = Kawaii.onFill(bg);
    final enabled = widget.onTap != null;
    final off = _down ? 1.0 : 4.0;
    final radius = BorderRadius.circular(Kawaii.radiusBtn);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Padding(
          // Reserve the shadow's footprint so pressing never shifts layout.
          padding: const EdgeInsets.only(right: 4, bottom: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            transform: Matrix4.translationValues(4 - off, 4 - off, 0),
            width: widget.expanded ? double.infinity : null,
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: Border.all(color: edge, width: Kawaii.borderW),
              boxShadow: [BoxShadow(color: edge, offset: Offset(off, off))],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onTap,
                onHighlightChanged: enabled ? _set : null,
                borderRadius: radius,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 13, horizontal: 22),
                  child: Row(
                    mainAxisSize: widget.expanded
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20, color: fg),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: fg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Container with two tiers:
/// - sticker (default): 3px outline + hard offset. The main object on a
///   screen.
/// - paper (`sticker: false`): 2px outline, flat. Lists, groups, empties.
///
/// Text and icons inside take a readable color from [color], so a peach
/// card stays ink-on-peach in dark mode too.
class KawaiiCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool sticker;
  final double? radius;
  const KawaiiCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.onLongPress,
    this.sticker = true,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Kawaii.cardOf(context);
    final edge = Kawaii.edgeOf(context);
    final r = BorderRadius.circular(radius ?? Kawaii.radiusCard);
    Widget content = Padding(padding: padding, child: child);
    content = KawaiiOnFill(fill: bg, child: content);
    if (onTap != null || onLongPress != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: r,
          child: content,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: r,
        border: Border.all(
            color: edge,
            width: sticker ? Kawaii.borderW : Kawaii.paperBorderW),
        boxShadow: sticker ? Kawaii.sticker(context) : null,
      ),
      child: content,
    );
  }
}

/// Re-themes text + icons for content painted on [fill]. A no-op when
/// the fill already matches the theme's text color.
class KawaiiOnFill extends StatelessWidget {
  final Color fill;
  final Widget child;
  const KawaiiOnFill({super.key, required this.fill, required this.child});

  @override
  Widget build(BuildContext context) {
    final fg = Kawaii.onFill(fill);
    if (fg == Kawaii.textOf(context)) return child;
    final theme = Theme.of(context);
    final muted = fg.withValues(alpha: 0.7);
    final tt = theme.textTheme.apply(bodyColor: fg, displayColor: fg);
    return Theme(
      data: theme.copyWith(
        textTheme: tt.copyWith(
            bodySmall: tt.bodySmall?.copyWith(color: muted)),
        iconTheme: theme.iconTheme.copyWith(color: fg),
        progressIndicatorTheme:
            theme.progressIndicatorTheme.copyWith(color: fg),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg),
        child: IconTheme.merge(data: IconThemeData(color: fg), child: child),
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

/// Inline alert (paper tier). Long copy wraps, the message never clips,
/// and every control (dismiss, action) either works or is not built.
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
    final tt = Theme.of(context).textTheme;
    return KawaiiCard(
      color: m.bg,
      sticker: false,
      radius: Kawaii.radiusInner + 4,
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KawaiiIcon(icon: m.icon, bg: m.tile, size: 36, iconSize: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: tt.titleSmall?.copyWith(color: Kawaii.ink)),
                      const SizedBox(height: 2),
                      Text(message,
                          style: tt.bodyMedium?.copyWith(
                              color: Kawaii.ink, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              if (onClose != null)
                KawaiiIconButton(
                  icon: Icons.close_rounded,
                  label: 'Dismiss $title',
                  onTap: onClose!,
                  size: 40,
                ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: KawaiiButton(
                label: actionLabel!,
                color: KawaiiBtnColor.white,
                onTap: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state: says what is missing and offers the one action that
/// fills it. Bold sticker-book style: sticker cluster + doodles on top,
/// paper tier so it never competes with real content.
class KawaiiEmpty extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final KawaiiBtnColor actionColor;
  final IconData stickerIcon;
  final Color stickerBg;
  const KawaiiEmpty({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.actionColor = KawaiiBtnColor.peach,
    this.stickerIcon = Icons.auto_awesome_rounded,
    this.stickerBg = Kawaii.sunny,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return KawaiiCard(
      sticker: false,
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KawaiiStickerCluster(main: stickerIcon, mainBg: stickerBg),
              const Spacer(),
              const KawaiiDoodles(),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: tt.titleMedium),
          const SizedBox(height: 4),
          Text(message, style: tt.bodyMedium),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            KawaiiButton(
              label: actionLabel!,
              icon: actionIcon,
              color: actionColor,
              expanded: false,
              onTap: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// Round outlined icon button with a 48dp target and a spoken label.
class KawaiiIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final Color? fill;
  const KawaiiIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 48,
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    final bg = fill ?? Kawaii.cardOf(context);
    final fg = Kawaii.onFill(bg);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: size / 2,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Container(
                width: size * 0.7,
                height: size * 0.7,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Kawaii.edgeOf(context),
                      width: Kawaii.paperBorderW),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: size * 0.38, color: fg),
              ),
            ),
          ),
        ),
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
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool enabled;
  final TextInputAction? action;
  final TextCapitalization capitalization;
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
    this.onSubmitted,
    this.focusNode,
    this.enabled = true,
    this.action,
    this.capitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final edge = Kawaii.edgeOf(context);
    final fg = Kawaii.textOf(context);
    final tt = Theme.of(context).textTheme;
    final err = kawaiiErrorText(context);
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Kawaii.radiusInput),
          borderSide: BorderSide(color: c, width: w),
        );
    final field = TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      textInputAction: action,
      textCapitalization: capitalization,
      autovalidateMode: validator == null
          ? AutovalidateMode.disabled
          : AutovalidateMode.onUserInteraction,
      style: tt.bodyLarge?.copyWith(color: fg),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: tt.bodyLarge?.copyWith(
            color: fg.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
        prefixIcon: prefix != null ? Icon(prefix, color: fg) : null,
        filled: true,
        fillColor: Kawaii.cardOf(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        errorStyle: tt.labelSmall?.copyWith(color: err, fontSize: 13),
        enabledBorder: border(edge, Kawaii.paperBorderW),
        disabledBorder: border(edge.withValues(alpha: 0.4), Kawaii.paperBorderW),
        // Focus = thicker ink edge; pastel focus rings fail 3:1 on white.
        focusedBorder: border(edge, 3.5),
        errorBorder: border(err, Kawaii.paperBorderW + 0.5),
        focusedErrorBorder: border(err, 3.5),
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label!, style: tt.titleSmall),
        ),
        field,
      ],
    );
  }
}

/// Small status pill. Only for real state (counts, progress, expiry),
/// never as a decorative label.
class KawaiiPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color? fg;
  final IconData? icon;
  const KawaiiPill(
      {super.key,
      required this.label,
      required this.color,
      this.fg,
      this.icon});

  @override
  Widget build(BuildContext context) {
    final text = fg ?? Kawaii.onFill(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: Kawaii.edgeOf(context), width: Kawaii.paperBorderW),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: text)),
        ),
      ]),
    );
  }
}

/// Icon on a pastel tile. Flat by default; `outlined` adds the ink edge
/// for tiles that stand alone outside a card.
class KawaiiIcon extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final double size;
  final double iconSize;
  final double radius;
  final bool outlined;
  const KawaiiIcon({
    super.key,
    required this.icon,
    required this.bg,
    this.size = 48,
    this.iconSize = 24,
    this.radius = 14,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: outlined
            ? Border.all(
                color: Kawaii.edgeOf(context), width: Kawaii.paperBorderW)
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: Kawaii.onFill(bg)),
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
    final overlap = size * 0.62;
    return Semantics(
      label: '$first and $second',
      child: SizedBox(
        width: size + overlap,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
                left: 0,
                child: KawaiiAvatar(text: first, bg: Kawaii.peach, size: size)),
            Positioned(
                left: overlap,
                child: KawaiiAvatar(text: second!, bg: Kawaii.sky, size: size)),
          ],
        ),
      ),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
            color: Kawaii.edgeOf(context), width: size >= 48 ? 3 : 2.5),
      ),
      alignment: Alignment.center,
      child: Text(text,
          style: TextStyle(
              fontFamily: Kawaii.displayFamily,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.4,
              height: 1,
              color: Kawaii.onFill(bg))),
    );
  }
}

/// Section heading inside a tab: sentence case, no eyebrow, optional
/// trailing state (e.g. a progress pill).
class KawaiiSectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const KawaiiSectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Confirmation for destructive actions. Resolves true only when the
/// person taps [confirmLabel].
Future<bool> confirmKawaii(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: KawaiiCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                KawaiiDoodles(),
                Spacer(),
                KawaiiSparkle(size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(d).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, style: Theme.of(d).textTheme.bodyMedium),
            const SizedBox(height: 18),
            KawaiiButton(
              label: confirmLabel,
              color: KawaiiBtnColor.pink,
              onTap: () => Navigator.of(d).pop(true),
            ),
            const SizedBox(height: 6),
            KawaiiButton(
              label: 'Cancel',
              color: KawaiiBtnColor.white,
              onTap: () => Navigator.of(d).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
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
                  fontFamily: Kawaii.displayFamily,
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
          borderRadius: BorderRadius.circular(Kawaii.radiusInner),
          side: BorderSide(color: Kawaii.edgeOf(context), width: 2.5),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 3),
      ),
    );
}
