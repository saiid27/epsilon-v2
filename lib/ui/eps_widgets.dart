import 'package:flutter/material.dart';

import 'eps_theme.dart';

/// Round official logo used on splash/auth screens.
class EpsLogo extends StatelessWidget {
  const EpsLogo({this.size = 96, this.ring = true, super.key});

  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring ? size * 0.035 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: ring ? Border.all(color: Eps.blue, width: size * 0.03) : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x262F5BD3),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/onboarding/epsilon_logo.jpeg',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// 40x40 bordered square icon button (`.icon-btn`).
class EpsIconButton extends StatelessWidget {
  const EpsIconButton({
    required this.icon,
    this.onTap,
    this.tooltip,
    this.badge,
    this.size = 42,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final int? badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: Eps.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 21, color: Eps.ink),
        ),
      ),
    );
    final withBadge = badge == null || badge == 0
        ? button
        : Stack(
            clipBehavior: Clip.none,
            children: [
              button,
              PositionedDirectional(
                top: -5,
                end: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  height: 19,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Eps.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge! > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          );
    return tooltip == null
        ? withBadge
        : Tooltip(message: tooltip!, child: withBadge);
  }
}

/// Centered page title with a back button on the start side and an optional
/// action on the end side (`.page-header`).
class EpsPageHeader extends StatelessWidget {
  const EpsPageHeader({
    required this.title,
    this.onBack,
    this.action,
    this.showBack = true,
    super.key,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? action;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return SizedBox(
      height: 74,
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: showBack && (onBack != null || canPop)
                ? EpsIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'رجوع',
                    onTap: onBack ?? () => Navigator.of(context).maybePop(),
                  )
                : null,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Eps.ink,
              ),
            ),
          ),
          SizedBox(width: 42, child: action),
        ],
      ),
    );
  }
}

/// Scaffold with the design background, safe area, and page header.
class EpsPage extends StatelessWidget {
  const EpsPage({
    required this.title,
    required this.children,
    this.action,
    this.onBack,
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(18, 0, 18, 32),
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;
  final VoidCallback? onBack;
  final Widget? bottom;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Eps.bg,
      body: SafeArea(
        bottom: bottom == null,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: EpsPageHeader(title: title, action: action, onBack: onBack),
            ),
            Expanded(
              child: ListView(padding: padding, children: children),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: bottom,
              ),
            ),
    );
  }
}

/// Gradient primary button (`.primary-btn`).
class EpsPrimaryButton extends StatelessWidget {
  const EpsPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.color,
    this.height = 54,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled || loading ? 1 : 0.75,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Eps.radius),
          gradient: enabled || loading
              ? (color == null
                    ? Eps.primaryGradient
                    : LinearGradient(colors: [color!, color!]))
              : null,
          color: enabled || loading ? null : const Color(0xFFC9CED9),
          boxShadow: enabled ? Eps.buttonShadow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Eps.radius),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (icon != null) ...[
                          const SizedBox(width: 8),
                          Icon(icon, color: Colors.white, size: 19),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White rounded card with thin border (`.continue-card`).
class EpsCard extends StatelessWidget {
  const EpsCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.color = Colors.white,
    this.borderColor = Eps.line,
    this.radius = Eps.cardRadius,
    this.gradient,
    this.dashed = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;
  final Gradient? gradient;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (dashed) {
      return CustomPaint(
        painter: _DashedBorderPainter(color: borderColor, radius: radius),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: content,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: gradient == null ? Border.all(color: borderColor) : null,
        boxShadow: Eps.cardShadow,
      ),
      child: content,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

enum EpsTone { blue, green, orange, red, gray }

extension EpsToneColors on EpsTone {
  Color get bg => switch (this) {
    EpsTone.blue => Eps.blueSoft,
    EpsTone.green => Eps.greenSoft,
    EpsTone.orange => Eps.orangeSoft,
    EpsTone.red => Eps.redSoft,
    EpsTone.gray => Eps.gray,
  };

  Color get fg => switch (this) {
    EpsTone.blue => Eps.blue2,
    EpsTone.green => Eps.greenInk,
    EpsTone.orange => Eps.orangeInk,
    EpsTone.red => Eps.redInk,
    EpsTone.gray => Eps.grayInk,
  };

  Color get solid => switch (this) {
    EpsTone.blue => Eps.blue,
    EpsTone.green => Eps.green,
    EpsTone.orange => Eps.orange,
    EpsTone.red => Eps.red,
    EpsTone.gray => Eps.faint,
  };
}

/// Pill badge (`.badge`).
class EpsBadge extends StatelessWidget {
  const EpsBadge(this.label, {this.tone = EpsTone.blue, this.icon, super.key});

  final String label;
  final EpsTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tone.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: tone.fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin rounded progress bar (`.progress`).
class EpsProgress extends StatelessWidget {
  const EpsProgress({
    required this.value,
    this.height = 6,
    this.color,
    this.track = const Color(0xFFE6E9F1),
    super.key,
  });

  final double value;
  final double height;
  final Color? color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height),
                  color: color,
                  gradient: color == null
                      ? const LinearGradient(
                          colors: [Eps.blue, Color(0xFF4775D0)],
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section heading with optional trailing link (`.section-title`).
class EpsSectionTitle extends StatelessWidget {
  const EpsSectionTitle(this.title, {this.action, this.onAction, super.key});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(1, 18, 1, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Eps.ink,
              ),
            ),
          ),
          if (action != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  action!,
                  style: const TextStyle(
                    color: Eps.blue2,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small rounded square containing an icon or glyph (`.subject-mark`).
class EpsMark extends StatelessWidget {
  const EpsMark({
    this.icon,
    this.glyph,
    this.tone = EpsTone.blue,
    this.size = 48,
    this.background,
    this.foreground,
    super.key,
  });

  final IconData? icon;
  final String? glyph;
  final EpsTone tone;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? tone.solid;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? tone.bg,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: icon != null
          ? Icon(icon, color: fg, size: size * 0.48)
          : Text(
              glyph ?? '',
              style: TextStyle(
                color: fg,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
    );
  }
}

/// Field label above inputs (`.auth-form > label`).
class EpsFieldLabel extends StatelessWidget {
  const EpsFieldLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 14, 3, 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Eps.ink,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// List-row style tile with mark, title, subtitle, trailing chevron.
class EpsListTile extends StatelessWidget {
  const EpsListTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.tone,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EpsTone? tone;

  @override
  Widget build(BuildContext context) {
    return EpsCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      color: tone == null ? Colors.white : tone!.bg.withValues(alpha: 0.55),
      borderColor: tone == null ? Eps.line : tone!.solid.withValues(alpha: 0.35),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Eps.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 12, color: Eps.muted),
                  ),
                ],
              ],
            ),
          ),
          trailing ??
              (onTap == null
                  ? const SizedBox.shrink()
                  : const Icon(
                      Icons.chevron_right_rounded,
                      color: Eps.ink,
                      size: 24,
                    )),
        ],
      ),
    );
  }
}

class EpsNavItem {
  const EpsNavItem(this.label, this.icon, {this.activeIcon, this.dot = false});

  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final bool dot;
}

/// Bottom navigation (`.bottom-nav`) with top indicator on active item.
class EpsBottomNav extends StatelessWidget {
  const EpsBottomNav({
    required this.items,
    required this.index,
    required this.onChanged,
    super.key,
  });

  final List<EpsNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF0FFFFFF),
        border: Border(top: BorderSide(color: Eps.line)),
        boxShadow: [
          BoxShadow(
            color: Color(0x101A2C50),
            blurRadius: 22,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    active: i == index,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final EpsNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Eps.blue : Eps.faint;
    return InkWell(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: active ? 28 : 0,
            height: 3,
            decoration: const BoxDecoration(
              color: Eps.blue,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      active ? (item.activeIcon ?? item.icon) : item.icon,
                      color: color,
                      size: 24,
                    ),
                    if (item.dot)
                      PositionedDirectional(
                        top: -2,
                        end: -4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Eps.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft blurred circles used as page backdrop on splash/auth.
class EpsGlowBackground extends StatelessWidget {
  const EpsGlowBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget blob(Color c, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
      ),
    );
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Eps.bg)),
        Positioned(
          top: 60,
          left: -60,
          child: blob(const Color(0x33F1B91C), 220),
        ),
        Positioned(
          top: 120,
          right: -80,
          child: blob(const Color(0x332F5BD3), 240),
        ),
        Positioned(
          bottom: 60,
          left: -70,
          child: blob(const Color(0x30F1B91C), 230),
        ),
        Positioned(
          bottom: 120,
          right: -90,
          child: blob(const Color(0x2B2F5BD3), 230),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// Empty-state block with logo loader style (`.empty`).
class EpsEmptyState extends StatelessWidget {
  const EpsEmptyState({
    required this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return EpsCard(
      dashed: true,
      borderColor: const Color(0xFFC9D3E6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        children: [
          EpsMark(icon: icon, size: 60),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Eps.ink,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Eps.muted),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
